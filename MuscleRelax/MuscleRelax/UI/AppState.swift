import Foundation
import SwiftUI
import Combine

// MARK: - 应用级状态装配（需求 §7.3 / §9）
//
// 负责在启动时创建数据仓库与各服务，并处理 §9 的降级链：
//   1) `try? CoreDataStore()` 正常加载本地加密数据库；
//   2) 失败 → `try? CoreDataStore(inMemory: true)` 内存降级，UI 显示提示横幅；
//   3) 仍失败（如 Keychain 不可写）→ 展示致命错误页，不进入主功能。
//
// 延迟到首屏 `.task` 中加载（@MainActor），避免在 App 属性初始化期
// 触碰 @MainActor 的 CoreDataStore 构造器。

@MainActor
final class AppState: ObservableObject {

    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var loadState: LoadState = .idle
    /// 数据库初始化失败后的内存降级标记（需求 §9）
    @Published private(set) var inMemoryFallback = false
    /// 启动期间捕获的说明信息（如持久化加载失败描述）
    @Published private(set) var startupNotice: String?

    /// 数据仓库；仅在 loadState == .ready 时可用
    private(set) var store: CoreDataStore?

    // 共享服务（语音输入 / 播报 / 备份提醒 / 语义识别）
    let speech = SpeechInputService()
    let broadcast = BroadcastService()
    let reminder = BackupReminderService()
    let parser = SemanticParser()

    /// 幂等加载：仅在首次调用时执行
    func loadIfNeeded() {
        guard loadState == .idle else { return }
        loadState = .loading

        var firstError: Error?
        do {
            let store = try CoreDataStore()
            self.store = store
            loadState = .ready
            return
        } catch {
            firstError = error
            NSLog("[AppState] CoreDataStore 持久化加载失败: \(error)")
        }

        // 持久化失败 → 内存降级（需求 §9：功能完整但数据不保存）
        do {
            let store = try CoreDataStore(inMemory: true)
            self.store = store
            inMemoryFallback = true
            startupNotice = Compliance.inMemoryFallbackHint
            loadState = .ready
            return
        } catch {
            NSLog("[AppState] CoreDataStore 内存降级也失败: \(error)")
        }

        let detail = firstError.map { "（\($0.localizedDescription)）" } ?? ""
        loadState = .failed("数据存储初始化失败\(detail)。请重启应用后重试；若问题持续，请备份后重新安装应用。")
    }

    /// 是否需要先展示免责声明（首启或条款版本更新，§8.2.1）
    var needsDisclaimer: Bool {
        guard let settings = store?.settings else { return false }
        return !settings.onboardingCompleted
            || settings.disclaimerAcceptedVersion != Compliance.disclaimerVersion
    }
}
