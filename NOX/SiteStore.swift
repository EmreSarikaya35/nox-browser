import Foundation

struct Site: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var url: URL
    var date = Date()
}

/// Geçmiş ve yer imleri için ortak, JSON dosyasına yazan basit depo.
@MainActor
final class SiteStore: ObservableObject {
    @Published private(set) var items: [Site] = []
    private let file: URL
    private let limit: Int

    init(name: String, limit: Int) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("NOX")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        file = dir.appendingPathComponent(name + ".json")
        self.limit = limit
        items = (try? JSONDecoder().decode([Site].self, from: Data(contentsOf: file))) ?? []
    }

    func add(title: String, url: URL) {
        items.removeAll { $0.url == url }
        items.insert(Site(title: title.isEmpty ? (url.host ?? url.absoluteString) : title, url: url), at: 0)
        if items.count > limit { items.removeLast(items.count - limit) }
        save()
    }

    func remove(_ url: URL) { items.removeAll { $0.url == url }; save() }
    func clear() { items = []; save() }
    func contains(_ url: URL?) -> Bool { items.contains { $0.url == url } }

    func matching(_ query: String) -> [Site] {
        items.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.url.absoluteString.localizedCaseInsensitiveContains(query) }
    }

    // shortcut: her değişiklikte tüm dosya yeniden yazılır (en çok `limit` kayıt); geçmiş büyürse SQLite'a geç.
    private func save() { try? JSONEncoder().encode(items).write(to: file, options: .atomic) }
}
