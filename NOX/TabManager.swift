import Combine
import WebKit

/// Bir pencerenin sekmeleri. Geçmiş, yer imleri, reklam engelleyici vb. `Services` üzerinden pencereler arasında paylaşılır.
@MainActor
final class TabManager: ObservableObject {
    static let defaultWorkspace = "Genel" // kayıtlarda kullanılan sabit ad; ekranda `displayName` ile çevrilir
    static func displayName(_ workspace: String) -> String { workspace == defaultWorkspace ? L("Genel") : workspace }
    /// Oturumu geri yükleyen ve kaydeden pencere (ilk açılan; kapanırsa sonraki açılan devralır).
    private static weak var primary: TabManager?

    @Published private(set) var tabs: [Tab] = []          // bütün çalışma alanlarının sekmeleri; sabitlenenler başta
    @Published private(set) var selectedID: UUID?
    @Published private(set) var splitID: UUID?            // bölünmüş görünümde sağdaki sekme
    @Published private(set) var workspace = TabManager.defaultWorkspace
    @Published var focusAddress = 0 // artınca adres çubuğu odaklanır
    @Published var findVisible = false
    @Published var downloadsVisible = false
    @Published var paletteVisible = false

    let history = Services.history
    let bookmarks = Services.bookmarks
    let adBlock = Services.adBlock
    let downloads = Services.downloads
    let privacy = Services.privacy
    let passwords = Services.passwords

    private var closed: [URL] = []
    private var lastSelected: [String: UUID] = [:] // çalışma alanı → son seçili sekme
    private var privateStore: WKWebsiteDataStore? // tüm gizli sekmeler paylaşır; sonuncusu kapanınca silinir
    private var subs = Set<AnyCancellable>()
    private let defaults = UserDefaults.standard

    private struct SessionTab: Codable { var url: String; var pinned: Bool; var ws: String }

    var selected: Tab? { tabs.first { $0.id == selectedID } }
    var splitTab: Tab? { tabs.first { $0.id == splitID } }
    var visibleTabs: [Tab] { tabs.filter { $0.workspace == workspace } }
    var workspaces: [String] { Services.workspaces.names }

    init() {
        // Alan listesi Ayarlar'dan veya başka pencereden değişince: silinen alanların sekmelerini kapat, görünümü yenile.
        Services.workspaces.$names.dropFirst().sink { [weak self] in self?.workspacesChanged($0) }.store(in: &subs)
        NotificationCenter.default.publisher(for: .noxRulesChanged)
            .sink { [weak self] _ in self?.tabs.forEach { $0.applyContentRules(host: $0.url?.host) } }.store(in: &subs)
        NotificationCenter.default.publisher(for: .noxDownloadStarted)
            .sink { [weak self] n in if self?.tabs.contains(where: { $0.webView === n.object as AnyObject? }) == true { self?.downloadsVisible = true } }
            .store(in: &subs)

        if Self.primary == nil {
            Self.primary = self
            if defaults.object(forKey: "restoreSession") as? Bool ?? true { restoreSession() }
        }
        if let first = visibleTabs.first, selectedID == nil { select(first.id) }
        if visibleTabs.isEmpty { newTab() }
    }

    private func restoreSession() {
        var saved = defaults.data(forKey: "session2").flatMap { try? JSONDecoder().decode([SessionTab].self, from: $0) } ?? []
        if saved.isEmpty { // eski biçim (0.6 ve öncesi)
            saved = (defaults.stringArray(forKey: "session") ?? []).map { SessionTab(url: $0, pinned: false, ws: Self.defaultWorkspace) }
        }
        for s in saved {
            guard let u = URL(string: s.url) else { continue }
            let tab = makeTab(url: u, isPrivate: false, loadNow: false)
            tab.isPinned = s.pinned
            tab.workspace = workspaces.contains(s.ws) ? s.ws : Self.defaultWorkspace
            tabs.append(tab)
        }
        guard !tabs.isEmpty else { return }
        let tab = tabs[min(defaults.integer(forKey: "sessionIndex"), tabs.count - 1)]
        workspace = tab.workspace
        select(tab.id)
    }

