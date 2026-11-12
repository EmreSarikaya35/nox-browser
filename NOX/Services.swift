import AppKit
import IOKit.ps

/// Bütün pencerelerin paylaştığı servisler (her pencerenin kendi TabManager'ı vardır).
@MainActor
enum Services {
    static let history = SiteStore(name: "history", limit: 2000)
    static let bookmarks = SiteStore(name: "bookmarks", limit: 5000)
    static let adBlock = AdBlockEngine()
    static let downloads = DownloadManager()
    static let privacy = PrivacyManager()
    static let passwords = PasswordManager()
    static let workspaces = WorkspaceList()
}

/// Çalışma alanlarının adları; bütün pencereler ve Ayarlar aynı listeyi kullanır. İlk alan ("Genel") silinemez.
@MainActor
final class WorkspaceList: ObservableObject {
    @Published private(set) var names: [String] {
        didSet { UserDefaults.standard.set(names, forKey: "workspaces") }
    }

    init() { names = UserDefaults.standard.stringArray(forKey: "workspaces") ?? [TabManager.defaultWorkspace] }

    /// Boş veya var olan ad eklenmez; eklenen adı döndürür.
    @discardableResult
    func add(_ name: String) -> String? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !names.contains(n) else { return nil }
        names.append(n)
        return n
    }

    func remove(_ name: String) {
        guard name != names.first else { return }
        names.removeAll { $0 == name }
    }
}

/// Varsayılan tarayıcı. Değişikliği macOS kendi onay penceresiyle kullanıcıya sorar.
@MainActor
enum DefaultBrowser {
    static var isDefault: Bool {
        NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!)?.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
    }

    static func makeDefault(completion: (() -> Void)? = nil) {
        // http için sorulan onay https'i de kapsar.
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "http") { _ in
            NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "https") { _ in
                DispatchQueue.main.async { completion?() }
            }
        }
    }
}

extension Notification.Name {
    static let noxRulesChanged = Notification.Name("noxRulesChanged")       // reklam kuralları değişti
    static let noxDownloadStarted = Notification.Name("noxDownloadStarted") // object: indirmeyi başlatan WKWebView
}

/// Sekme simgeleri. Bellekte ve (gizli sekmeler hariç) diskte alan adına göre önbelleklenir.
@MainActor
enum Favicons {
    private static let memory = NSCache<NSString, NSImage>()
    private static let session = URLSession(configuration: .ephemeral)
    private static let dir: URL = {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("NOX/favicons")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    private static func file(_ host: String) -> URL { dir.appendingPathComponent(host.replacingOccurrences(of: "/", with: "_")) }

    static func cached(_ host: String?) -> NSImage? {
        guard let host, !host.isEmpty else { return nil }
        if let img = memory.object(forKey: host as NSString) { return img }
        guard let img = NSImage(contentsOf: file(host)) else { return nil }
        memory.setObject(img, forKey: host as NSString)
        return img
    }

    /// Sayfanın bildirdiği simgeyi, yoksa /favicon.ico'yu indirir.
    static func load(page: URL?, declared: String?, persist: Bool) async -> NSImage? {
        guard let page, let host = page.host, page.scheme == "http" || page.scheme == "https" else { return nil }
        if let img = cached(host) { return img }
        let candidates = [declared.flatMap { URL(string: $0, relativeTo: page)?.absoluteURL }, URL(string: "/favicon.ico", relativeTo: page)?.absoluteURL]
        for case let url? in candidates where url.scheme == "http" || url.scheme == "https" {
            guard let (data, response) = try? await session.data(from: url), (response as? HTTPURLResponse)?.statusCode == 200,
                  data.count < 1_000_000, let img = NSImage(data: data), img.isValid, img.size.width > 0 else { continue }
            memory.setObject(img, forKey: host as NSString)
            if persist { try? data.write(to: file(host)) }
            return img
        }
        return nil
    }

    static func clear() {
        memory.removeAllObjects()
        for f in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] { try? FileManager.default.removeItem(at: f) }
    }
}

/// Güç kaynağını izler (olay tabanlı, yoklama yok). "Pildeyken otomatik pil tasarrufu" ayarı açıksa
/// şarjdan çıkınca pil tasarrufunu açar, şarja takılınca kapatır.
@MainActor
final class PowerMonitor {
    static let shared = PowerMonitor()
    private(set) var onBattery = false

    private init() {
        let source = IOPSNotificationCreateRunLoopSource({ _ in
            DispatchQueue.main.async { PowerMonitor.shared.update() }
        }, nil).takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        update()
    }

    func update() {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        onBattery = IOPSGetProvidingPowerSourceType(info).takeUnretainedValue() as String == kIOPMBatteryPowerKey
        if UserDefaults.standard.bool(forKey: "autoBatterySaver") { UserDefaults.standard.set(onBattery, forKey: "batterySaver") }
    }
}

