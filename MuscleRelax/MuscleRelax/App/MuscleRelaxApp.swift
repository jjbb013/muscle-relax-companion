import SwiftUI

// MARK: - App 入口（需求 §7.3 / §8.2 / §9）
//
// 装配链：AppState 在首屏 .task 中创建 CoreDataStore（try? 正常加载，
// 失败降级 CoreDataStore(inMemory: true) 并展示提示横幅）；
// settings.onboardingCompleted 为 false 或免责声明版本过期时先进入 DisclaimerView。
// 详见 UI/AppState.swift 与 UI/ContentView.swift。

@main
struct MuscleRelaxApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
