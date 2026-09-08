import SwiftUI

// MARK: - 首页（需求 §7.3.1）
//
// 顶部极简标题 + 右上角设置 / 历史入口；中部 2D 人体热区图（占屏主体）；
// 底部固定双按钮「新建记录」「常用模板」。
// 降级提示条：内存模式（§9）与加密密钥重建（§9 / CryptoError.keyRebuilt）。

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: CoreDataStore

    @State private var selectedRegionId: String?
    @State private var use3DBody = true // 人体可视化默认 3D（§3.3），可切回 2D 热区图
    @State private var guideRegion: BodyRegion?
    @State private var showRecordFlow = false
    @State private var showTemplates = false
    @State private var showHistory = false
    @State private var showSettings = false

    private var selectedRegion: BodyRegion? {
        selectedRegionId.flatMap { StaticContent.region(id: $0) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: 降级提示条
                if appState.inMemoryFallback {
                    noticeBanner(text: Compliance.inMemoryFallbackHint,
                                 icon: "internaldrive",
                                 tint: DT.Color.levelModerate)
                }
                if store.encryptionKeyWasRebuilt {
                    noticeBanner(text: Compliance.keyRebuiltHint,
                                 icon: "key.fill",
                                 tint: DT.Color.levelModerate)
                }

                ScrollView {
                    VStack(spacing: 16) {
                        // MARK: 人体可视化核心区（默认 3D，可切回 2D 热区图，§3.3）
                        ZStack(alignment: .topTrailing) {
                            Group {
                                if use3DBody {
                                    BodyScene3DView(selectedRegionId: $selectedRegionId)
                                } else {
                                    BodyMap2DView(selectedRegionId: $selectedRegionId)
                                }
                            }

                            // 3D/2D 胶囊切换
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                    use3DBody.toggle()
                                }
                            } label: {
                                Text(use3DBody ? "2D" : "3D")
                                    .font(DT.Font.auxiliary.weight(.semibold))
                                    .foregroundStyle(DT.Color.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(DT.Color.background.opacity(0.92))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(DT.Color.primary.opacity(0.35), lineWidth: 1)
                                    )
                            }
                            .padding(.top, 58) // 避开 3D/2D 视图内右上角的「列表」入口
                            .padding(.trailing, 6)
                            .accessibilityLabel(use3DBody ? "切换到 2D 热区图" : "切换到 3D 人体模型")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // MARK: 选中部位信息卡
                        if let region = selectedRegion {
                            RegionInfoCard(region: region) { guideTarget in
                                guideRegion = guideTarget
                            }
                            .padding(.horizontal, 16)
                            // 卡片选中上浮 2pt + 阴影增强（§7.4）
                            .offset(y: -2)
                            .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.bottom, 12)
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.8), value: selectedRegionId)

                // MARK: 底部固定双按钮
                HStack(spacing: 12) {
                    Button {
                        showRecordFlow = true
                    } label: {
                        Label("新建记录", systemImage: "plus.circle.fill")
                            .font(DT.Font.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(DT.Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.button))
                    }
                    .accessibilityHint("开始一次新的身体状态记录")

                    Button {
                        showTemplates = true
                    } label: {
                        Label("常用模板", systemImage: "doc.text.fill")
                            .font(DT.Font.body.weight(.semibold))
                            .foregroundStyle(DT.Color.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(DT.Color.primaryLight)
                            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.button))
                    }
                    .accessibilityHint("浏览内置高频放松沟通模板")
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(DT.Color.background)
            }
            .background(DT.Color.layeredBackground.ignoresSafeArea())
            .navigationTitle("肌肉放松")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(DT.Color.primary)
                    }
                    .accessibilityLabel("历史记录")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(DT.Color.primary)
                    }
                    .accessibilityLabel("设置")
                }
            }
            // 新建记录流程（sheet 分步）
            .sheet(isPresented: $showRecordFlow) {
                RecordFlowView(initialRegionId: selectedRegionId)
            }
            // 常用模板速览（套用入口在记录流程内，此处仅浏览）
            .sheet(isPresented: $showTemplates) {
                TemplateBrowseSheet {
                    showTemplates = false
                    showRecordFlow = true
                }
            }
            // 历史记录
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
            // 设置
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            // 舒缓参考
            .sheet(item: $guideRegion) { region in
                StretchGuideSheet(region: region)
            }
        }
    }

    private func noticeBanner(text: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(DT.Font.auxiliary)
                .foregroundStyle(DT.Color.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("提示：\(text)")
    }
}

// MARK: - 模板速览（首页「常用模板」入口；套用走记录流程保证部位确认完整）

private struct TemplateBrowseSheet: View {
    var onStartRecord: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(StaticContent.builtinTemplates) { template in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(template.name)
                                    .font(DT.Font.body.weight(.medium))
                                    .foregroundStyle(DT.Color.textPrimary)
                                Spacer()
                                if let region = StaticContent.region(id: template.regionId) {
                                    Text(region.displayName)
                                        .font(DT.Font.auxiliary)
                                        .foregroundStyle(DT.Color.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(DT.Color.primaryLight)
                                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.tag))
                                }
                            }
                            Text(template.content)
                                .font(DT.Font.auxiliary)
                                .foregroundStyle(DT.Color.textSecondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("内置高频模板")
                } footer: {
                    Text("模板为通用身体放松常识整理，仅供沟通参考。新建记录时可直接套用。")
                }

                Section {
                    Button {
                        dismiss()
                        onStartRecord()
                    } label: {
                        Label("新建记录并套用模板", systemImage: "arrow.right.circle.fill")
                            .font(DT.Font.body.weight(.medium))
                            .foregroundStyle(DT.Color.primary)
                    }
                }
            }
            .navigationTitle("常用模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