/// GitHub Releases'teki son sürümü denetler; uygulama /Applications içindeyse yeni sürümü indirip yerine kurar.
/// Kurulan sürüm, uygulama yeniden başlatılınca devreye girer.
// shortcut: indirilen paket yalnızca "GitHub'daki depomuzdan, HTTPS ile geldi + paket kimliği bizim + sürüm daha yeni"
// diye doğrulanır; kriptografik imza denetimi yok. Developer ID alınınca imza doğrulaması eklenmeli.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()
    static let latestURL = URL(string: "https://api.github.com/repos/EmreSarikaya35/nox-browser/releases/latest")!
    @Published private(set) var available: (version: String, page: URL)? // yeni sürüm var ama kurulmadı
    @Published private(set) var installed: String?                       // kuruldu; yeniden başlatma bekliyor
    private var busy = false

    static var current: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let parse = { (s: String) in s.drop { $0 == "v" }.split(separator: ".").map { Int($0) ?? 0 } }
        let x = parse(a), y = parse(b)
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    private struct Release: Decodable {
        struct Asset: Decodable { let name: String; let browser_download_url: URL }
        let tag_name: String
        let html_url: URL
        let assets: [Asset]
    }

    /// Yeni sürüm varsa true, yoksa false, denetlenemediyse nil. Yeni sürüm mümkünse hemen kurulur.
    @discardableResult
    func check() async -> Bool? {
        guard !busy else { return available != nil || installed != nil }
        busy = true
        defer { busy = false }
        var request = URLRequest(url: Self.latestURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession(configuration: .ephemeral).data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200, let r = try? JSONDecoder().decode(Release.self, from: data) else { return nil }
        UserDefaults.standard.set(Date(), forKey: "updateChecked")
        let version = String(r.tag_name.drop { $0 == "v" })
        guard Self.isNewer(version, than: installed ?? Self.current) else { available = nil; return installed != nil }
        available = (version, r.html_url)
        if let dmg = r.assets.first(where: { $0.name.hasSuffix(".dmg") })?.browser_download_url {
            do {
                try await install(dmg: dmg, version: version)
                installed = version
                available = nil
            } catch { NSLog("NOX güncelleme kurulamadı: %@", String(describing: error)) } // "Güncelle" düğmesi elle indirme için kalır
        }
        return true
    }

    /// DMG'yi indirir, bağlar, içindeki NOX.app'i doğrular ve çalışan uygulamanın yerine koyar.
    private func install(dmg: URL, version: String) async throws {
        let app = Bundle.main.bundleURL
        // Yalnızca /Applications'a kurulmuş kopya kendini günceller (geliştirme derlemeleri ve taşınmış kopyalar değil).
        guard app.path.hasPrefix("/Applications/"), FileManager.default.isWritableFile(atPath: app.deletingLastPathComponent().path),
              dmg.scheme == "https", dmg.host == "github.com" else { throw URLError(.noPermissionsToReadFile) }
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("nox-update-" + UUID().uuidString)
        let mount = work.appendingPathComponent("mount")
        try fm.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        let (file, response) = try await URLSession(configuration: .ephemeral).download(from: dmg)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let image = work.appendingPathComponent("NOX.dmg")
        try fm.moveItem(at: file, to: image)

        try await Self.run("/usr/bin/hdiutil", ["attach", image.path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path])
        defer { Task.detached { try? await Self.run("/usr/bin/hdiutil", ["detach", mount.path, "-force"]) } }
        let source = mount.appendingPathComponent("NOX.app")
        guard let bundle = Bundle(url: source), bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              let found = bundle.infoDictionary?["CFBundleShortVersionString"] as? String, found == version,
              Self.isNewer(found, than: Self.current) else { throw URLError(.cannotParseResponse) }

        // Önce yanına kopyala, sonra tek adımda yer değiştir: yarım kalan kopya çalışan uygulamayı bozmaz.
        let staged = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: app, create: true).appendingPathComponent("NOX.app")
        try fm.copyItem(at: source, to: staged)
        _ = try fm.replaceItemAt(app, withItemAt: staged)
    }

    private nonisolated static func run(_ tool: String, _ args: [String]) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: tool)
            p.arguments = args
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            p.terminationHandler = { $0.terminationStatus == 0 ? c.resume() : c.resume(throwing: URLError(.cannotOpenFile)) }
            do { try p.run() } catch { c.resume(throwing: error) }
        }
    }

    /// Kurulan yeni sürümü başlatıp bu süreci kapatır.
    func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    /// Açılışta: ayar açıksa ve son denetimin üzerinden bir gün geçtiyse denetler.
    func checkIfDue() {
        let d = UserDefaults.standard
        guard d.object(forKey: "autoUpdateCheck") as? Bool ?? true else { return }
        if let last = d.object(forKey: "updateChecked") as? Date, Date().timeIntervalSince(last) < 86_400 { return }
        Task { await check() }
    }

    func checkManually() {
        Task {
            let result = await check()
            let alert = NSAlert()
            if let installed {
                alert.messageText = L("NOX \(installed) kuruldu")
                alert.informativeText = L("Yeni sürüm, uygulama yeniden başlatılınca devreye girer.")
                alert.addButton(withTitle: L("Yeniden Başlat"))
                alert.addButton(withTitle: L("Sonra"))
                if alert.runModal() == .alertFirstButtonReturn { relaunch() }
            } else if let available {
                alert.messageText = L("Yeni sürüm var: \(available.version)")
                alert.informativeText = L("Otomatik kurulamadı (uygulama Uygulamalar klasöründe olmalı). İndirme sayfasını açmak ister misiniz?")
                alert.addButton(withTitle: L("İndirme Sayfasını Aç"))
                alert.addButton(withTitle: L("Sonra"))
                if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(available.page) }
            } else {
                alert.messageText = result == nil ? L("Güncelleme denetlenemedi") : L("NOX güncel")
                alert.informativeText = result == nil ? L("GitHub'a ulaşılamadı. İnternet bağlantınızı denetleyin.") : L("Sürüm \(Self.current) en yeni sürüm.")
                alert.runModal()
            }
        }
    }
}
