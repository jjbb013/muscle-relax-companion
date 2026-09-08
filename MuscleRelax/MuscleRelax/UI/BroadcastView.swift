import SwiftUI

// MARK: - 播报展示（需求 §6.4 双通道无障碍沟通）
//
// 用户把手机递给按摩师：
// - 视障从业者 → 语音播报（AVSpeechSynthesizer，BroadcastService）
// - 听障从业者 → 屏幕超大号加粗静态文字（≥ 34pt Bold，DT.Font.broadcast）
// 两者互为兜底。
//
// 逐段高亮：拆句规则与 BroadcastService 完全一致（复用其 splitSentences），
// highlightedSentenceIndex 驱动当前句段高亮。
// 语言跟随 settings.language，可在页面临时切换（中 / 英 / 日）。
// 顶栏固定非医疗属性轻提示（§8.2.2，不弹窗）。

struct BroadcastView: View {
    let text: String
    /// 默认语言（跟随设置），页面内可临时切换
    let initialLanguage: AppLanguage
    /// 是否已保存（记录流程传入）
    var saved: Bool = false
    /// 保存记录回调；为 nil 时不展示保存按钮（如历史记录重播场景）
    var onSave: (() -> Void)? = nil
    /// 顶栏是否显示非医疗轻提示（历史详情页同样展示）
    var showComplianceHint: Bool = true

    @EnvironmentObject private var broadcast: BroadcastService
    @State private var language: AppLanguage

    init(text: String,
         initialLanguage: AppLanguage,
         saved: Bool = false,
         onSave: (() -> Void)? = nil,
         showComplianceHint: Bool = true) {
        self.text = text
        self.initialLanguage = initialLanguage
        self.saved = saved
        self.onSave = onSave
        self.showComplianceHint = showComplianceHint
        _language = State(initialValue: initialLanguage)
    }

    /// 与 BroadcastService 内部拆句保持一致的句段（静态方法直接复用）
    private var sentences: [String] {
        BroadcastService.splitSentences(text)
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: 顶栏固定轻提示（非医疗属性）
            if showComplianceHint {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .accessibilityHidden(true)
                    Text(Compliance.broadcastHint)
                        .font(DT.Font.auxiliary)
                }
                .foregroundStyle(DT.Color.textSecondary)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(DT.Color.layeredBackground)
                .accessibilityElement(children: .combine)
            }

            // MARK: 超大号文字（逐段高亮）
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                        let highlighted = broadcast.highlightedSentenceIndex == index
                        Text(sentence)
                            .font(DT.Font.broadcast)
                            .foregroundStyle(highlighted ? DT.Color.primary : DT.Color.textPrimary)
                            .lineSpacing(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: DT.Radius.tag)
                                    .fill(highlighted ? DT.Color.primaryLight : .clear)
                            )
                            .animation(.easeInOut(duration: 0.2), value: highlighted)
                            .accessibilityLabel(sentence)
                            .accessibilityHint(highlighted ? "正在播报" : "")
                    }
                }
                .padding(20)
            }

            // MARK: 控制区
            VStack(spacing: 14) {
                // 语言切换（临时，不写回设置）
                Picker("播报语言", selection: $language) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("播报语言切换")
                .onChange(of: language) { newValue in
                    if broadcast.isSpeaking {
                        broadcast.speak(text: text, language: newValue)
                    }
                }

                HStack(spacing: 12) {
                    // 暂停 / 继续
                    Button {
                        if broadcast.isPaused {
                            broadcast.resume()
                        } else {
                            broadcast.pause()
                        }
                    } label: {
                        Label(broadcast.isPaused ? "继续" : "暂停",
                              systemImage: broadcast.isPaused ? "play.fill" : "pause.fill")
                            .font(DT.Font.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(broadcast.isSpeaking ? DT.Color.primary : DT.Color.textSecondary.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.button))
                    }
                    .disabled(!broadcast.isSpeaking)
                    .accessibilityLabel(broadcast.isPaused ? "继续播报" : "暂停播报")

                    // 重播
                    Button {
                        broadcast.speak(text: text, language: language)
                    } label: {
                        Label("重播", systemImage: "arrow.clockwise")
                            .font(DT.Font.body.weight(.semibold))
                            .foregroundStyle(DT.Color.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(DT.Color.primaryLight)
                            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.button))
                    }
                    .accessibilityLabel("从头重新播报")
                }

                // 播报失败兜底提示（§9：大字展示完整保留）
                if !broadcast.isSpeaking {
                    Text("若无声音，请检查系统音量与静音开关；屏幕文字可完整展示。")
                        .font(DT.Font.auxiliary)
                        .foregroundStyle(DT.Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // 保存记录（仅记录流程）
                if let onSave {
                    Button(action: onSave) {
                        Label(saved ? "已保存到历史记录" : "保存记录",
                              systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                            .font(DT.Font.body.weight(.semibold))
                            .foregroundStyle(saved ? DT.Color.textSecondary : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(saved ? DT.Color.layeredBackground : DT.Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.button))
                    }
                    .disabled(saved)
                    .accessibilityLabel(saved ? "记录已保存" : "保存这条记录")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(DT.Color.background)
        }
        .background(DT.Color.background.ignoresSafeArea())
        .onAppear {
            broadcast.speak(text: text, language: language)
        }
        .onDisappear {
            broadcast.stop()
        }
    }
}
