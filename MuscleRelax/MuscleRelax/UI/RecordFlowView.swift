import SwiftUI

// MARK: - 记录流程（需求 §7.3.2，sheet 分步呈现）
//
// 步骤：① 选择部位 → ② 描述症状（语音 / 文字 / 模板三 Tab + 等级选择）
//      → ③ 生成沟通文案（可编辑 + 固定位置非医疗轻提示）→ ④ 播报展示。
// 每步可返回，全部状态保留在 ViewModel 中。
//
// 冲突处理（§6.2）：语音 / 文字经 SemanticParser.parse 得到候选部位，
// 与手动点选部位不一致时强制弹窗，并列展示两个候选，用户确认后才继续。

@MainActor
final class RecordFlowViewModel: ObservableObject {

    enum Step: Int, CaseIterable {
        case region = 0, symptom, message, broadcast

        var title: String {
            switch self {
            case .region: return "选择部位"
            case .symptom: return "描述症状"
            case .message: return "确认沟通文案"
            case .broadcast: return "播报展示"
            }
        }
    }

    enum InputTab: String, CaseIterable, Identifiable {
        case voice, text, template
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .voice: return "语音"
            case .text: return "文字"
            case .template: return "模板"
            }
        }
    }

    @Published var step: Step
    @Published var region: BodyRegion?
    @Published var inputTab: InputTab = .voice
    @Published var symptomText: String = ""
    @Published var level: SoreLevel = .mild
    @Published var levelTouchedByUser = false
    @Published var message: String = ""
    @Published var source: RecordSource = .manual
    @Published var templateId: String?

    /// 部位识别冲突（§6.2）：非 nil 时展示强制确认弹窗
    @Published var conflictMatch: SemanticMatch?

    /// 语音授权被拒提示
    @Published var speechAuthDenied = false

    init(initialRegionId: String?) {
        if let id = initialRegionId, let region = StaticContent.region(id: id) {
            self.region = region
            self.step = .symptom
        } else {
            self.region = nil
            self.step = .region
        }
    }

    var canProceedFromRegion: Bool { region != nil }

    /// 生成标准化沟通文案（§7.3.2 ③）
    /// 双侧 / 单侧部位的 displayName 已含"左 / 右"前缀（如"左肩"），居中部位无侧别，直接采用。
    func buildMessage() {
        guard let region else { return }
        let symptom = symptomText.trimmingCharacters(in: .whitespacesAndNewlines)
        let symptomClause = symptom.isEmpty ? "" : "。\(symptom)"
        message = "您好，我的\(region.displayName)感觉\(level.displayName)\(symptomClause)。希望重点放松这个部位，力度请随时和我确认，谢谢！"
    }

    /// 从症状步继续：语义识别 → 冲突确认（§6.2）或直接生成文案
    func proceedFromSymptom(parser: SemanticParser) {
        let trimmed = symptomText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = trimmed.isEmpty ? [] : parser.parse(trimmed)

        if let top = matches.first,
           let selected = region,
           top.regionId != selected.id,
           top.confidence >= 0.7 {
            // 识别部位与点选不一致：强制确认弹窗（§6.2），暂停前进
            conflictMatch = top
            return
        }

        // 无冲突：采纳等级推断（用户未手动改过等级时）
        if !levelTouchedByUser, let inferred = matches.first?.level {
            level = inferred
        }
        buildMessage()
        step = .message
    }

    /// 冲突确认结果：useRecognized = true 采用识别部位，否则保留手动点选
    func resolveConflict(useRecognized: Bool) {
        defer { conflictMatch = nil }
        if useRecognized, let match = conflictMatch,
           let matched = StaticContent.region(id: match.regionId) {
            region = matched
            if !levelTouchedByUser, let inferred = match.level {
                level = inferred
            }
        }
        buildMessage()
        step = .message
    }

    /// 套用模板（§6.5）：模板为用户显式选择，部位直接跟随模板，不走识别冲突
    func applyTemplate(_ template: BuiltinTemplate) {
        source = .template
        templateId = template.id
        if let templateRegion = StaticContent.region(id: template.regionId) {
            region = templateRegion
        }
        message = template.content
        step = .message
    }

    func applyUserTemplate(_ template: UserTemplateData) {
        source = .template
        templateId = template.id.uuidString
        if let templateRegion = StaticContent.region(id: template.regionId) {
            region = templateRegion
        }
        message = template.content
        step = .message
    }

    func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }
}

// MARK: - 流程视图

