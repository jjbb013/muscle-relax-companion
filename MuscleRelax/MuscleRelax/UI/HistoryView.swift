import SwiftUI

// MARK: - 历史记录与复盘（需求 §6.7）
//
// 列表按时间倒序（部位、等级色标 + 文字、时间、来源标签）；
// 筛选：部位 / 等级；详情页：完整文案 + 重新播报 + 编辑 + 删除；
// 复盘视图：近 30 天部位分布条形图 + 等级趋势（SwiftUI 原生绘制，零第三方图表库）；
// 清空全部数据需二次确认（confirmationDialog）。

struct HistoryView: View {
    @EnvironmentObject private var store: CoreDataStore
    @Environment(\.dismiss) private var dismiss

    @State private var filterRegionId: String?
    @State private var filterLevel: SoreLevel?
    @State private var showReview = false
    @State private var detailRecord: SoreRecordData?
    @State private var showClearConfirm = false

    private var filteredRecords: [SoreRecordData] {
        store.records.filter { record in
            if let filterRegionId, record.regionId != filterRegionId { return false }
            if let filterLevel, record.level != filterLevel { return false }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: 筛选栏
                HStack(spacing: 10) {
                    Menu {
                        Button("全部部位") { filterRegionId = nil }
                        ForEach(StaticContent.regions) { region in
                            Button(region.displayName) { filterRegionId = region.id }
                        }
                    } label: {
                        filterChip(title: filterRegionId.flatMap { StaticContent.region(id: $0) }?.displayName ?? "部位",
                                   active: filterRegionId != nil)
                    }
                    .accessibilityLabel("按部位筛选")
                    .accessibilityHint(filterRegionId == nil ? "当前为全部部位" : "双击修改部位筛选")

                    Menu {
                        Button("全部等级") { filterLevel = nil }
                        ForEach(SoreLevel.allCases, id: \.rawValue) { level in
                            Button("Lv.\(level.rawValue) \(level.displayName)") { filterLevel = level }
                        }
                    } label: {
                        filterChip(title: filterLevel.map { "Lv.\($0.rawValue) \($0.displayName)" } ?? "等级",
                                   active: filterLevel != nil)
                    }
                    .accessibilityLabel("按等级筛选")

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            showReview.toggle()
                        }
                    } label: {
                        Label("复盘", systemImage: showReview ? "chart.bar.fill" : "chart.bar")
                            .font(DT.Font.auxiliary.weight(.medium))
                            .foregroundStyle(showReview ? .white : DT.Color.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(showReview ? DT.Color.primary : DT.Color.primaryLight)
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel("近 30 天复盘视图")
                    .accessibilityHint(showReview ? "双击收起" : "双击展开")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if showReview {
                    ReviewPanel(records: store.records)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // MARK: 记录列表
                if filteredRecords.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundStyle(DT.Color.textSecondary)
                            .accessibilityHidden(true)
                        Text(store.records.isEmpty ? "还没有记录" : "没有符合筛选条件的记录")
                            .font(DT.Font.body)
                            .foregroundStyle(DT.Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredRecords) { record in
                            Button {
                                detailRecord = record
                            } label: {
                                recordRow(record)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(rowAccessibilityLabel(record))
                            .accessibilityHint("双击查看详情")
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.deleteRecord(id: filteredRecords[index].id)
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                // MARK: 清空全部（二次确认，§6.7.4）
                if !store.records.isEmpty {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Text("清空全部数据")
                            .font(DT.Font.auxiliary)
                            .foregroundStyle(DT.Color.levelSevere)
                    }
                    .padding(.bottom, 8)
                    .accessibilityHint("删除所有历史记录，操作前会再次确认")
                }
            }
            .background(DT.Color.layeredBackground.ignoresSafeArea())
            .navigationTitle("历史记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .confirmationDialog("清空全部数据？",
                                isPresented: $showClearConfirm,
                                titleVisibility: .visible) {
                Button("删除全部 \(store.records.count) 条记录", role: .destructive) {
                    store.deleteAllRecords()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作不可撤销。建议先在设置中导出备份。")
            }
            .sheet(item: $detailRecord) { record in
                RecordDetailView(record: record)
            }
            // 数据写入失败提示（§9）
            .alert("操作未完成", isPresented: storeErrorBinding) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(store.lastErrorMessage ?? "")
            }
        }
    }

    private var storeErrorBinding: Binding<Bool> {
        Binding(
            get: { store.lastErrorMessage != nil },
            set: { _ in }
        )
    }

    private func filterChip(title: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(DT.Font.auxiliary.weight(.medium))
            Image(systemName: "chevron.down")
                .font(.system(size: 10))
                .accessibilityHidden(true)
        }
        .foregroundStyle(active ? .white : DT.Color.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(active ? DT.Color.primary : DT.Color.primaryLight)
        .clipShape(Capsule())
    }

    private func recordRow(_ record: SoreRecordData) -> some View {
        HStack(spacing: 12) {
            // 等级色标（颜色 + 文字双载体，§10.3）
            VStack(spacing: 2) {
                Text("Lv.\(record.level.rawValue)")
                    .font(DT.Font.auxiliary.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            .background(DT.levelColor(record.level))
            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.tag))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(StaticContent.region(id: record.regionId)?.displayName ?? record.regionId)
                        .font(DT.Font.body.weight(.medium))
                        .foregroundStyle(DT.Color.textPrimary)
                    Text(record.level.displayName)
                        .font(DT.Font.auxiliary)
                        .foregroundStyle(DT.levelColor(record.level))
                }
                HStack(spacing: 8) {
                    Text(record.createdAt, format: .dateTime.year().month().day().hour().minute())
                        .font(DT.Font.auxiliary)
                        .foregroundStyle(DT.Color.textSecondary)
                    Text(record.source.displayName)
                        .font(DT.Font.auxiliary)
                        .foregroundStyle(DT.Color.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(DT.Color.primaryLight)
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.tag))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(DT.Color.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }

    private func rowAccessibilityLabel(_ record: SoreRecordData) -> String {
        let region = StaticContent.region(id: record.regionId)?.displayName ?? record.regionId
        return "\(region)，等级 \(record.level.rawValue) \(record.level.displayName)，来源 \(record.source.displayName)，\(record.createdAt.formatted(date: .numeric, time: .shortened))"
    }
}

// MARK: - 记录详情（完整文案 + 重新播报 + 编辑 + 删除）

private struct RecordDetailView: View {
    let record: SoreRecordData

    @EnvironmentObject private var store: CoreDataStore
    @Environment(\.dismiss) private var dismiss

    @State private var editing = false
    @State private var editedText: String = ""
    @State private var editedLevel: SoreLevel = .mild
    @State private var levelTouched = true
    @State private var showDeleteConfirm = false

    private var regionName: String {
        StaticContent.region(id: record.regionId)?.displayName ?? record.regionId
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 元信息
                    HStack(spacing: 8) {
                        Text(regionName)
                            .font(DT.Font.title)
                            .foregroundStyle(DT.Color.textPrimary)
                        Text("Lv.\(record.level.rawValue) \(record.level.displayName)")
                            .font(DT.Font.auxiliary.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(DT.levelColor(record.level))
                            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.tag))
                        Spacer()
                    }

                    Text(record.createdAt, format: .dateTime.year().month().day().weekday().hour().minute())
                        .font(DT.Font.auxiliary)
                        .foregroundStyle(DT.Color.textSecondary)

                    if !record.symptomText.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("症状描述")
                                .font(DT.Font.body.weight(.medium))
                                .foregroundStyle(DT.Color.textPrimary)
                            Text(record.symptomText)
                                .font(DT.Font.body)
                                .foregroundStyle(DT.Color.textBody)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // 完整文案 / 编辑
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("沟通文案")
                                .font(DT.Font.body.weight(.medium))
                                .foregroundStyle(DT.Color.textPrimary)
                            Spacer()
                            Button(editing ? "完成" : "编辑") {
                                if editing {
                                    saveEdits()
                                } else {
                                    editedText = record.generatedText
                                    editedLevel = record.level
                                    editing = true
                                }
                            }
                            .font(DT.Font.auxiliary.weight(.medium))
                            .foregroundStyle(DT.Color.primary)
                            .accessibilityLabel(editing ? "完成编辑并保存" : "编辑沟通文案与等级")
                        }

                        if editing {
                            LevelSelector(level: $editedLevel, touched: $levelTouched)
                            TextEditor(text: $editedText)
                                .font(DT.Font.body)
                                .frame(minHeight: 140)
                                .padding(8)
                                .background(DT.Color.background)
                                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.tag))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DT.Radius.tag)
                                        .stroke(DT.Color.textSecondary.opacity(0.3), lineWidth: 1)
                                )
                        } else {
                            Text(record.generatedText)
                                .font(DT.Font.body)
                                .foregroundStyle(DT.Color.textBody)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(DT.Color.background)
                                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
                                .cardShadow()
                        }
                    }

                    Text(Compliance.unifiedStatement)
                        .font(DT.Font.auxiliary)
                        .foregroundStyle(DT.Color.textSecondary)

                    // 重新播报
                    if !editing {
                        NavigationLink {
                            BroadcastView(
                                text: record.generatedText,
                                initialLanguage: store.settings.language
                            )
                            .navigationTitle("重新播报")
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            Label("重新播报", systemImage: "speaker.wave.2.fill")
                                .font(DT.Font.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(DT.Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.button))
                        }
                        .accessibilityHint("以大字与语音重新展示这条记录")

                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("删除这条记录", systemImage: "trash")
                                .font(DT.Font.body.weight(.medium))
                                .foregroundStyle(DT.Color.levelSevere)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                    }
                }
                .padding(16)
            }
            .background(DT.Color.layeredBackground.ignoresSafeArea())
            .navigationTitle("记录详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .confirmationDialog("删除这条记录？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    store.deleteRecord(id: record.id)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后不可恢复。")
            }
        }
    }

    private func saveEdits() {
        var updated = record
        updated.generatedText = editedText
        updated.level = editedLevel
        store.updateRecord(updated)
        editing = false
    }
}

