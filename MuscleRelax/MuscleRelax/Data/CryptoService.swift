import Foundation
import CryptoKit

/// AES-256-GCM 字段级加密（需求 §3.1）
///
/// 密文采用 `AES.GCM.SealedBox.combined` 格式（nonce ‖ ciphertext ‖ tag），
/// 密钥为 256 位 `SymmetricKey`，由 `KeychainService` 生成并托管。
struct CryptoService: Sendable {

    private let key: SymmetricKey

    /// 从 Keychain 加载（或首次生成）密钥。
    /// - Throws: `CryptoError.keyRebuilt`（已重建新密钥，旧密文不可解密）、
    ///   `CryptoError.keychainWriteFailed`
    init(keychain: KeychainService = KeychainService()) throws {
        self.key = try keychain.loadOrCreateKey()
    }

    /// 供测试注入固定密钥
    init(key: SymmetricKey) {
        self.key = key
    }

    /// 明文 → AES-256-GCM 密文（combined 格式）
    func encrypt(_ plaintext: String) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(Data(plaintext.utf8), using: key)
            guard let combined = sealedBox.combined else {
                throw CryptoError.encryptionFailed
            }
            return combined
        } catch let error as CryptoError {
            throw error
        } catch {
            throw CryptoError.encryptionFailed
        }
    }

    /// AES-256-GCM 密文（combined 格式）→ 明文
    func decrypt(_ data: Data) throws -> String {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let plaintextData = try AES.GCM.open(sealedBox, using: key)
            guard let plaintext = String(data: plaintextData, encoding: .utf8) else {
                throw CryptoError.decryptionFailed
            }
            return plaintext
        } catch let error as CryptoError {
            throw error
        } catch {
            throw CryptoError.decryptionFailed
        }
    }

    /// 备份导出用：加密后转 Base64 字符串
    func encryptToBase64String(_ plaintext: String) throws -> String {
        try encrypt(plaintext).base64EncodedString()
    }

    /// 备份导入用：Base64 解码后解密
    func decryptFromBase64String(_ base64: String) throws -> String {
        guard let data = Data(base64Encoded: base64) else {
            throw CryptoError.decryptionFailed
        }
        return try decrypt(data)
    }
}
