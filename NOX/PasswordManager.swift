import Foundation
import Security

struct Credential: Identifiable, Hashable {
    let host: String
    let username: String
    var id: String { host + "\n" + username }
}

/// Parolalar yalnızca macOS Anahtar Zinciri'nde (login keychain) saklanır; uygulama dosyalarına veya
/// UserDefaults'a hiçbir parola yazılmaz. Kayıtlar Anahtar Zinciri Erişimi'nde "NOX Browser parolası" adıyla görünür.
// shortcut: uygulama ad-hoc imzalı olduğu için her yeni derlemeden sonra macOS, kayıtlı parolayı okurken
// oturum parolasını bir kez sorar; Developer ID imzasıyla bu kaybolur.
@MainActor
final class PasswordManager: ObservableObject {
    @Published private(set) var credentials: [Credential] = []
    private static let label = "NOX Browser parolası"
    private static let servicePrefix = "nox:"

    init() { reload() }

    private func query(_ c: Credential) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: Self.servicePrefix + c.host,
         kSecAttrAccount as String: c.username]
    }

    func reload() {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrLabel as String: Self.label,
                                kSecMatchLimit as String: kSecMatchLimitAll, kSecReturnAttributes as String: true]
        var out: CFTypeRef?
        let rows = SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? (out as? [[String: Any]] ?? []) : []
        credentials = rows.compactMap { row in
            guard let service = row[kSecAttrService as String] as? String, service.hasPrefix(Self.servicePrefix),
                  let account = row[kSecAttrAccount as String] as? String else { return nil }
            return Credential(host: String(service.dropFirst(Self.servicePrefix.count)), username: account)
        }
        .sorted { ($0.host, $0.username) < ($1.host, $1.username) }
    }

    /// Yalnızca tam eşleşen alan adı; alt alan adları veya benzer adlar eşleşmez.
    func credentials(for host: String?) -> [Credential] { credentials.filter { $0.host == host } }

    func password(for c: Credential) -> String? {
        var q = query(c)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func save(host: String, username: String, password: String) -> Bool {
        var q = query(Credential(host: host, username: username))
        SecItemDelete(q as CFDictionary) // aynı kullanıcı için eski kaydı değiştir
        q[kSecAttrLabel as String] = Self.label
        q[kSecValueData as String] = Data(password.utf8)
        let ok = SecItemAdd(q as CFDictionary, nil) == errSecSuccess
        reload()
        return ok
    }

    func delete(_ c: Credential) {
        SecItemDelete(query(c) as CFDictionary)
        reload()
    }
}