// MARK: - 复盘视图（近 30 天，SwiftUI 原生绘制，§6.7.3）

private struct ReviewPanel: View {

    let records: [SoreRecordData]

    private struct RegionCount: Identifiable {
        var id: String { name }
        let name: String
        let count: Int
    }

    private struct WeekLevel: Identifiable {
        let id: Int
        let label: String
        let average: Double?   // nil = 该周无记录
        let count: Int
    }

    private var recentRecords: [SoreRecordData] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return records.filter { $0.createdAt >= cutoff }
    }

    private var regionCounts: [RegionCount] {
        var counts: [String: Int] = [:]
        for record in recentRecords {
            let name = StaticContent.region(id: record.regionId)?.displayName ?? record.regionId
            counts[name, default: 0] += 1
        }
        return counts.map { RegionCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    /// 近 4 周等级趋势：每周平均等级（无记录则置空）
    private var weeklyLevels: [WeekLevel] {
        let calendar = Calendar.current
        var result: [WeekLevel] = []
        for weekOffset in stride(from: 3, through: 0, by: -1) {
            guard let start = calendar.date(byAdding: .day, value: -7 * (weekOffset + 1) + 1, to: Date()),
                  let end = calendar.date(byAdding: .day, value: -7 * weekOffset, to: Date()) else { continue }
            let weekRecords = recentRecords.filter { $0.createdAt >= start && $0.createdAt < end }
            let average: Double? = weekRecords.isEmpty
                ? nil
                : Double(weekRecords.map(\.level.rawValue).reduce(0, +)) / Double(weekRecords.count)
            result.append(WeekLevel(id: weekOffset,
                                    label: weekOffset == 0 ? "本周" : "\(weekOffset) 周前",
                                    average: average,
                                    count: weekRecords.count))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("近 30 天复盘")
                    .font(DT.Font.body.weight(.semibold))
                    .foregroundStyle(DT.Color.textPrimary)
                Spacer()
                Text("\(recentRecords.count) 条记录")
                    .font(DT.Font.auxiliary)
                    .foregroundStyle(DT.Color.textSecondary)
            }

            if recentRecords.isEmpty {
                Text("近 30 天暂无记录")
                    .font(DT.Font.auxiliary)
                    .foregroundStyle(DT.Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                // 部位分布条形图
                Text("部位分布")
                    .font(DT.Font.auxiliary.weight(.medium))
                    .foregroundStyle(DT.Color.textSecondary)
                let maxCount = regionCounts.map(\.count).max() ?? 1
                ForEach(regionCounts.prefix(8)) { item in
                    HStack(spacing: 8) {
                        Text(item.name)
                            .font(DT.Font.auxiliary)
                            .foregroundStyle(DT.Color.textBody)
                            .frame(width: 64, alignment: .trailing)
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: DT.Radius.tag)
                                .fill(LinearGradient(colors: [DT.Color.primary, DT.Color.primaryLight],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(8, proxy.size.width * CGFloat(item.count) / CGFloat(maxCount)))
                        }
                        .frame(height: 16)
                        Text("\(item.count)")
                            .font(DT.Font.auxiliary.weight(.medium))
                            .foregroundStyle(DT.Color.textPrimary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(item.name)，\(item.count) 条")
                }

                // 等级趋势（每周平均等级，颜色即等级色标，附文字）
                Text("等级趋势（每周平均）")
                    .font(DT.Font.auxiliary.weight(.medium))
                    .foregroundStyle(DT.Color.textSecondary)
                    .padding(.top, 4)
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(weeklyLevels) { week in
                        VStack(spacing: 4) {
                            if let average = week.average {
                                let level = SoreLevel(rawValue: Int(average.rounded())) ?? .mild
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(DT.levelColor(level))
                                    .frame(height: 20 + 30 * CGFloat(average) / 3)
                                Text(String(format: "%.1f", average))
                                    .font(DT.Font.auxiliary)
                                    .foregroundStyle(DT.Color.textBody)
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(DT.Color.layeredBackground)
                                    .frame(height: 20)
                                Text("无")
                                    .font(DT.Font.auxiliary)
                                    .foregroundStyle(DT.Color.textSecondary)
                            }
                            Text(week.label)
                                .font(DT.Font.auxiliary)
                                .foregroundStyle(DT.Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(week.average.map {
                            "\(week.label)，平均等级 \(String(format: "%.1f", $0))，\(week.count) 条记录"
                        } ?? "\(week.label)，无记录")
                    }
                }
            }
        }
        .padding(16)
        .background(DT.Color.background)
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
        .cardShadow()
    }
}
