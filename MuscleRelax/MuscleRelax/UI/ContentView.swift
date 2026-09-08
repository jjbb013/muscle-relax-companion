import SwiftUI

// MARK: - 根视图（需求 §7.3）
//
// 启动门控：加载数据层 → 免责声明（首启 / 条款版本更新）→ 首页。
// 大字模式（settings.largeTextMode）在此全局放大正文动态字体。

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.loadState {
            case .idle, .loading:
                VStack(spacing: 16) {
                    ProgressView()
                    Text("正在准备本地数据…")
                        .font(DT.Font.auxiliary)
                        .foregroundStyle(DT.Color.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let message):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(DT.Color.levelModerate)
                        .accessibilityHidden(true)
                    Text("应用暂时无法启动")
                        .font(DT.Font.title)
                        .foregroundStyle(DT.Color.textPrimary)
                    Text(message)
                        .font(DT.Font.body)
                        .foregroundStyle(DT.Color.textBody)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .ready:
                if let store = appState.store {
                    ReadyRootView()
                        .environmentObject(store)
                        .environmentObject(appState.speech)
                        .environmentObject(appState.broadcast)
                        .environmentObject(appState.reminder)
                }
            }
        }
        .background(DT.Color.background.ignoresSafeArea())
        .task { appState.loadIfNeeded() }
    }
}

/// 就绪后的根视图：直接通过 @EnvironmentObject 订阅 CoreDataStore。
/// 注意：门控判断必须放在这里而不是 ContentView —— AppState.store 不是
/// @Published，settings 更新不会触发 ContentView 重算，
/// 会导致免责声明「同意并进入」点击后页面不切换。
private struct ReadyRootView: View {
    @EnvironmentObject private var store: CoreDataStore

    var body: some View {
        Group {
            #if DEBUG
            // 调试通道：自动化截图验证可绕过免责声明门控（Release 不受影响）
            if ProcessInfo.processInfo.arguments.contains("-SkipDisclaimerPreview") {
                HomeView()
            } else if !store.settings.onboardingCompleted
                || store.settings.disclaimerAcceptedVersion != Compliance.disclaimerVersion {
                DisclaimerView()
            } else {
                HomeView()
            }
            #else
            if !store.settings.onboardingCompleted
                || store.settings.disclaimerAcceptedVersion != Compliance.disclaimerVersion {
                DisclaimerView()
            } else {
                HomeView()
            }
            #endif
        }
        .modifier(LargeTextModeModifier(enabled: store.settings.largeTextMode))
    }
}

/// 大字模式：开启后把动态字体基准抬到 .accessibility1（需求 §7.3.4 / §10.2）
private struct LargeTextModeModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.dynamicTypeSize(.accessibility1)
        } else {
            content
        }
    }
}
