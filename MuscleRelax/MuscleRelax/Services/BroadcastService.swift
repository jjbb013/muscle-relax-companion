import Foundation
import AVFoundation

// MARK: - 语音播报服务（需求 §6.4 双通道无障碍沟通）
//
// 场景：用户把手机递给按摩师——视障从业者听语音，听障从业者看大屏文字。
// AVSpeechSynthesizer 逐句播报，highlightedSentenceIndex 驱动 UI 逐段高亮，
// 与超大号静态文字互为兜底。
//
// 音色：系统合成语音（不承诺"真人音色"）；若用户已自行下载"增强语音"包则优先使用。

@MainActor
final class BroadcastService: NSObject, ObservableObject, BroadcastServicing {

    // MARK: 契约状态

    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var isPaused: Bool = false
    /// 当前正在播报的句段下标（对应 sentences），UI 据此高亮；未播报时为 nil
    @Published private(set) var highlightedSentenceIndex: Int?

    // MARK: 私有状态

    private let synthesizer = AVSpeechSynthesizer()
    /// 句段文本（拆句结果），下标即 highlightedSentenceIndex 语义
    private var sentences: [String] = []
    /// 与 sentences 一一对应的 utterance，delegate 回调里用对象身份反查下标
    private var utterances: [AVSpeechUtterance] = []
    /// 音频会话是否由本服务激活（用于收尾时对称 deactivate）
    private var audioSessionActive = false

    // MARK: 初始化

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: BroadcastServicing

    /// 逐句播报。重复调用安全：先停掉进行中的播报再开始新一轮。
    func speak(text: String, language: AppLanguage) {
        stop()

        sentences = Self.splitSentences(text)
        guard !sentences.isEmpty else { return }

        activateAudioSession()

        let voice = Self.preferredVoice(for: language)
        utterances = sentences.map { sentence in
            let utterance = AVSpeechUtterance(string: sentence)
            utterance.voice = voice
            utterance.rate = 0.5            // 稍慢，便于按摩师听清
            utterance.pitchMultiplier = 1.0
            utterance.preUtteranceDelay = 0.15  // 句间小停顿，分段感更清晰
            return utterance
        }

        isSpeaking = true
        isPaused = false
        highlightedSentenceIndex = nil
        utterances.forEach { synthesizer.speak($0) }
    }

    func pause() {
        guard isSpeaking, !isPaused else { return }
        // .immediate：立刻停在当前词，便于现场沟通随时打断
        synthesizer.pauseSpeaking(at: .immediate)
        isPaused = true
    }

    func resume() {
        guard isSpeaking, isPaused else { return }
        synthesizer.continueSpeaking()
        isPaused = false
    }

    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        // delegate 的 didCancel 回调也会做收尾；这里同步重置，保证状态即时准确
        resetState()
    }

    // MARK: 拆句

    /// 按句读拆成句段：中英文逗号/句号/分号/冒号/叹号/问号与换行均为切分点。
    /// 分隔符本身丢弃；空段剔除。拆句结果同时供播报队列与 UI 分段高亮使用。
    static func splitSentences(_ text: String) -> [String] {
        let delimiters = CharacterSet(charactersIn: ".,;:!?。，；：！？\n")
        return text
            .components(separatedBy: delimiters)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: 音色

    /// 优先使用已下载的系统"增强语音"（§6.4.4，一次性用户主动行为，非应用联网）；
    /// 未下载则回退默认音色。系统音色不可用时返回 nil（合成器使用系统默认）。
    private static func preferredVoice(for language: AppLanguage) -> AVSpeechSynthesisVoice? {
        let code = language.speechLanguageCode
        let enhanced = AVSpeechSynthesisVoice.speechVoices().first {
            $0.language == code && $0.quality == .enhanced
        }
        return enhanced ?? AVSpeechSynthesisVoice(language: code)
    }

    // MARK: 音频会话

    /// .playback：播报不受静音开关影响（递给按摩师时必须能出声）
    private func activateAudioSession() {
        guard !audioSessionActive else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .voicePrompt)
            try session.setActive(true)
            audioSessionActive = true
        } catch {
            // 会话配置失败不阻断播报——合成器仍会尝试出声
            audioSessionActive = false
        }
    }

    private func deactivateAudioSession() {
        guard audioSessionActive else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        audioSessionActive = false
    }

    /// 全部播报结束 / 被取消后的统一收尾
    private func resetState() {
        isSpeaking = false
        isPaused = false
        highlightedSentenceIndex = nil
        sentences = []
        utterances = []
        deactivateAudioSession()
    }

    /// utterance 是否为当前队列最后一句（用于判断整轮播报结束）
    private func isLastUtterance(_ utterance: AVSpeechUtterance) -> Bool {
        utterances.last === utterance
    }
}

// MARK: - AVSpeechSynthesizerDelegate
//
// AVSpeechSynthesizer 在主线程回调 delegate；本类为 @MainActor。
// Swift 6 下跨 actor 的协议遵循需 @preconcurrency（回调实际发生在主线程，安全）。

extension BroadcastService: @preconcurrency AVSpeechSynthesizerDelegate {

    /// 逐段高亮核心：每句开始播报时回调，用对象身份反查句段下标
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        if let index = utterances.firstIndex(where: { $0 === utterance }) {
            highlightedSentenceIndex = index
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        if isLastUtterance(utterance) {
            resetState()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        // stop() 已同步重置；此处兜底（如系统中断导致的取消）
        if !isSpeaking || isLastUtterance(utterance) {
            resetState()
        }
    }
}
