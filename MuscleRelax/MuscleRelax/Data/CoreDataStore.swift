import Foundation
import CoreData
import Combine

/// Core Data 用户数据仓库（需求 §3.1 / §4 / §5 / §9）
///
/// - 内存中以明文 DTO（`SoreRecordData` / `UserTemplateData` / `AppSettingsData`）交互；
///   落盘时 `symptomText` / `generatedText` / 模板 `name` / `content` 经 `CryptoService`
///   AES-256-GCM 加密为 Binary Data。
/// - 持久化文件启用 `FileProtectionType.complete`（锁屏后不可读）。
/// - 协议方法按契约不抛错：写入 / 加密 / 保存失败时记录在 `lastErrorMessage`。
/// - 导出 / 导入的用户体验方法挂在本类上（`exportBackup(to:)` / `importBackup(from:)`）。
@MainActor
final class CoreDataStore: SoreRecordStore {

    /// 密钥变更后无法解密的历史内容占位文案（需求 §9：提示需原设备重新导出）
    static let undecryptablePlaceholder = "【加密内容不可用：需在原设备重新导出后恢复】"

    // MARK: - 对外状态

    @Published private(set) var records: [SoreRecordData] = []
    @Published private(set) var userTemplates: [UserTemplateData] = []
    @Published private(set) var settings: AppSettingsData = AppSettingsData()

    /// 检测到加密密钥被重建（换机 / 恢复系统备份后），旧密文将无法解密
    @Published private(set) var encryptionKeyWasRebuilt: Bool = false

    /// 最近一次写入 / 保存失败的中文描述（协议方法不抛错，借此暴露给 UI 提示）
    @Published private(set) var lastErrorMessage: String?

    // MARK: - 内部

    private let container: NSPersistentContainer
    private let crypto: CryptoService
    private let backupService: BackupService

    private var context: NSManagedObjectContext { container.viewContext }

    private enum EntityName {
        static let record = "SoreRecord"
        static let template = "UserTemplate"
        static let setting = "AppSetting"
    }

    // MARK: - 初始化