    private func makeTab(url: URL?, isPrivate: Bool, loadNow: Bool = true) -> Tab {
        if isPrivate, privateStore == nil { privateStore = .nonPersistent() }
        let tab = Tab(url: url, isPrivate: isPrivate, dataStore: isPrivate ? privateStore! : .default(), adBlock: adBlock,
                      downloads: downloads, privacy: privacy, loadNow: loadNow)
        tab.workspace = workspace
        tab.onNewTab = { [weak self] in self?.newTab(url: $0, isPrivate: isPrivate) }
        tab.onVisit = { [weak self] title, url in
            self?.history.add(title: title, url: url)
            self?.saveSession()
        }
        return tab
    }

    /// Sabitlenmiş sekmeler her zaman başta durur (kendi aralarındaki sıra korunur).
    private func arrange() { tabs = tabs.filter(\.isPinned) + tabs.filter { !$0.isPinned } }

    // MARK: Sekmeler

    func newTab(url: URL? = nil, isPrivate: Bool = false, select selectIt: Bool = true) {
        let tab = makeTab(url: url, isPrivate: isPrivate)
        tabs.insert(tab, at: tabs.firstIndex { $0.id == selectedID }.map { $0 + 1 } ?? tabs.count)
        arrange()
        if selectIt { select(tab.id); if url == nil { focusAddress += 1 } }
    }

    func select(_ id: UUID) {
        let previous = selected
        if id == splitID { splitID = nil }
        selectedID = id
        lastSelected[workspace] = id
        findVisible = false
        if previous?.id != id, previous?.id != splitID { previous?.scheduleSleep(after: sleepDelay) }
        selected?.wake()
    }

    /// Arka plan sekmesinin uyutulmadan önce bekleyeceği süre (sn). Test için: `defaults write com.nox.browser sleepDelay -int 10`
    private var sleepDelay: Int {
        let custom = defaults.integer(forKey: "sleepDelay")
        return custom > 0 ? custom : (defaults.bool(forKey: "batterySaver") ? 5 * 60 : 30 * 60)
    }

    /// Pil tasarrufu ayarı değişince arka plan sekmelerinin sayaçlarını yeni süreyle yeniden başlatır.
    func rescheduleSleep() {
        for tab in tabs where tab.id != selectedID && tab.id != splitID { tab.scheduleSleep(after: sleepDelay) }
    }

    func cycle(_ step: Int) {
        let v = visibleTabs
        guard let i = v.firstIndex(where: { $0.id == selectedID }) else { return }
        select(v[(i + step + v.count) % v.count].id)
    }

    func close(_ id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        let i = visibleTabs.firstIndex { $0.id == id } ?? 0
        tabs.removeAll { $0.id == id }
        if splitID == id { splitID = nil }
        if !tab.isPrivate, let u = tab.url { closed.append(u) }
        if !tabs.contains(where: \.isPrivate) { privateStore = nil }
        let v = visibleTabs
        if v.isEmpty { newTab() } else if selectedID == id { select(v[min(i, v.count - 1)].id) }
        saveSession()
    }

    func reopenClosed() { if let u = closed.popLast() { newTab(url: u) } }

    /// Sürükle-bırak: `id` sekmesini `target` sekmesinin önüne taşır.
    func move(_ id: UUID, before target: UUID) {
        guard id != target, let from = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs.remove(at: from)
        tabs.insert(tab, at: tabs.firstIndex { $0.id == target } ?? tabs.count)
        arrange()
        saveSession()
    }

    func togglePin(_ id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        tab.isPinned.toggle()
        arrange()
        saveSession()
    }

    // MARK: Bölünmüş görünüm

