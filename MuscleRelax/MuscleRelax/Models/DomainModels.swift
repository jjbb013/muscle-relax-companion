import Foundation

// MARK: - 基础枚举（需求 §4 数据模型）

/// 部位侧别
enum RegionSide: String, Codable, CaseIterable, Sendable {
    case left, right, center, both

    var displayName: String {
        switch self {
        case .left: return "左侧"
        case .right: return "右侧"
        case .center: return ""
        case .both: return "双侧"
        }
    }
}

/// 酸痛等级（需求 §4：1 轻微软胀 / 2 中度酸胀 / 3 重度紧绷）
enum SoreLevel: Int, Codable, CaseIterable, Sendable, Comparable {
    case mild = 1
    case moderate = 2
    case severe = 3

    static func < (lhs: SoreLevel, rhs: SoreLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var displayName: String {
        switch self {
        case .mild: return "轻微软胀"
        case .moderate: return "中度酸胀"
        case .severe: return "重度紧绷"
        }
    }
}

/// 记录来源
enum RecordSource: String, Codable, Sendable {
    case manual, voice, template

    var displayName: String {
        switch self {
        case .manual: return "手动"
        case .voice: return "语音"
        case .template: return "模板"
        }
    }
}

/// 部位分类（需求 §4 BodyRegion.category）
enum RegionCategory: String, Codable, CaseIterable, Sendable {
    case neck, shoulder, back, waist, abdomen
    case upperArm, forearm, hip, thigh, calf, knee, other

    var displayName: String {
        switch self {
        case .neck: return "颈部"
        case .shoulder: return "肩部"
        case .back: return "背部"
        case .waist: return "腰部"
        case .abdomen: return "腹部"
        case .upperArm: return "上臂"
        case .forearm: return "前臂"
        case .hip: return "髋部"
        case .thigh: return "大腿"
        case .calf: return "小腿"
        case .knee: return "膝部"
        case .other: return "其他"
        }
    }
}

/// 播报 / 界面语言
enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case zh, en, ja

    var displayName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }

    /// AVSpeechSynthesisVoice 语言代码
    var speechLanguageCode: String {
        switch self {
        case .zh: return "zh-CN"
        case .en: return "en-US"
        case .ja: return "ja-JP"
        }
    }
}

// MARK: - 内置静态数据（随包只读）

/// 常用按压点（需求 §4 PressPoint，非医疗表述，note 统一带"仅供参考"）
struct PressPoint: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let regionId: String
    let note: String
}

/// 身体部位（需求 §4 BodyRegion）
struct BodyRegion: Identifiable, Hashable, Sendable {
    let id: String            // 如 "shoulder_l"
    let displayName: String   // 中文展示名
    let side: RegionSide
    let category: RegionCategory
    let muscleNames: [String]        // 关联肌肉名称（展示用）
    let pressPoints: [PressPoint]    // 常用按压点
    let fatigueScenes: [String]      // 常见疲劳场景说明
    let relaxSuggestions: [String]   // 适配的放松方式建议
    let isFineRendered: Bool         // 是否精细渲染区（高频区 = true）
}

/// 内置高频放松模板（需求 §6.5）
struct BuiltinTemplate: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let content: String
    let regionId: String
}

/// 自助舒缓参考（需求 §6.6，静态图文，无外链）
struct StretchGuide: Identifiable, Hashable, Sendable {
    let id: String
    let regionId: String
    let title: String
    let steps: [String]
    let sourceNote: String   // 内容来源 / 循证说明
}

// MARK: - 用户数据（内存中的明文形态；落盘时敏感字段加密，见 DataContracts）

/// 酸痛记录（需求 §4 SoreRecord）
struct SoreRecordData: Identifiable, Hashable, Sendable {
    var id: UUID
    var createdAt: Date
    var regionId: String
    var side: RegionSide
    var level: SoreLevel
    var symptomText: String    // 🔒 落盘 AES-256 加密
    var generatedText: String  // 🔒 落盘 AES-256 加密
    var source: RecordSource
    var templateId: String?
}

/// 自定义模板（需求 §4 UserTemplate）
struct UserTemplateData: Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String           // 🔒 加密
    var content: String        // 🔒 加密
    var regionId: String
    var updatedAt: Date
}

/// 应用设置（需求 §4 AppSettings）
struct AppSettingsData: Hashable, Sendable {
    var language: AppLanguage = .zh
    var backupReminderEnabled: Bool = false
    var disclaimerAcceptedVersion: String = ""
    var onboardingCompleted: Bool = false
    var largeTextMode: Bool = false
}

// MARK: - 语义识别结果（需求 §6.3）

struct SemanticMatch: Hashable, Sendable {
    let regionId: String
    let side: RegionSide
    let level: SoreLevel?
    let confidence: Double     // 0...1；低置信时 UI 引导手动点选
}