    /// - Parameter inMemory: 为 true 时使用内存存储（供预览 / 测试）。
    /// - Throws: `StoreError.persistenceLoadFailed`、`CryptoError.keychainWriteFailed`
    init(inMemory: Bool = false) throws {
        // 加密密钥：Keychain 读取失败时 KeychainService 已自动重建新密钥并抛
        // `CryptoError.keyRebuilt`，此处捕获后重新加载新密钥继续工作，
        // 并置 `encryptionKeyWasRebuilt` 供 UI 提示「加密记录需原设备重新导出」（需求 §9）。
        var rebuilt = false
        let cryptoService: CryptoService
        do {
            cryptoService = try CryptoService()
        } catch CryptoError.keyRebuilt {
            rebuilt = true
            cryptoService = try CryptoService() // 重建后的密钥已写入 Keychain，可正常加载
        }
        self.crypto = cryptoService
        self.encryptionKeyWasRebuilt = rebuilt
        self.backupService = BackupService(crypto: cryptoService)

        let container = NSPersistentContainer(name: "MuscleRelax")
        if let description = container.persistentStoreDescriptions.first {
            // 文件级数据保护：设备锁定期间数据库文件不可读（需求 §3.1 纯本地隐私）。
            // 注意：必须用 setOption(_:forKey:) 设置 store option，
            // KVC setValue(_:forKey:) 会抛 NSUnknownKeyException 导致启动即崩溃。
            description.setOption(FileProtectionType.complete.rawValue as NSString,
                                  forKey: NSPersistentStoreFileProtectionKey)
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
        }
        self.container = container

        var loadError: NSError?
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                loadError = error
            }
        }
        if let loadError {
            throw StoreError.persistenceLoadFailed(loadError.localizedDescription)
        }

        context.automaticallyMergesChangesFromParent = true
        ensureSettingsRowExists()
        refresh()
    }

    // MARK: - SoreRecordStore：记录

    func addRecord(_ record: SoreRecordData) {
        do {
            let object = NSEntityDescription.insertNewObject(forEntityName: EntityName.record,
                                                             into: context)
            try applyRecord(record, to: object)
            try saveAndRefresh()
        } catch {
            context.rollback()
            lastErrorMessage = error.localizedDescription
        }
    }

    func updateRecord(_ record: SoreRecordData) {
        do {
            guard let object = try fetchRecordObject(id: record.id) else { return }
            try applyRecord(record, to: object)
            try saveAndRefresh()
        } catch {
            context.rollback()
            lastErrorMessage = error.localizedDescription
        }
    }

    func deleteRecord(id: UUID) {
        do {
            if let object = try fetchRecordObject(id: id) {
                context.delete(object)
                try saveAndRefresh()
            }
        } catch {
            context.rollback()
            lastErrorMessage = error.localizedDescription
        }
    }

    /// 清空全部记录（二次确认由 UI 负责，需求 §6.7）
    func deleteAllRecords() {
        do {
            let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.record)
            for object in try context.fetch(request) {
                context.delete(object)
            }
            try saveAndRefresh()
        } catch {
            context.rollback()
            lastErrorMessage = error.localizedDescription
        }
    }

    // MARK: - SoreRecordStore：模板

    func addTemplate(_ template: UserTemplateData) {
        do {
            let object = NSEntityDescription.insertNewObject(forEntityName: EntityName.template,
                                                             into: context)
            try applyTemplate(template, to: object)
            try saveAndRefresh()
        } catch {
            context.rollback()
            lastErrorMessage = error.localizedDescription
        }
    }

    func updateTemplate(_ template: UserTemplateData) {
        do {
            guard let object = try fetchTemplateObject(id: template.id) else { return }
            try applyTemplate(template, to: object)
            try saveAndRefresh()
        } catch {
            context.rollback()
            lastErrorMessage = error.localizedDescription
        }
    }

    func deleteTemplate(id: UUID) {
        do {
            if let object = try fetchTemplateObject(id: id) {
                context.delete(object)
                try saveAndRefresh()
            }
        } catch {
            context.rollback()
            lastErrorMessage = error.localizedDescription
        }
    }

    // MARK: - SoreRecordStore：设置

    func updateSettings(_ settings: AppSettingsData) {
        do {
            let object = try settingsObject()
            applySettings(settings, to: object)
            try saveAndRefresh()
        } catch {
            context.rollback()
            lastErrorMessage = error.localizedDescription
        }
    }

    // MARK: - 备份导出 / 导入（需求 §5）

    /// 导出全部用户数据（LZ4 压缩 JSON，敏感字段保持密文）到用户选择的 URL。
    func exportBackup(to url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        try backupService.exportBackup(records: records,
                                       templates: userTemplates,
                                       settings: settings,
                                       to: url)
    }

    /// 从用户选择的 URL 导入备份；导入完成后刷新内存数据并落盘。
    /// - Returns: 导入摘要（含 ID 冲突重映射条数）
    func importBackup(from url: URL) throws -> ImportSummary {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let (backup, summary) = try backupService.importBackup(
            from: url,
            existingRecordIDs: Set(records.map(\.id)),
            existingTemplateIDs: Set(userTemplates.map(\.id))
        )

        // backup 中敏感字段已被 BackupService 解密为明文；此处走正常写入路径重新加密落盘。
        for backupRecord in backup.records {
            let record = try Self.mapBackupRecord(backupRecord)
            let object = NSEntityDescription.insertNewObject(forEntityName: EntityName.record,
                                                             into: context)
            try applyRecord(record, to: object)
        }
        for backupTemplate in backup.templates {
            let template = try Self.mapBackupTemplate(backupTemplate)
            let object = NSEntityDescription.insertNewObject(forEntityName: EntityName.template,
                                                             into: context)
            try applyTemplate(template, to: object)
        }

        // 设置：以备份文件为准整体覆盖（语言字段宽容解析，未知值回退中文）
        let importedSettings = Self.mapBackupSettings(backup.settings)
        applySettings(importedSettings, to: try settingsObject())

        try saveAndRefresh()
        return summary
    }

    // MARK: - Core Data 读写映射

    private func applyRecord(_ record: SoreRecordData, to object: NSManagedObject) throws {
        object.setValue(record.id, forKey: "id")
        object.setValue(record.createdAt, forKey: "createdAt")
        object.setValue(record.regionId, forKey: "regionId")
        object.setValue(record.side.rawValue, forKey: "side")
        object.setValue(Int16(record.level.rawValue), forKey: "level")
        object.setValue(record.source.rawValue, forKey: "source")
        object.setValue(record.templateId, forKey: "templateId")
        object.setValue(try crypto.encrypt(record.symptomText), forKey: "symptomText")
        object.setValue(try crypto.encrypt(record.generatedText), forKey: "generatedText")
    }

    private func applyTemplate(_ template: UserTemplateData, to object: NSManagedObject) throws {
        object.setValue(template.id, forKey: "id")
        object.setValue(template.regionId, forKey: "regionId")
        object.setValue(template.updatedAt, forKey: "updatedAt")
        object.setValue(try crypto.encrypt(template.name), forKey: "name")
        object.setValue(try crypto.encrypt(template.content), forKey: "content")
    }

    private func applySettings(_ settings: AppSettingsData, to object: NSManagedObject) {
        object.setValue(settings.language.rawValue, forKey: "language")
        object.setValue(settings.backupReminderEnabled, forKey: "backupReminderEnabled")
        object.setValue(settings.disclaimerAcceptedVersion, forKey: "disclaimerAcceptedVersion")
        object.setValue(settings.onboardingCompleted, forKey: "onboardingCompleted")
        object.setValue(settings.largeTextMode, forKey: "largeTextMode")
    }

    private func decryptOrPlaceholder(_ data: Data?) -> String {
        guard let data, let plaintext = try? crypto.decrypt(data) else {
            return Self.undecryptablePlaceholder
        }
        return plaintext
    }

    private func mapRecordObject(_ object: NSManagedObject) -> SoreRecordData? {
        guard let id = object.value(forKey: "id") as? UUID,
              let createdAt = object.value(forKey: "createdAt") as? Date,
              let regionId = object.value(forKey: "regionId") as? String else {
            return nil
        }
        let sideRaw = object.value(forKey: "side") as? String ?? RegionSide.center.rawValue
        let levelRaw = (object.value(forKey: "level") as? NSNumber)?.intValue ?? SoreLevel.mild.rawValue
        let sourceRaw = object.value(forKey: "source") as? String ?? RecordSource.manual.rawValue
        return SoreRecordData(
            id: id,
            createdAt: createdAt,
            regionId: regionId,
            side: RegionSide(rawValue: sideRaw) ?? .center,
            level: SoreLevel(rawValue: levelRaw) ?? .mild,
            symptomText: decryptOrPlaceholder(object.value(forKey: "symptomText") as? Data),
            generatedText: decryptOrPlaceholder(object.value(forKey: "generatedText") as? Data),
            source: RecordSource(rawValue: sourceRaw) ?? .manual,
            templateId: object.value(forKey: "templateId") as? String
        )
    }

    private func mapTemplateObject(_ object: NSManagedObject) -> UserTemplateData? {
        guard let id = object.value(forKey: "id") as? UUID,
              let regionId = object.value(forKey: "regionId") as? String,
              let updatedAt = object.value(forKey: "updatedAt") as? Date else {
            return nil
        }
        return UserTemplateData(
            id: id,
            name: decryptOrPlaceholder(object.value(forKey: "name") as? Data),
            content: decryptOrPlaceholder(object.value(forKey: "content") as? Data),
            regionId: regionId,
            updatedAt: updatedAt
        )
    }

    // MARK: - 备份 DTO 映射

    private static func mapBackupRecord(_ backupRecord: BackupFile.Record) throws -> SoreRecordData {
        guard let side = RegionSide(rawValue: backupRecord.side),
              let level = SoreLevel(rawValue: backupRecord.level),
              let source = RecordSource(rawValue: backupRecord.source) else {
            throw BackupError.corruptedFile
        }
        return SoreRecordData(
            id: backupRecord.id,
            createdAt: backupRecord.createdAt,
            regionId: backupRecord.regionId,
            side: side,
            level: level,
            symptomText: backupRecord.symptomText,
            generatedText: backupRecord.generatedText,
            source: source,
            templateId: backupRecord.templateId
        )
    }

    private static func mapBackupTemplate(_ backupTemplate: BackupFile.Template) throws -> UserTemplateData {
        UserTemplateData(
            id: backupTemplate.id,
            name: backupTemplate.name,
            content: backupTemplate.content,
            regionId: backupTemplate.regionId,
            updatedAt: backupTemplate.updatedAt
        )
    }

    private static func mapBackupSettings(_ backupSettings: BackupFile.Settings) -> AppSettingsData {
        AppSettingsData(
            language: AppLanguage(rawValue: backupSettings.language) ?? .zh,
            backupReminderEnabled: backupSettings.backupReminderEnabled,
            disclaimerAcceptedVersion: backupSettings.disclaimerAcceptedVersion,
            onboardingCompleted: backupSettings.onboardingCompleted,
            largeTextMode: backupSettings.largeTextMode
        )
    }

    // MARK: - 查询与刷新

    private func fetchRecordObject(id: UUID) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.record)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchTemplateObject(id: UUID) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.template)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// 单例设置行；不存在则创建默认值（需求 §4 AppSettings）
    private func settingsObject() throws -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.setting)
        request.fetchLimit = 1
        if let existing = try context.fetch(request).first {
            return existing
        }
        let object = NSEntityDescription.insertNewObject(forEntityName: EntityName.setting,
                                                         into: context)
        applySettings(AppSettingsData(), to: object)
        return object
    }

    private func ensureSettingsRowExists() {
        do {
            _ = try settingsObject()
            if context.hasChanges {
                try context.save()
            }
        } catch {
            context.rollback()
            lastErrorMessage = error.localizedDescription
        }
    }

    private func saveAndRefresh() throws {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                throw StoreError.saveFailed(error.localizedDescription)
            }
        }
        refresh()
    }

    private func refresh() {
        records = fetchAllRecords()
        userTemplates = fetchAllTemplates()
        settings = fetchCurrentSettings()
    }

    private func fetchAllRecords() -> [SoreRecordData] {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.record)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let objects = (try? context.fetch(request)) ?? []
        return objects.compactMap(mapRecordObject)
    }

    private func fetchAllTemplates() -> [UserTemplateData] {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.template)
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        let objects = (try? context.fetch(request)) ?? []
        return objects.compactMap(mapTemplateObject)
    }

    private func fetchCurrentSettings() -> AppSettingsData {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.setting)
        request.fetchLimit = 1
        guard let object = (try? context.fetch(request))?.first else {
            return AppSettingsData()
        }
        let languageRaw = object.value(forKey: "language") as? String ?? AppLanguage.zh.rawValue
        return AppSettingsData(
            language: AppLanguage(rawValue: languageRaw) ?? .zh,
            backupReminderEnabled: object.value(forKey: "backupReminderEnabled") as? Bool ?? false,
            disclaimerAcceptedVersion: object.value(forKey: "disclaimerAcceptedVersion") as? String ?? "",
            onboardingCompleted: object.value(forKey: "onboardingCompleted") as? Bool ?? false,
            largeTextMode: object.value(forKey: "largeTextMode") as? Bool ?? false
        )
    }
}
