import Foundation
import Combine

// MARK: - 数据层契约（由 Data/ 目录实现，UI 仅依赖本文件）

/// 用户数据仓库：Core Data + 字段级 AES-256 加密（需求 §3.1）
/// 内存中以明文 DTO 交互；落盘时 symptomText / generatedText / 模板 name / content 加密。
@MainActor
protocol SoreRecordStore: AnyObject, ObservableObject {
    var records: [SoreRecordData] { get }          // 按时间倒序
    var userTemplates: [UserTemplateData] { get }
    var settings: AppSettingsData { get }

    func addRecord(_ record: SoreRecordData)
    func updateRecord(_ record: SoreRecordData)
    func deleteRecord(id: UUID)
    func deleteAllRecords()                        // 二次确认由 UI 负责

    func addTemplate(_ template: UserTemplateData)
    func updateTemplate(_ template: UserTemplateData)
    func deleteTemplate(id: UUID)

    func updateSettings(_ settings: AppSettingsData)
}

/// 备份服务：LZ4 压缩 JSON，导出/导入（需求 §5）
protocol BackupServicing: Sendable {
    /// 导出当前全部用户数据到指定 URL（敏感字段保持密文）
    func exportBackup(records: [SoreRecordData],
                      templates: [UserTemplateData],
                      settings: AppSettingsData,
                      to url: URL) throws
    /// 从 URL 导入；版本高于当前支持则抛错；ID 冲突生成新副本（需求 §9）
    func importBackup(from url: URL,
                      existingRecordIDs: Set<UUID>,
                      existingTemplateIDs: Set<UUID>) throws -> (BackupFile, ImportSummary)
}
