import WebKit

@MainActor
final class TabManager: ObservableObject {
    @Published private(set) var tabs: [Tab] = []
    @Published private(set) var selectedID: UUID?
    @Published var focusAddress = 0 // artınca adres çubuğu odaklanır
    @Published var findVisible = false
    @Published var downloadsVisible = false

    let history = SiteStore(name: "history", limit: 2000)
    let bookmarks = SiteStore(name: "bookmarks", limit: 500)
    let adBlock = AdBlockEngine()
    let downloads = DownloadManager()
    let privacy = PrivacyManager()
    let passwords = PasswordManager()

    private var closed: [URL] = []
    private var privateStore: WKWebsiteDataStore? // tüm gizli sekmeler paylaşır; sonuncusu kapanınca silinir
    private let defaults = UserDefaults.standard

    var selected: Tab? { tabs.first { $0.id == selectedID } }

    init() {
        downloads.onStart = { [weak self] in self?.downloadsVisible = true }
        adBlock.onRulesChanged = { [weak self] in self?.tabs.forEach { $0.applyContentRules(host: $0.url?.host) } }
        if defaults.object(forKey: "restoreSession") as? Bool ?? true {
            for s in defaults.stringArray(forKey: "session") ?? [] {
                if let u = URL(string: s) { tabs.append(makeTab(url: u, isPrivate: false, loadNow: false)) }
            }
        }
        if tabs.isEmpty { newTab() } else { select(tabs[min(defaults.integer(forKey: "sessionIndex"), tabs.count - 1)].id) }
    }

    private func makeTab(url: URL?, isPrivate: Bool, loadNow: Bool = true) -> Tab {
        if isPrivate, privateStore == nil { privateStore = .nonPersistent() }
        let tab = Tab(url: url, isPrivate: isPrivate, dataStore: isPrivate ? privateStore! : .default(), adBlock: adBlock,
                      downloads: downloads, privacy: privacy, loadNow: loadNow)
        tab.onNewTab = { [weak self] in self?.newTab(url: $0, isPrivate: isPrivate) }
        tab.onVisit = { [weak self] title, url in
            self?.history.add(title: title, url: url)
            self?.saveSession()
        }
        return tab
    }

    func newTab(url: URL? = nil, isPrivate: Bool = false) {
        let tab = makeTab(url: url, isPrivate: isPrivate)
        let index = tabs.firstIndex { $0.id == selectedID }.map { $0 + 1 } ?? tabs.count
        tabs.insert(tab, at: index)
        select(tab.id)
        if url == nil { focusAddress += 1 }
    }

    func select(_ id: UUID) {
        let previous = selected
        selectedID = id
        findVisible = false
        if previous?.id != id { previous?.scheduleSleep(after: sleepDelay) }
        selected?.wake()
    }

    /// Arka plan sekmesinin uyutulmadan önce bekleyeceği süre (sn). Test için: `defaults write com.nox.browser sleepDelay -int 10`
    private var sleepDelay: Int {
        let custom = defaults.integer(forKey: "sleepDelay")
        return custom > 0 ? custom : (defaults.bool(forKey: "batterySaver") ? 5 * 60 : 30 * 60)
    }

    /// Pil tasarrufu ayarı değişince arka plan sekmelerinin sayaçlarını yeni süreyle yeniden başlatır.
    func rescheduleSleep() {
        for tab in tabs where tab.id != selectedID { tab.scheduleSleep(after: sleepDelay) }
    }

    func cycle(_ step: Int) {
        guard let i = tabs.firstIndex(where: { $0.id == selectedID }) else { return }
        select(tabs[(i + step + tabs.count) % tabs.count].id)
    }

    func close(_ id: UUID) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs.remove(at: i)
        if !tab.isPrivate, let u = tab.url { closed.append(u) }
        if !tabs.contains(where: \.isPrivate) { privateStore = nil }
        if tabs.isEmpty { newTab() } else if selectedID == id { select(tabs[min(i, tabs.count - 1)].id) }
        saveSession()
    }

    func reopenClosed() { if let u = closed.popLast() { newTab(url: u) } }

    func open(_ input: String) {
        guard let url = URLResolver.resolve(input, engine: .current) else { return }
        if let selected { selected.load(url) } else { newTab(url: url) }
    }

    func goHome() {
        if let url = URLResolver.resolve(defaults.string(forKey: "homepage") ?? "", engine: .current) { selected?.load(url) }
        else { selected?.reset() }
    }

    func toggleBookmark() {
        guard let tab = selected, let url = tab.url else { return }
        if bookmarks.contains(url) { bookmarks.remove(url) } else { bookmarks.add(title: tab.title, url: url) }
    }

    func saveSession() {
        if defaults.bool(forKey: "clearOnQuit") { defaults.removeObject(forKey: "session"); return }
        let normal = tabs.filter { !$0.isPrivate && $0.url != nil }
        defaults.set(normal.map { $0.url!.absoluteString }, forKey: "session")
        defaults.set(normal.firstIndex { $0.id == selectedID } ?? 0, forKey: "sessionIndex")
    }

    func clearBrowsingData(completion: (() -> Void)? = nil) {
        history.clear()
        closed = []
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { completion?() }
    }
}