    /// Açıksa kapatır; kapalıysa `id` sekmesini (verilmezse sıradaki sekmeyi, o da yoksa yeni bir sekmeyi) sağda açar.
    func toggleSplit(with id: UUID? = nil) {
        if let old = splitTab, id == nil || id == old.id {
            splitID = nil
            old.scheduleSleep(after: sleepDelay)
            return
        }
        var target = id
        if target == nil {
            let v = visibleTabs
            if v.count < 2 { newTab(select: false) }
            let all = visibleTabs
            let i = all.firstIndex { $0.id == selectedID } ?? 0
            target = all[(i + 1) % all.count].id
        }
        guard let target, target != selectedID, let tab = tabs.first(where: { $0.id == target }) else { return }
        splitTab?.scheduleSleep(after: sleepDelay)
        splitID = target
        tab.wake()
    }

    /// Sol ve sağ bölmeyi değiştirir; adres çubuğu ve araçlar her zaman soldaki sekmeye aittir.
    func swapSplit() {
        guard let s = splitID, let old = selectedID else { return }
        selectedID = s
        splitID = old
        lastSelected[workspace] = s
        findVisible = false
    }

    // MARK: Çalışma alanları

    func setWorkspace(_ name: String) {
        guard workspaces.contains(name), name != workspace else { return }
        let previous = selected, oldSplit = splitTab
        splitID = nil
        workspace = name
        oldSplit?.scheduleSleep(after: sleepDelay)
        let v = visibleTabs
        if v.isEmpty { previous?.scheduleSleep(after: sleepDelay); newTab() }
        else { select(v.first { $0.id == lastSelected[name] }?.id ?? v[0].id) }
    }

    func addWorkspace(_ name: String) {
        if let n = Services.workspaces.add(name) { setWorkspace(n) }
    }

    /// `names`: listenin yeni hali. Silinen alanların sekmeleri kapanır; bu pencere silinen alandaysa ilk alana döner.
    private func workspacesChanged(_ names: [String]) {
        objectWillChange.send()
        let orphans = tabs.filter { !names.contains($0.workspace) }
        guard !orphans.isEmpty || !names.contains(workspace) else { return }
        closed += orphans.filter { !$0.isPrivate }.compactMap(\.url)
        tabs.removeAll { !names.contains($0.workspace) }
        if splitTab == nil { splitID = nil }
        if !tabs.contains(where: \.isPrivate) { privateStore = nil }
        if !names.contains(workspace) {
            workspace = names[0]
            let v = visibleTabs
            if v.isEmpty { newTab() } else { select(v.first { $0.id == lastSelected[workspace] }?.id ?? v[0].id) }
        }
        saveSession()
    }

    func moveTab(_ id: UUID, to name: String) {
        guard let tab = tabs.first(where: { $0.id == id }), tab.workspace != name, workspaces.contains(name) else { return }
        let i = visibleTabs.firstIndex { $0.id == id } ?? 0
        tab.workspace = name
        tab.isPinned = false
        if splitID == id { splitID = nil }
        arrange()
        let v = visibleTabs
        if v.isEmpty { newTab() } else if selectedID == id { select(v[min(i, v.count - 1)].id) }
        tab.scheduleSleep(after: sleepDelay)
        saveSession()
    }

    // MARK: Gezinme

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

    // shortcut: yalnızca birincil pencerenin oturumu kaydedilir; diğer pencerelerin sekmeleri yeniden açılışta geri gelmez.
    func saveSession() {
        guard Self.primary === self else { return }
        defaults.removeObject(forKey: "session")
        if defaults.bool(forKey: "clearOnQuit") { defaults.removeObject(forKey: "session2"); return }
        let normal = tabs.filter { !$0.isPrivate && $0.url != nil }
        let saved = normal.map { SessionTab(url: $0.url!.absoluteString, pinned: $0.isPinned, ws: $0.workspace) }
        defaults.set(try? JSONEncoder().encode(saved), forKey: "session2")
        defaults.set(normal.firstIndex { $0.id == selectedID } ?? 0, forKey: "sessionIndex")
    }

    /// Geçmişi, sekme simgesi önbelleğini, çerezleri ve site verilerini siler (bütün pencereler için ortak).
    static func clearBrowsingData(completion: (() -> Void)? = nil) {
        Services.history.clear()
        Favicons.clear()
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { completion?() }
    }
}
