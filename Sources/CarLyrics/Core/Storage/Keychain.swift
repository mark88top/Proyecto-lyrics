import Foundation
import Security

/// Almacenamiento de tokens en el Keychain.
///
/// Los tokens de Spotify no van a `UserDefaults`: se guardan con
/// `kSecAttrAccessibleAfterFirstUnlock` para que CarPlay pueda reconectar
/// tras un reinicio del teléfono sin que el usuario lo desbloquee primero.
struct Keychain {
    let service: String

    init(service: String = (Bundle.main.bundleIdentifier ?? "com.carlyrics.app") + ".tokens") {
        self.service = service
    }

    func set(_ data: Data, for account: String) {
        var query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            Log.auth.error("Keychain add falló con status \(status)")
        }
    }

    func data(for account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    func remove(_ account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

extension Keychain {
    func encode<T: Encodable>(_ value: T, for account: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        set(data, for: account)
    }

    func decode<T: Decodable>(_ type: T.Type, for account: String) -> T? {
        guard let data = data(for: account) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
