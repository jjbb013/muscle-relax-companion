import Foundation
import Compression

/// 备份导出 / 导入（需求 §5 / §9）
///
/// 管线：
/// - 导出：明文 DTO → 敏感字段 AES-256-GCM 加密为 Base64 → JSON（iso8601 + sortedKeys）
///   → LZ4RAW 压缩 → 写入目标 URL（文件保护 complete）。
/// - 导入：读文件 → LZ4RAW 解压（缓冲扩张循环）→ JSON 解码 → 校验 schema_version
///   → 解密敏感字段为明文 → ID 冲突重映射（生成新 UUID，计入 ImportSummary.reassignedIDs）。
///
/// 注意：返回给调用方的 `BackupFile` 中敏感字段已是**解密后的明文**，
/// 与落盘格式（密文 Base64）不同；调用方写入 Core Data 时会重新加密。
struct BackupService: BackupServicing {

    /// 当前支持的 schema 版本上限
    static let supportedSchemaVersion = 1

    private let crypto: CryptoService

    init(crypto: CryptoService) {
        self.crypto = crypto
    }

    // MARK: - 导出

    func exportBackup(records: [SoreRecordData],
                      templates: [UserTemplateData],
                      settings: AppSettingsData,
                      to url: URL) throws {
        let backup = BackupFile(
            schemaVersion: Self.supportedSchemaVersion,
            appVersion: Self.appVersionString(),
            exportedAt: Date(),
            records: try records.map { record in
                BackupFile.Record(
                    id: record.id,
                    createdAt: record.createdAt,
                    regionId: record.regionId,
                    side: record.side.rawValue,
                    level: record.level.rawValue,
                    symptomText: try crypto.encryptToBase64String(record.symptomText),
                    generatedText: try crypto.encryptToBase64String(record.generatedText),
                    source: record.source.rawValue,
                    templateId: record.templateId
                )
            },
            templates: try templates.map { template in
                BackupFile.Template(
                    id: template.id,
                    name: try crypto.encryptToBase64String(template.name),
                    content: try crypto.encryptToBase64String(template.content),
                    regionId: template.regionId,
                    updatedAt: template.updatedAt
                )
            },
            settings: BackupFile.Settings(
                language: settings.language.rawValue,
                backupReminderEnabled: settings.backupReminderEnabled,
                disclaimerAcceptedVersion: settings.disclaimerAcceptedVersion,
                onboardingCompleted: settings.onboardingCompleted,
                largeTextMode: settings.largeTextMode
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        let jsonData: Data
        do {
            jsonData = try encoder.encode(backup)
        } catch {
            throw BackupError.encodingFailed
        }

        let compressed = try Self.lz4Compress(jsonData)

        do {
            try compressed.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            throw BackupError.writeFailed
        }
    }

    // MARK: - 导入

    func importBackup(from url: URL,
                      existingRecordIDs: Set<UUID>,
                      existingTemplateIDs: Set<UUID>) throws -> (BackupFile, ImportSummary) {
        guard let compressed = try? Data(contentsOf: url) else {
            throw BackupError.corruptedFile
        }

        let jsonData = try Self.lz4Decompress(compressed)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var backup: BackupFile
        do {
            backup = try decoder.decode(BackupFile.self, from: jsonData)
        } catch {
            throw BackupError.corruptedFile
        }

        // 版本校验（需求 §5.2：高于当前支持版本则拒绝，未写入任何数据）
        if backup.schemaVersion > Self.supportedSchemaVersion {
            throw BackupError.unsupportedVersion(found: backup.schemaVersion)
        }

        // 解密敏感字段为明文（密钥不匹配会抛出 CryptoError.decryptionFailed）
        for index in backup.records.indices {
            backup.records[index].symptomText = try crypto.decryptFromBase64String(backup.records[index].symptomText)
            backup.records[index].generatedText = try crypto.decryptFromBase64String(backup.records[index].generatedText)
        }
        for index in backup.templates.indices {
            backup.templates[index].name = try crypto.decryptFromBase64String(backup.templates[index].name)
            backup.templates[index].content = try crypto.decryptFromBase64String(backup.templates[index].content)
        }

        // ID 冲突 → 生成新副本，不覆盖现有数据（需求 §9）
        var reassigned = 0
        var claimedRecordIDs = existingRecordIDs
        for index in backup.records.indices {
            if claimedRecordIDs.contains(backup.records[index].id) {
                backup.records[index].id = UUID()
                reassigned += 1
            }
            claimedRecordIDs.insert(backup.records[index].id)
        }
        var claimedTemplateIDs = existingTemplateIDs
        for index in backup.templates.indices {
            if claimedTemplateIDs.contains(backup.templates[index].id) {
                backup.templates[index].id = UUID()
                reassigned += 1
            }
            claimedTemplateIDs.insert(backup.templates[index].id)
        }

        let summary = ImportSummary(
            importedRecords: backup.records.count,
            importedTemplates: backup.templates.count,
            reassignedIDs: reassigned
        )
        return (backup, summary)
    }

    // MARK: - LZ4RAW 压缩 / 解压

    /// LZ4RAW 压缩。`compression_encode_buffer` 输出缓冲不足时返回 0，
    /// 这里按 LZ4 最坏情况上界（src + src/255 + 64）起步，失败则倍增重试。
    static func lz4Compress(_ source: Data) throws -> Data {
        guard !source.isEmpty else { return Data() }

        var dstCapacity = max(64, source.count + source.count / 255 + 64)
        let capacityLimit = 1 << 30 // 1 GB 防御上限

        while true {
            var dst = Data(count: dstCapacity)
            let written = dst.withUnsafeMutableBytes { dstPtr -> Int in
                source.withUnsafeBytes { srcPtr -> Int in
                    guard let dstBase = dstPtr.baseAddress,
                          let srcBase = srcPtr.baseAddress else { return 0 }
                    return compression_encode_buffer(
                        dstBase.assumingMemoryBound(to: UInt8.self),
                        dstCapacity,
                        srcBase.assumingMemoryBound(to: UInt8.self),
                        source.count,
                        nil,
                        COMPRESSION_LZ4_RAW
                    )
                }
            }
            if written > 0 {
                dst.count = written
                return dst
            }
            dstCapacity *= 2
            if dstCapacity > capacityLimit {
                throw BackupError.compressionFailed
            }
        }
    }

    /// LZ4RAW 解压。LZ4RAW 不带原始长度头，需缓冲扩张循环：
    /// 若解码结果恰好填满缓冲，则无法区分「恰好填满」与「被截断」，一律倍增重试。
    static func lz4Decompress(_ source: Data) throws -> Data {
        guard !source.isEmpty else { throw BackupError.corruptedFile }

        var dstCapacity = max(4096, source.count * 4)
        let capacityLimit = 1 << 29 // 512 MB 防御上限（防解压炸弹）

        while true {
            var dst = Data(count: dstCapacity)
            let written = dst.withUnsafeMutableBytes { dstPtr -> Int in
                source.withUnsafeBytes { srcPtr -> Int in
                    guard let dstBase = dstPtr.baseAddress,
                          let srcBase = srcPtr.baseAddress else { return 0 }
                    return compression_decode_buffer(
                        dstBase.assumingMemoryBound(to: UInt8.self),
                        dstCapacity,
                        srcBase.assumingMemoryBound(to: UInt8.self),
                        source.count,
                        nil,
                        COMPRESSION_LZ4_RAW
                    )
                }
            }
            if written == 0 {
                // 无法解码：文件损坏或并非 LZ4RAW 数据
                throw BackupError.corruptedFile
            }
            if written < dstCapacity {
                dst.count = written
                return dst
            }
            dstCapacity *= 2
            if dstCapacity > capacityLimit {
                throw BackupError.corruptedFile
            }
        }
    }

    // MARK: - 辅助

    private static func appVersionString() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0.0"
    }
}
