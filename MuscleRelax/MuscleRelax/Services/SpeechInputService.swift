import Foundation
import Speech
import AVFoundation

// MARK: - 语音输入服务（需求 §3.2 分级策略 / §6.3.1）
//
// 仅设备本地识别：request.requiresOnDeviceRecognition = true，
// 不支持 on-device 的语言/设备上 isOnDeviceAvailable = false，UI 应降级为文字输入。
// 全程无网络请求。

@MainActor
final class SpeechInputService: ObservableObject, SpeechInputServicing {

    // MARK: 契约状态

    /// 是否存在可做纯本地识别的识别器。
    /// 语义说明：以 App 主语言（中文 zh-CN）的识别器为判定基准——
    /// 初始化时该 locale 的 SFSpeechRecognizer 不为 nil 且 supportsOnDeviceRecognition 为 true。
    /// UI 若需要按语言粒度判断（如切换到日语时），请用 `isOnDeviceAvailable(for:)`。
    @Published private(set) var isOnDeviceAvailable: Bool

    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var isTranscribing: Bool = false
    @Published private(set) var partialText: String = ""

    /// 最近一次失败的描述（静音超时 / 识别错误等）。
    /// 出错后会话会被安全收尾，UI 提示后可直接再次 startTranscribing 重试。
    @Published private(set) var lastError: String?

    // MARK: 私有状态

    /// 按 App 语言缓存的识别器（locale 不可用时对应缺失）
    private var recognizers: [AppLanguage: SFSpeechRecognizer] = [:]
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var currentLanguage: AppLanguage?

    // MARK: 初始化

    init() {
        for language in AppLanguage.allCases {
            if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language.speechLanguageCode)) {
                recognizers[language] = recognizer
            }
        }
        // 契约属性以主语言（.zh）为基准；recognizer 为 nil（locale 不可用）即为 false
        self.isOnDeviceAvailable = recognizers[.zh]?.supportsOnDeviceRecognition ?? false
    }

    /// 按语言粒度的 on-device 判定（需求 §3.2.3：日语离线包未下载等情况需降级提示）
    func isOnDeviceAvailable(for language: AppLanguage) -> Bool {
        recognizers[language]?.supportsOnDeviceRecognition ?? false
    }

    // MARK: 授权

    func requestAuthorization() async -> Bool {
        // 1) 语音识别授权
        let speechGranted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechGranted else {
            isAuthorized = false
            return false
        }
        // 2) 麦克风授权：iOS 17+ 走 AVAudioApplication，以下走 AVAudioSession
        let micGranted: Bool
        if #available(iOS 17.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        isAuthorized = micGranted
        return micGranted
    }

    // MARK: 转写

    /// 开始转写。重复调用 / 切换语言安全：会先取消旧会话再建立新会话。
    /// 前置条件（契约）：仅在 isOnDeviceAvailable(for: language) 为 true 时调用。
    func startTranscribing(language: AppLanguage) {
        guard let recognizer = recognizers[language],
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            lastError = "当前设备或语言不支持本地语音输入，请使用文字描述"
            return
        }

        // 清理上一次会话（若仍在进行），保证重复调用安全
        cancelTranscribing()
        partialText = ""
        lastError = nil
        currentLanguage = language

        // 音频会话：录音场景；结束时通知其他 App 恢复播放
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            lastError = "音频会话配置失败：\(error.localizedDescription)"
            return
        }

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.requiresOnDeviceRecognition = true   // 纯本地，不联网
        recognitionRequest.shouldReportPartialResults = true     // partialText 渐进更新
        request = recognitionRequest

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            lastError = "录音启动失败：\(error.localizedDescription)"
            teardownAudioSession()
            request = nil
            return
        }

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            // 回调不在主线程；跳回 MainActor 更新状态
            Task { @MainActor [weak self] in
                guard let self, self.recognitionTask != nil else { return } // 已取消的会话忽略
                if let result {
                    self.partialText = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.finishSession()
                    }
                }
                if let error, self.recognitionTask != nil {
                    // 静音超时 / 识别错误：暴露错误状态、安全收尾，保持可重试，不崩溃
                    self.lastError = error.localizedDescription
                    self.finishSession()
                }
            }
        }
        isTranscribing = true
    }

    /// 正常结束：停止喂音频，让识别任务输出最终结果（partialText 即为最终文本）
    func stopTranscribing() {
        guard isTranscribing else { return }
        isTranscribing = false
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()          // 识别任务随后回调 isFinal，在 finishSession 收尾
        request = nil
        teardownAudioSession()
    }

    /// 取消：丢弃任务，不再等待最终结果；partialText 保留已识别内容供 UI 参考
    func cancelTranscribing() {
        guard isTranscribing || recognitionTask != nil else { return }
        isTranscribing = false
        let task = recognitionTask
        recognitionTask = nil        // 先置 nil，使随后的取消回调被忽略
        task?.cancel()
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request = nil
        teardownAudioSession()
    }

    // MARK: 私有

    /// 识别任务自然结束（isFinal / error）后的统一收尾
    private func finishSession() {
        isTranscribing = false
        recognitionTask = nil
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request = nil
        teardownAudioSession()
    }

    private func teardownAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
