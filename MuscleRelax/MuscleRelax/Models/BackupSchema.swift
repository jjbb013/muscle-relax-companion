import Foundation

// MARK: - 备份文件 Schema（需求 §5.2，schema_version = 1）
// 敏感字段导出时保持 AES-256 密文（Base64），整体再经 LZ4 压缩。

struct BackupFile: Codable, Sendable {
    var schemaVersion: Int = 1
    var appVersion: String
    var exportedAt: Date
    var records: [Record]
    var templates: [Template]
    var settings: Settings

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case appVersion = "app_version"
        case exportedAt = "exported_at"
        case records, templates, settings
    }

    struct Record: Codable, Sendable {
        var id: UUID
        var createdAt: Date
        var regionId: String
        var side: String
        var level: Int
        var symptomText: String   // AES-256 密文 Base64
        var generatedText: String // AES-256 密文 Base64
        var source: String
        var templateId: String?

        enum CodingKeys: String, CodingKey {
            case id
            case createdAt = "created_at"
            case regionId = "region_id"
            case side, level
            case symptomText = "symptom_text"
            case generatedText = "generated_text"
            case source
            case templateId = "template_id"
        }
    }

    struct Template: Codable, Sendable {
        var id: UUID
        var name: String      // 密文 Base64
        var content: String   // 密文 Base64
        var regionId: String
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id, name, content
            case regionId = "region_id"
            case updatedAt = "updated_at"
        }
    }

    struct Settings: Codable, Sendable {
        var language: String
        var backupReminderEnabled: Bool
        var disclaimerAcceptedVersion: String
        var onboardingCompleted: Bool
        var largeTextMode: Bool

        enum CodingKeys: String, CodingKey {
            case language
            case backupReminderEnabled = "backup_reminder_enabled"
            case disclaimerAcceptedVersion = "disclaimer_accepted_version"
            case onboardingCompleted = "onboarding_completed"
            case largeTextMode = "large_text_mode"
        }
    }
}

struct ImportSummary: Sendable {
    let importedRecords: Int
    let importedTemplates: Int
    let reassignedIDs: Int   // ID 冲突时生成新副本的条数（需求 §9）
}
