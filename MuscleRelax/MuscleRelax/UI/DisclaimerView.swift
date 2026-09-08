import SwiftUI

// MARK: - 首启免责声明（需求 §8.2.1）
//
// 强制交互：必须滚动至底部才启用「同意并进入」按钮。
// 同意后写入 disclaimerAcceptedVersion（当前版本）与 onboardingCompleted = true；
// 条款更新时递增 Compliance.disclaimerVersion，旧版本用户会被 ContentView 重新引导至此。

struct DisclaimerView: View {
    @EnvironmentObject private var store: CoreDataStore

    @State private var reachedBottom = false
    @State private var showScrollHint = true

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题
            VStack(spacing: 8) {
                Text("使用须知与免责声明")
                    .font(DT.Font.largeTitle)
                    .foregroundStyle(DT.Color.textPrimary)
                Text("请完整阅读至底部后继续")
                    .font(DT.Font.auxiliary)
                    .foregroundStyle(DT.Color.textSecondary)
            }
            .padding(.top, 28)
            .padding(.bottom, 16)

            // 正文（滚动到底部检测：底部锚点 onAppear）
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(Compliance.disclaimerText)
                        .font(DT.Font.body)
                        .foregroundStyle(DT.Color.textBody)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("免责声明全文。\(Compliance.unifiedStatement)")

                    // 底部锚点：进入可视区域即视为读到底部
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                reachedBottom = true
                                showScrollHint = false
                            }
                        }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .background(DT.Color.layeredBackground)
            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
            .cardShadow()
            .padding(.horizontal, 20)
            .overlay(alignment: .bottom) {
                if showScrollHint {
                    Text("向下滚动阅读全文")
                        .font(DT.Font.auxiliary)
                        .foregroundStyle(DT.Color.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(DT.Color.primaryLight)
                        .clipShape(Capsule())
                        .padding(.bottom, 16)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }

            // 底部操作区
            VStack(spacing: 10) {
                Button(action: accept) {
                    Text(reachedBottom ? "同意并进入" : "请先滚动阅读至底部")
                        .font(DT.Font.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(reachedBottom ? DT.Color.primary : DT.Color.textSecondary.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.button))
                }
                .disabled(!reachedBottom)
                .accessibilityLabel(reachedBottom ? "同意并进入" : "同意并进入，需先阅读完整免责声明")
                .accessibilityHint(reachedBottom ? "" : "请先滚动阅读免责声明至底部")

                Text("版本 v\(Compliance.disclaimerVersion) · 条款更新后需重新确认")
                    .font(DT.Font.auxiliary)
                    .foregroundStyle(DT.Color.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .background(DT.Color.background.ignoresSafeArea())
        // 免责声明为强制步骤，不允许手势返回跳过
        .interactiveDismissDisabled()
    }

    private func accept() {
        var settings = store.settings
        settings.disclaimerAcceptedVersion = Compliance.disclaimerVersion
        settings.onboardingCompleted = true
        store.updateSettings(settings)
    }
}

#Preview {
    DisclaimerView()
        .environmentObject(try! CoreDataStore(inMemory: true))
}
