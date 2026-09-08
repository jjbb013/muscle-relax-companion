import Foundation

// MARK: - 数据层错误（全部带中文描述，供 UI 直接展示）

/// 加密相关错误（需求 §3.1 / §9）
enum CryptoError: LocalizedError, Sendable {
    /// Keychain 读取失败（如换机 / 恢复备份后），已自动重建新密钥；
    /// 旧密文无法解密，上层应提示「加密记录需原设备重新导出」。
    case keyRebuilt
    /// 密钥写入 Keychain 失败
    case keychainWriteFailed(OSStatus)
    /// AES-GCM 加密失败
    case encryptionFailed
    /// 解密失败：密钥不匹配或密文损坏
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .keyRebuilt:
            return "检测到加密密钥不可用（可能因换机或恢复系统备份），已自动重建新密钥。此前的加密记录需在原设备重新导出后才能恢复。"
        case .keychainWriteFailed(let status):
            return "无法将加密密钥写入系统钥匙串（错误码 \(status)），请重启 App 后重试。"
        case .encryptionFailed:
            return "内容加密失败，请重试。"
        case .decryptionFailed:
            return "无法解密内容：密钥不匹配或数据已损坏。"
        }
    }
}

/// 备份 / 恢复相关错误（需求 §5 / §9）
enum BackupError: LocalizedError, Sendable {
    /// 文件损坏或格式不正确（未写入任何数据）
    case corruptedFile
    /// 备份 schema 版本高于当前 App 支持版本
    case unsupportedVersion(found: Int)
    /// LZ4 压缩失败
    case compressionFailed
    /// JSON 编码失败
    case encodingFailed
    /// 文件写入失败
    case writeFailed
    /// 加密模块不可用（密钥写入 Keychain 失败的极端情况）
    case encryptionUnavailable

    var errorDescription: String? {
        switch self {
        case .corruptedFile:
            return "备份文件已损坏或格式不正确，未写入任何数据，请重新选择文件。"
        case .unsupportedVersion(let found):
            return "备份文件版本（v\(found)）高于当前 App 支持的版本，请将 App 升级到最新版后再导入。"
        case .compressionFailed:
            return "备份文件压缩失败。"
        case .encodingFailed:
            return "备份数据编码失败。"
        case .writeFailed:
            return "备份文件写入失败，请检查所选位置是否可写。"
        case .encryptionUnavailable:
            return "加密模块不可用，暂时无法导出 / 导入备份。"
        }
    }
}

/// 本地持久化（Core Data）相关错误
enum StoreError: LocalizedError, Sendable {
    /// 数据库文件加载失败（损坏且自动迁移无法修复）
    case persistenceLoadFailed(String)
    /// 上下文保存失败
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .persistenceLoadFailed(let detail):
            return "本地数据库打开失败（\(detail)）。请尝试重启 App；若仍失败，可在设置中导入最近的备份文件恢复数据。"
        case .saveFailed(let detail):
            return "数据保存失败（\(detail)），请重试。"
        }
    }
}
