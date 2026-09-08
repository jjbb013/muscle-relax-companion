import Foundation

// MARK: - 服务层契约（由 Services/ 目录实现，UI 仅依赖本文件）

/// 语音输入（需求 §3.2 分级策略）
/// 仅设备本地识别；不支持 on-device 时 isOnDeviceAvailable = false，UI 降级为文字输入。
@MainActor
protocol SpeechInputServicing: AnyObject, ObservableObject {
    var isOnDeviceAvailable: Bool { get }
    var isAuthorized: Bool { get }
    var isTranscribing: Bool { get }
    var partialText: String { get }

    func requestAuthorization() async -> Bool
    /// 开始转写；partialText 渐进更新。不支持 on-device 时不应被调用。
    func startTranscribing(language: AppLanguage)
    func stopTranscribing()
    func cancelTranscribing()
}

/// 语义识别（需求 §6.3）：NLTagger 分词 + 本地部位词典/同义词表
protocol SemanticParsing: Sendable {
    /// 返回按置信度排序的候选；空数组 = 无匹配（UI 引导手动点选，不强行匹配）
    func parse(_ text: String) -> [SemanticMatch]
}

/// 语音播报（需求 §6.4）：AVSpeechSynthesizer，逐段高亮由 highlightedText 驱动
@MainActor
protocol BroadcastServicing: AnyObject, ObservableObject {
    var isSpeaking: Bool { get }
    var isPaused: Bool { get }
    var highlightedSentenceIndex: Int? { get }   // 当前播报句段下标，用于逐段高亮

    func speak(text: String, language: AppLanguage)
    func pause()
    func resume()
    func stop()
}

/// 备份提醒（需求 §5.1.3）：本地通知，每周一次，内容不含健康数据
@MainActor
protocol BackupReminderServicing: AnyObject {
    func requestAuthorizationIfNeeded() async -> Bool
    func scheduleWeeklyReminder()
    func cancelReminder()
}
