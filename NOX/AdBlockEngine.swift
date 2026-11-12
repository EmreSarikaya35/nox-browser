import WebKit

struct FilterList: Identifiable {
    let id: String
    let name: String
    let url: URL
}

/// Filtre listelerini indirir, WKContentRuleList olarak derler ve hangi sitede etkin olacağına karar verir.
/// Derlenmiş listeler WebKit'in diskteki deposunda kalır; uygulama açılışında yeniden derlenmez.
@MainActor
final class AdBlockEngine: ObservableObject {
    // Listeler çalışma anında kendi sunucularından indirilir, uygulamayla birlikte dağıtılmaz.
    static let lists = [
        FilterList(id: "easylist", name: "EasyList (reklamlar)", url: URL(string: "https://easylist.to/easylist/easylist.txt")!),
        FilterList(id: "easyprivacy", name: "EasyPrivacy (takipçiler)", url: URL(string: "https://easylist.to/easylist/easyprivacy.txt")!),
        FilterList(id: "ublock", name: "uBlock filters", url: URL(string: "https://ublockorigin.github.io/uAssets/filters/filters.txt")!),
        FilterList(id: "adguard-tr", name: "AdGuard Türkçe", url: URL(string: "https://filters.adtidy.org/extension/ublock/filters/13.txt")!),
    ]
    private static let customID = "custom"
    private static let updateInterval: TimeInterval = 4 * 24 * 3600

    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "adblockEnabled"); changed() } }
    @Published var customFilters: String
    @Published private(set) var whitelist: Set<String>
    @Published private(set) var enabledLists: Set<String>
    @Published private(set) var ruleCounts: [String: Int]
    @Published private(set) var lastUpdate: Date?
    @Published private(set) var totalBlocked: Int
    @Published private(set) var status = ""
    @Published private(set) var busy = false

    /// Etkin kural kümesi her değiştiğinde artar; sekmeler bununla kendi kurallarını tazeler.
    private(set) var revision = 0

    private var compiled: [String: WKContentRuleList] = [:]
    private let store = WKContentRuleListStore.default()!
    private let defaults = UserDefaults.standard

    init() {
        enabled = defaults.object(forKey: "adblockEnabled") as? Bool ?? true
        customFilters = defaults.string(forKey: "adblockCustom") ?? ""
        whitelist = Set(defaults.stringArray(forKey: "adblockWhitelist") ?? [])
        enabledLists = Set(defaults.stringArray(forKey: "adblockLists") ?? ["easylist", "easyprivacy"])
        ruleCounts = defaults.dictionary(forKey: "adblockCounts") as? [String: Int] ?? [:]
        lastUpdate = defaults.object(forKey: "adblockUpdated") as? Date
        totalBlocked = defaults.integer(forKey: "adblockTotal")
        Task { await start() }
    }

    private func start() async {
        for id in enabledLists.union([Self.customID]) {
            compiled[id] = try? await store.contentRuleList(forIdentifier: id)
        }
        changed()
        let stale = lastUpdate.map { Date().timeIntervalSince($0) > Self.updateInterval } ?? true
        await sync(force: stale)
    }

    // MARK: Sekmelerin kullandığı arayüz

    func isWhitelisted(_ host: String?) -> Bool { whitelist.contains(Self.normalize(host)) }
    func isActive(on host: String?) -> Bool { enabled && !isWhitelisted(host) }
    func activeLists(for host: String?) -> [WKContentRuleList] { isActive(on: host) ? Array(compiled.values) : [] }

    func noteBlocked() {
        totalBlocked += 1
        defaults.set(totalBlocked, forKey: "adblockTotal")
    }

    // MARK: Kullanıcı ayarları

    func toggleSite(_ host: String?) {
        let h = Self.normalize(host)
        guard !h.isEmpty else { return }
        if whitelist.contains(h) { whitelist.remove(h) } else { whitelist.insert(h) }
        defaults.set(whitelist.sorted(), forKey: "adblockWhitelist")
        changed()
    }

    func setList(_ id: String, on: Bool) {
        if on { enabledLists.insert(id) } else { enabledLists.remove(id) }
        defaults.set(enabledLists.sorted(), forKey: "adblockLists")
        Task { await sync(force: false) }
    }

    func update() async { await sync(force: true) }

    func applyCustomFilters() {
        defaults.set(customFilters, forKey: "adblockCustom")
        Task {
            do {
                if AdBlockConverter.rules(from: customFilters).isEmpty {
                    compiled[Self.customID] = nil
                    ruleCounts[Self.customID] = nil
                    changed()
                    try? await store.removeContentRuleList(forIdentifier: Self.customID)
                    status = customFilters.isEmpty ? "Özel filtreler kaldırıldı" : "Özel filtrelerde desteklenen kural yok"
                } else {
                    try await compile(Self.customID, customFilters)
                    changed()
                    status = "Özel filtreler uygulandı (\(ruleCounts[Self.customID] ?? 0) kural)"
                }
            } catch { status = "Özel filtreler derlenemedi: \(error.localizedDescription)" }
            defaults.set(ruleCounts, forKey: "adblockCounts")
        }
    }

    // MARK: İndirme ve derleme

    /// Kapatılan listeleri kaldırır, eksik olanları (force ise hepsini) indirip derler.
    private func sync(force: Bool) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        var errors: [String] = [], removed: [String] = [], downloaded = false
        for list in Self.lists {
            guard enabledLists.contains(list.id) else {
                if compiled.removeValue(forKey: list.id) != nil { removed.append(list.id); ruleCounts[list.id] = nil }
                continue
            }
            guard force || compiled[list.id] == nil else { continue }
            status = "\(list.name) indiriliyor…"
            do {
                let (data, response) = try await URLSession.shared.data(from: list.url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                status = "\(list.name) derleniyor…"
                try await compile(list.id, String(decoding: data, as: UTF8.self))
                downloaded = true
            } catch {
                // Eski derlenmiş liste (varsa) kullanılmaya devam eder.
                errors.append("\(list.name): \(error.localizedDescription)")
                NSLog("NOX AdBlock: %@ güncellenemedi: %@", list.id, String(describing: error))
            }
        }
        changed()
        for id in removed { try? await store.removeContentRuleList(forIdentifier: id) }
        if downloaded, errors.isEmpty {
            lastUpdate = Date()
            defaults.set(lastUpdate, forKey: "adblockUpdated")
        }
        defaults.set(ruleCounts, forKey: "adblockCounts")
        status = errors.isEmpty ? "" : errors.joined(separator: "\n")
    }

    private func compile(_ id: String, _ text: String) async throws {
        // Ayrıştırma ana iş parçacığını ve arayüzü meşgul etmesin.
        let rules = await Task.detached(priority: .utility) { AdBlockConverter.encode(text) }.value
        guard rules.count > 0 else { throw URLError(.cannotParseResponse) }
        guard let list = try await store.compileContentRuleList(forIdentifier: id, encodedContentRuleList: rules.json) else {
            throw URLError(.cannotParseResponse)
        }
        compiled[id] = list
        ruleCounts[id] = rules.count
    }

    private func changed() {
        revision += 1
        NotificationCenter.default.post(name: .noxRulesChanged, object: nil)
    }

    private static func normalize(_ host: String?) -> String {
        let h = (host ?? "").lowercased()
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }
}
