import Foundation
import Security
import CryptoKit

/// 加密密钥的 Keychain 托管（需求 §3.1）
///
/// - 条目类型：`kSecClassGenericPassword`
/// - 可访问性：`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
///   （首次解锁后可用；不随 iCloud 钥匙串同步、不迁移到新设备）
/// - 密钥本体永不落盘到数据库或备份文件，仅存于 Keychain。
struct KeychainService: Sendable {

    let service: String
    let account: String

    init(service: String = "com.will.musclerelax.app",
         account: String = "encryption-key.v1") {
        self.service = service
        self.account = account
    }

    /// 读取密钥；不存在则生成新密钥（首次启动）。
    /// 读取失败或数据损坏（如换机恢复后旧密钥不可访问）时：
    /// 自动重建新密钥并写入，然后抛出 `CryptoError.keyRebuilt`，
    /// 由上层提示「加密记录需原设备重新导出」（需求 §9）。
    func loadOrCreateKey() throws -> SymmetricKey {
        switch readKeyData() {
        case .success(let data):
            guard data.count == 32 else {
                // 长度异常视为数据损坏 → 重建
                _ = try rebuildKey()
                throw CryptoError.keyRebuilt
            }
            return SymmetricKey(data: data)

        case .failure(let status) where status == errSecItemNotFound:
            // 首次启动：生成并写入
            let key = Self.generateKey()
            try writeKeyData(keyData(key))
            return key

        case .failure:
            // 其他读取失败：重建新密钥（旧密文将无法解密）
            _ = try rebuildKey()
            throw CryptoError.keyRebuilt
        }
    }

    // MARK: - Private

    private static func generateKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }

    private func rebuildKey() throws -> SymmetricKey {
        deleteKeyData()
        let key = Self.generateKey()
        try writeKeyData(keyData(key))
        return key
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    /// Keychain 读取结果（OSStatus 不遵循 Error，用专用类型承载）
    enum ReadResult {
        case success(Data)
        case failure(OSStatus)
    }

    private func readKeyData() -> ReadResult {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return .failure(status) }
        guard let data = item as? Data else { return .failure(errSecDecode) }
        return .success(data)
    }

    private func writeKeyData(_ data: Data) throws {
        var attributes = baseQuery()
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            // 已存在则更新（重建路径已先删除，此处仅作防御）
            let update: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, update as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw CryptoError.keychainWriteFailed(updateStatus)
            }
            return
        }
        guard status == errSecSuccess else {
            throw CryptoError.keychainWriteFailed(status)
        }
    }

    private func deleteKeyData() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}
