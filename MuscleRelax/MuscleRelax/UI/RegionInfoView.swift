import SwiftUI

// MARK: - 部位信息卡 + 舒缓参考（需求 §6.1.3 / §6.6）
//
// 点选部位后展示：肌肉名称、常用按压点（统一标注"位置示意，仅供参考"）、
// 常见疲劳场景、放松方式建议，并提供「查看舒缓参考」教程入口。
// 全部内容为静态通识整理，非医疗口径。

struct RegionInfoCard: View {
    let region: BodyRegion
    var onShowGuides: ((BodyRegion) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 标题行
            HStack(alignment: .firstTextBaseline) {
                Text(region.displayName)
                    .font(DT.Font.title)
                    .foregroundStyle(DT.Color.textPrimary)
                Spacer()
                Text(region.category.displayName)
                    .font(DT.Font.auxiliary)
                    .foregroundStyle(DT.Color.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(DT.Color.primaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: DT.Radius.tag))
            }

            infoSection(title: "关联肌肉",
                        items: region.muscleNames,
                        bulletStyle: .chips)

            VStack(alignment: .leading, spacing: 6) {
                Text("常用按压点")
                    .font(DT.Font.body.weight(.medium))
                    .foregroundStyle(DT.Color.textPrimary)
                ForEach(region.pressPoints) { point in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(DT.Color.primary)
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                        Text(point.name)
                            .font(DT.Font.body)
                            .foregroundStyle(DT.Color.textBody)
                        Text("（\(Compliance.pressPointNote)）")
                            .font(DT.Font.auxiliary)
                            .foregroundStyle(DT.Color.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("按压点 \(point.name)，\(Compliance.pressPointNote)")
                }
            }

            infoSection(title: "常见疲劳场景", items: region.fatigueScenes, bulletStyle: .list)
            infoSection(title: "放松方式建议", items: region.relaxSuggestions, bulletStyle: .list)

            // 舒缓参考入口
            let guides = StaticContent.stretchGuides(forRegionId: region.id)
            if !guides.isEmpty {
                Button {
                    onShowGuides?(region)
                } label: {
                    Label("查看舒缓参考（\(guides.count) 篇）", systemImage: "figure.cooldown")
                        .font(DT.Font.body.weight(.medium))
                        .foregroundStyle(DT.Color.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(DT.Color.primaryLight)
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.button))
                }
                .accessibilityHint("打开该部位的日常舒缓动作参考")
            }

            Text(Compliance.unifiedStatement)
                .font(DT.Font.auxiliary)
                .foregroundStyle(DT.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(DT.Color.background)
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
        .cardShadow()
    }

    private enum BulletStyle { case chips, list }

    @ViewBuilder
    private func infoSection(title: String, items: [String], bulletStyle: BulletStyle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(DT.Font.body.weight(.medium))
                .foregroundStyle(DT.Color.textPrimary)
            switch bulletStyle {
            case .chips:
                FlowChips(items: items)
            case .list:
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("·")
                            .foregroundStyle(DT.Color.primary)
                            .accessibilityHidden(true)
                        Text(item)
                            .font(DT.Font.body)
                            .foregroundStyle(DT.Color.textBody)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

/// 轻量流式标签布局（iOS 16 兼容，无 Layout 协议需求外依赖；使用 iOS 16 Layout 亦可，这里手写保证稳定）
private struct FlowChips: View {
    let items: [String]

    var body: some View {
        // 简化实现：单行横向滚动，避免自研流式布局的复杂度
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(DT.Font.auxiliary)
                        .foregroundStyle(DT.Color.textBody)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(DT.Color.layeredBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.tag))
                }
            }
        }
        .accessibilityLabel("关联肌肉：" + items.joined(separator: "，"))
    }
}

// MARK: - 舒缓参考教程页（需求 §6.6：静态图文，无外链）

struct StretchGuideSheet: View {
    let region: BodyRegion
    @Environment(\.dismiss) private var dismiss

    private var guides: [StretchGuide] {
        StaticContent.stretchGuides(forRegionId: region.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(guides) { guide in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(guide.title)
                                .font(DT.Font.title)
                                .foregroundStyle(DT.Color.textPrimary)

                            ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(DT.Font.auxiliary.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(DT.Color.primary)
                                        .clipShape(Circle())
                                        .accessibilityHidden(true)
                                    Text(step)
                                        .font(DT.Font.body)
                                        .foregroundStyle(DT.Color.textBody)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("第 \(index + 1) 步：\(step)")
                            }

                            Text(guide.sourceNote)
                                .font(DT.Font.auxiliary)
                                .foregroundStyle(DT.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DT.Color.background)
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
                        .cardShadow()
                    }

                    Text(Compliance.unifiedStatement)
                        .font(DT.Font.auxiliary)
                        .foregroundStyle(DT.Color.textSecondary)
                        .padding(.horizontal, 4)
                }
                .padding(16)
            }
            .background(DT.Color.layeredBackground.ignoresSafeArea())
            .navigationTitle("\(region.displayName) · 舒缓参考")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