struct RecordFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: CoreDataStore
    @EnvironmentObject private var speech: SpeechInputService

    @StateObject private var vm: RecordFlowViewModel
    @State private var saved = false

    init(initialRegionId: String?) {
        _vm = StateObject(wrappedValue: RecordFlowViewModel(initialRegionId: initialRegionId))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Group {
                    switch vm.step {
                    case .region: regionStep
                    case .symptom: symptomStep
                    case .message: messageStep
                    case .broadcast: broadcastStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(DT.Color.layeredBackground.ignoresSafeArea())
            .navigationTitle(vm.step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        speech.cancelTranscribing()
                        dismiss()
                    }
                    .accessibilityHint("放弃本次记录")
                }
                if vm.step.rawValue > 0, vm.step != .broadcast {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            speech.cancelTranscribing()
                            vm.goBack()
                        } label: {
                            Label("上一步", systemImage: "chevron.left")
                        }
                        .accessibilityLabel("返回上一步，已填写内容保留")
                    }
                }
            }
            // 部位识别冲突：强制确认（§6.2）
            .alert("确认不适部位", isPresented: conflictBinding) {
                if let match = vm.conflictMatch,
                   let recognized = StaticContent.region(id: match.regionId) {
                    Button("点选的部位：\(vm.region?.displayName ?? "")") {
                        vm.resolveConflict(useRecognized: false)
                    }
                    Button("描述中提到的：\(recognized.displayName)") {
                        vm.resolveConflict(useRecognized: true)
                    }
                }
                Button("返回修改描述", role: .cancel) {
                    vm.conflictMatch = nil
                }
            } message: {
                if let match = vm.conflictMatch,
                   let recognized = StaticContent.region(id: match.regionId) {
                    Text("您点选的是「\(vm.region?.displayName ?? "")」，但描述内容更接近「\(recognized.displayName)」。为避免左右侧或部位误差，请确认最终部位后再继续。")
                }
            }
        }
    }

    private var conflictBinding: Binding<Bool> {
        Binding(
            get: { vm.conflictMatch != nil },
            set: { if !$0 { vm.conflictMatch = nil } }
        )
    }

    // MARK: 步骤指示器

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(RecordFlowViewModel.Step.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= vm.step.rawValue ? DT.Color.primary : DT.Color.textSecondary.opacity(0.25))
                    .frame(height: 4)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("第 \(vm.step.rawValue + 1) 步，共 4 步：\(vm.step.title)")
    }

    // MARK: ① 选择部位

    private var regionStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                BodyMap2DView(selectedRegionId: regionBinding)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            bottomBar(
                title: "下一步：描述症状",
                enabled: vm.canProceedFromRegion
            ) {
                vm.step = .symptom
            }
        }
    }

    private var regionBinding: Binding<String?> {
        Binding(
            get: { vm.region?.id },
            set: { id in
                vm.region = id.flatMap { StaticContent.region(id: $0) }
            }
        )
    }

    // MARK: ② 描述症状（语音 / 文字 / 模板 + 等级）

    private var symptomStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    if let region = vm.region {
                        HStack {
                            Text("当前部位")
                                .font(DT.Font.auxiliary)
                                .foregroundStyle(DT.Color.textSecondary)
                            Text(region.displayName)
                                .font(DT.Font.body.weight(.semibold))
                                .foregroundStyle(DT.Color.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        .accessibilityElement(children: .combine)
                    }

                    Picker("输入方式", selection: $vm.inputTab) {
                        ForEach(RecordFlowViewModel.InputTab.allCases) { tab in
                            Text(tab.displayName).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("症状描述方式：语音、文字或模板")

                    switch vm.inputTab {
                    case .voice: voiceTab
                    case .text: textTab
                    case .template: templateTab
                    }

                    // 等级选择（§4：1/2/3，色标 + 文字双载体，§10.3）
                    LevelSelector(level: $vm.level, touched: $vm.levelTouchedByUser)
                }
                .padding(16)
            }
            .onChange(of: vm.inputTab) { _ in
                speech.cancelTranscribing()
            }

            bottomBar(title: "下一步：生成沟通文案", enabled: true) {
                speech.stopTranscribing()
                if vm.inputTab == .voice, !speech.partialText.isEmpty,
                   vm.symptomText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    vm.symptomText = speech.partialText
                    vm.source = .voice
                }
                vm.proceedFromSymptom(parser: appState.parser)
            }
        }
    }

    // 语音 Tab（§3.2 分级策略：不支持 on-device 时完整降级到文字）
    @ViewBuilder
    private var voiceTab: some View {
        let language = store.settings.language
        VStack(spacing: 14) {
            if !speech.isOnDeviceAvailable(for: language) {
                // 降级提示（§3.2.3 / §9）
                VStack(spacing: 10) {
                    Image(systemName: "mic.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(DT.Color.textSecondary)
                        .accessibilityHidden(true)
                    Text(Compliance.speechUnavailableHint)
                        .font(DT.Font.body)
                        .foregroundStyle(DT.Color.textBody)
                        .multilineTextAlignment(.center)
                    Text("语音输入（支持设备上本地完成）")
                        .font(DT.Font.auxiliary)
                        .foregroundStyle(DT.Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(DT.Color.background)
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
                .cardShadow()
            } else {
                VStack(spacing: 12) {
                    // 录音按钮
                    Button {
                        toggleRecording(language: language)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: speech.isTranscribing ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(speech.isTranscribing ? DT.Color.levelSevere : DT.Color.primary)
                            Text(speech.isTranscribing ? "停止" : "开始说话")
                                .font(DT.Font.body.weight(.medium))
                                .foregroundStyle(DT.Color.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                    .accessibilityLabel(speech.isTranscribing ? "停止语音输入" : "开始语音输入")
                    .accessibilityHint("语音在设备本地完成识别，不联网")

                    // 实时转写
                    if speech.isTranscribing || !speech.partialText.isEmpty {
                        Text(speech.partialText.isEmpty ? "正在聆听…" : speech.partialText)
                            .font(DT.Font.body)
                            .foregroundStyle(speech.partialText.isEmpty ? DT.Color.textSecondary : DT.Color.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(DT.Color.layeredBackground)
                            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.tag))
                            .accessibilityLabel(speech.partialText.isEmpty ? "正在聆听" : "识别内容：\(speech.partialText)")
                    }

                    if let error = speech.lastError {
                        Text("语音输入未完成：\(error)。可直接重试，或改用文字描述。")
                            .font(DT.Font.auxiliary)
                            .foregroundStyle(DT.Color.levelModerate)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if vm.speechAuthDenied {
                        Text("未获得麦克风或语音识别权限。可在系统设置中开启，或直接使用文字描述。")
                            .font(DT.Font.auxiliary)
                            .foregroundStyle(DT.Color.levelModerate)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !speech.partialText.isEmpty, !speech.isTranscribing {
                        Button {
                            vm.symptomText = speech.partialText
                            vm.source = .voice
                        } label: {
                            Label("采用这段文字", systemImage: "checkmark.circle")
                                .font(DT.Font.body.weight(.medium))
                                .foregroundStyle(DT.Color.primary)
                        }
                        .accessibilityHint("将识别内容填入症状描述")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(DT.Color.background)
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
                .cardShadow()
            }

            // 语音 Tab 同样展示已采用的文字，便于校对修改
            if !vm.symptomText.isEmpty, vm.inputTab == .voice {
                VStack(alignment: .leading, spacing: 6) {
                    Text("症状描述（可修改）")
                        .font(DT.Font.auxiliary)
                        .foregroundStyle(DT.Color.textSecondary)
                    TextEditor(text: $vm.symptomText)
                        .font(DT.Font.body)
                        .frame(minHeight: 70)
                        .padding(8)
                        .background(DT.Color.layeredBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.tag))
                }
            }
        }
    }

    private func toggleRecording(language: AppLanguage) {
        if speech.isTranscribing {
            speech.stopTranscribing()
            return
        }
        vm.speechAuthDenied = false
        Task {
            let granted = await speech.requestAuthorization()
            if granted {
                speech.startTranscribing(language: language)
            } else {
                vm.speechAuthDenied = true
            }
        }
    }

    // 文字 Tab
    private var textTab: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("用文字描述不适感受（可留空）")
                .font(DT.Font.auxiliary)
                .foregroundStyle(DT.Color.textSecondary)
            TextEditor(text: $vm.symptomText)
                .font(DT.Font.body)
                .frame(minHeight: 120)
                .padding(8)
                .background(DT.Color.background)
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.tag))
                .overlay(
                    RoundedRectangle(cornerRadius: DT.Radius.tag)
                        .stroke(DT.Color.textSecondary.opacity(0.3), lineWidth: 1)
                )
                .accessibilityLabel("症状描述输入框")
                .onChange(of: vm.symptomText) { _ in
                    if vm.inputTab == .text { vm.source = .manual }
                }
        }
    }

    // 模板 Tab（内置 + 用户自定义，§6.5）
    private var templateTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !store.userTemplates.isEmpty {
                Text("我的模板")
                    .font(DT.Font.body.weight(.medium))
                    .foregroundStyle(DT.Color.textPrimary)
                ForEach(store.userTemplates) { template in
                    templateRow(name: template.name, content: template.content) {
                        vm.applyUserTemplate(template)
                    }
                }
            }

            Text("内置模板")
                .font(DT.Font.body.weight(.medium))
                .foregroundStyle(DT.Color.textPrimary)
            ForEach(StaticContent.builtinTemplates) { template in
                templateRow(name: template.name, content: template.content) {
                    vm.applyTemplate(template)
                }
            }
        }
    }

    private func templateRow(name: String, content: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(DT.Font.body.weight(.medium))
                    .foregroundStyle(DT.Color.textPrimary)
                Text(content)
                    .font(DT.Font.auxiliary)
                    .foregroundStyle(DT.Color.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(DT.Color.background)
            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.button))
            .cardShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("模板：\(name)")
        .accessibilityHint("双击套用此模板生成沟通文案")
    }

    // MARK: ③ 生成沟通文案（可编辑 + 固定轻提示，§8.2.2）

    private var messageStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    // 固定位置非医疗轻提示（不弹窗）
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(DT.Color.primary)
                            .accessibilityHidden(true)
                        Text(Compliance.generatedTextHint)
                            .font(DT.Font.auxiliary)
                            .foregroundStyle(DT.Color.textBody)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DT.Color.primaryLight.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: DT.Radius.tag))
                    .accessibilityElement(children: .combine)

                    if let region = vm.region {
                        HStack(spacing: 8) {
                            Text(region.displayName)
                                .font(DT.Font.auxiliary.weight(.medium))
                                .foregroundStyle(DT.Color.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(DT.Color.primaryLight)
                                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.tag))
                            Text(vm.level.displayName)
                                .font(DT.Font.auxiliary.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(DT.levelColor(vm.level))
                                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.tag))
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("部位 \(region.displayName)，等级 \(vm.level.displayName)")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("沟通文案（可直接编辑）")
                            .font(DT.Font.auxiliary)
                            .foregroundStyle(DT.Color.textSecondary)
                        TextEditor(text: $vm.message)
                            .font(DT.Font.body)
                            .frame(minHeight: 160)
                            .padding(10)
                            .background(DT.Color.background)
                            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
                            .cardShadow()
                            .accessibilityLabel("沟通文案，可编辑")
                    }
                }
                .padding(16)
            }

            bottomBar(title: "下一步：播报展示",
                      enabled: !vm.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                vm.step = .broadcast
            }
        }
    }

    // MARK: ④ 播报展示

    private var broadcastStep: some View {
        BroadcastView(
            text: vm.message,
            initialLanguage: store.settings.language,
            saved: saved,
            onSave: saveRecord
        )
    }

    private func saveRecord() {
        guard let region = vm.region else { return }
        let record = SoreRecordData(
            id: UUID(),
            createdAt: Date(),
            regionId: region.id,
            side: region.side,
            level: vm.level,
            symptomText: vm.symptomText,
            generatedText: vm.message,
            source: vm.source,
            templateId: vm.templateId
        )
        store.addRecord(record)
        if store.lastErrorMessage == nil {
            withAnimation { saved = true }
        }
    }

    // MARK: 底部主按钮

    private func bottomBar(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DT.Font.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(enabled ? DT.Color.primary : DT.Color.textSecondary.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.button))
        }
        .disabled(!enabled)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(DT.Color.background)
        .accessibilityLabel(title)
    }
}

// MARK: - 等级选择器（§4 / §10.3：色标 + 文字双载体）

struct LevelSelector: View {
    @Binding var level: SoreLevel
    @Binding var touched: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("不适程度")
                .font(DT.Font.body.weight(.medium))
                .foregroundStyle(DT.Color.textPrimary)
            HStack(spacing: 10) {
                ForEach(SoreLevel.allCases, id: \.rawValue) { item in
                    let selected = level == item
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            level = item
                            touched = true
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("Lv.\(item.rawValue)")
                                .font(DT.Font.auxiliary.weight(.bold))
                            Text(item.displayName)
                                .font(DT.Font.auxiliary)
                        }
                        .foregroundStyle(selected ? .white : DT.Color.textBody)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selected ? DT.levelColor(item) : DT.Color.background)
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.button))
                        .overlay(
                            RoundedRectangle(cornerRadius: DT.Radius.button)
                                .stroke(DT.levelColor(item), lineWidth: selected ? 0 : 1)
                        )
                        .scaleEffect(selected ? 1.03 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("等级 \(item.rawValue)，\(item.displayName)")
                    .accessibilityHint(selected ? "当前已选中" : "双击选择该等级")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}
