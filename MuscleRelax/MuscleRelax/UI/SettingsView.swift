import SwiftUI
import SafariServices
import UniformTypeIdentifiers
import UIKit

// MARK: - 设置页（需求 §7.3.4 / §5 / §8）
//
// 极简列表：语言切换 / 数据导出 / 数据导入 / 备份提醒开关 / 大字模式 /
// 隐私政策（SFSafariViewController）/ 免责声明（只读）/ 版本信息。
// 导出导入经 UIDocumentPickerViewController，由用户显式选择位置（§5.1.2）。

struct SettingsView: View {
    @EnvironmentObject private var store: CoreDataStore
    @EnvironmentObject private var reminder: BackupReminderService
    @Environment(\.dismiss) private var dismiss

    @State private var exportFileURL: URL?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showSafari = false
    @State private var showDisclaimer = false

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: 通用
                Section("通用") {
                    // 语言切换
                    HStack {
                        Label("播报语言", systemImage: "globe")
                        Spacer()
                        Picker("播报语言", selection: languageBinding) {
                            ForEach(AppLanguage.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .accessibilityLabel("播报语言，当前：\(store.settings.language.displayName)")
                    }

                    // 大字模式（§10.2）
                    Toggle(isOn: largeTextBinding) {
                        Label("大字模式", systemImage: "textformat.size.larger")
                    }
                    .accessibilityHint("开启后全局放大正文字体")
                }

                // MARK: 数据与备份
                Section("数据与备份") {
                    Button {
                        prepareExport()
                    } label: {
                        Label("导出数据备份", systemImage: "square.and.arrow.up")
                            .foregroundStyle(DT.Color.textPrimary)
                    }
                    .accessibilityHint("将全部记录与设置导出为备份文件，由你选择保存位置")

                    Button {
                        showImporter = true
                    } label: {
                        Label("导入数据备份", systemImage: "square.and.arrow.down")
                            .foregroundStyle(DT.Color.textPrimary)
                    }
                    .accessibilityHint("从备份文件恢复数据，冲突的记录会生成新副本")

                    Toggle(isOn: reminderBinding) {
                        Label("每周备份提醒", systemImage: "bell.badge")
                    }
                    .accessibilityHint("开启后每周通过本地通知提醒一次，通知不含任何健康数据")
                }

                // MARK: 关于
                Section("关于") {
                    Button {
                        showSafari = true
                    } label: {
                        Label("隐私政策", systemImage: "hand.raised")
                            .foregroundStyle(DT.Color.textPrimary)
                    }
                    .accessibilityHint("打开隐私政策页面，该页面不收集任何访问数据")

                    Button {
                        showDisclaimer = true
                    } label: {
                        Label("免责声明", systemImage: "doc.plaintext")
                            .foregroundStyle(DT.Color.textPrimary)
                    }
                    .accessibilityHint("查看已同意的免责声明（只读）")

                    HStack {
                        Label("版本", systemImage: "info.circle")
                        Spacer()
                        Text(Compliance.appVersion)
                            .foregroundStyle(DT.Color.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("版本 \(Compliance.appVersion)")
                }

                Section {
                    Text(Compliance.unifiedStatement)
                        .font(DT.Font.auxiliary)
                        .foregroundStyle(DT.Color.textSecondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            // 导出：先生成临时文件，再由 document picker 导出到用户选择的位置
            .sheet(isPresented: $showExporter, onDismiss: cleanupExportTempFile) {
                if let exportFileURL {
                    DocumentPicker(mode: .export(fileURL: exportFileURL)) { exportedURL in
                        if exportedURL != nil {
                            presentAlert(title: "导出完成", message: "备份文件已保存到你选择的位置。请妥善保管，该文件包含你的全部记录。")
                        }
                        showExporter = false
                    }
                }
            }
            // 导入：选择备份文件 → store.importBackup（§9 错误明确提示）
            .sheet(isPresented: $showImporter) {
                DocumentPicker(mode: .importBackup) { url in
                    showImporter = false
                    if let url { performImport(from: url) }
                }
            }
            .sheet(isPresented: $showSafari) {
                SafariView(url: Compliance.privacyPolicyURL)
            }
            .sheet(isPresented: $showDisclaimer) {
                DisclaimerReadOnlySheet()
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: 绑定

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { store.settings.language },
            set: { lang in
                var settings = store.settings
                settings.language = lang
                store.updateSettings(settings)
            }
        )
    }

    private var largeTextBinding: Binding<Bool> {
        Binding(
            get: { store.settings.largeTextMode },
            set: { enabled in
                var settings = store.settings
                settings.largeTextMode = enabled
                store.updateSettings(settings)
            }
        )
    }

    /// 备份提醒：开启时先申请本地通知授权（§8.4），授权失败则回退开关并提示
    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { store.settings.backupReminderEnabled },
            set: { enabled in
                if enabled {
                    Task {
                        let granted = await reminder.requestAuthorizationIfNeeded()
                        if granted {
                            reminder.scheduleWeeklyReminder()
                            persistReminder(true)
                        } else {
                            persistReminder(false)
                            presentAlert(title: "无法开启提醒",
                                         message: "未获得通知权限。可在系统「设置」中为本应用开启通知后再试。")
                        }
                    }
                } else {
                    reminder.cancelReminder()
                    persistReminder(false)
                }
            }
        )
    }

    private func persistReminder(_ enabled: Bool) {
        var settings = store.settings
        settings.backupReminderEnabled = enabled
        store.updateSettings(settings)
    }

    // MARK: 导出 / 导入

    private func prepareExport() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let filename = "muscle-relax-backup-\(formatter.string(from: Date())).mrbak"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try store.exportBackup(to: tempURL)
            exportFileURL = tempURL
            showExporter = true
        } catch {
            // §9：导出失败明确提示（如加密模块不可用 / 写入失败）
            presentAlert(title: "导出失败", message: error.localizedDescription)
        }
    }

    private func cleanupExportTempFile() {
        if let url = exportFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        exportFileURL = nil
    }

    private func performImport(from url: URL) {
        do {
            let summary = try store.importBackup(from: url)
            var parts = ["成功导入 \(summary.importedRecords) 条记录、\(summary.importedTemplates) 个模板。"]
            if summary.reassignedIDs > 0 {
                // §9：ID 冲突生成新副本，不覆盖现有数据
                parts.append("其中 \(summary.reassignedIDs) 条与现有数据重复，已作为新副本保留，未覆盖任何现有内容。")
            }
            presentAlert(title: "导入完成", message: parts.joined())
        } catch {
            // §9：文件损坏 / 版本过高 → 明确报错，未写入任何数据，可重新选择
            presentAlert(title: "导入失败", message: error.localizedDescription)
        }
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - 免责声明只读展示（设置页入口）

private struct DisclaimerReadOnlySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(Compliance.disclaimerText)
                    .font(DT.Font.body)
                    .foregroundStyle(DT.Color.textBody)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .navigationTitle("免责声明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Text("已同意版本：v\(Compliance.disclaimerVersion)")
                        .font(DT.Font.auxiliary)
                        .foregroundStyle(DT.Color.textSecondary)
                }
            }
        }
    }
}

// MARK: - UIDocumentPicker 桥接（§5.1.2：用户显式选择位置）

private struct DocumentPicker: UIViewControllerRepresentable {

    enum Mode {
        /// 导出模式：把已生成的临时备份文件复制到用户选择的位置
        case export(fileURL: URL)
        /// 导入模式：打开备份文件（asCopy，无需长期访问权限）
        case importBackup
    }

    let mode: Mode
    let onComplete: (URL?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController
        switch mode {
        case .export(let fileURL):
            picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        case .importBackup:
            let types: [UTType] = [.data, .json, .archive]
            picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        }
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onComplete: (URL?) -> Void

        init(onComplete: @escaping (URL?) -> Void) {
            self.onComplete = onComplete
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onComplete(urls.first)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onComplete(nil)
        }
    }
}

// MARK: - SFSafariViewController 桥接（§8.3 隐私政策静态页）

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
