import AppKit

/// Site bazında kamera/mikrofon izinleri. Karar verilmemiş sitelerde kullanıcıya sorulur.
@MainActor
final class PrivacyManager: ObservableObject {
    /// host → ["camera": true/false, "microphone": true/false]
    @Published private(set) var permissions: [String: [String: Bool]]
    private let defaults = UserDefaults.standard

    init() { permissions = defaults.dictionary(forKey: "sitePermissions") as? [String: [String: Bool]] ?? [:] }

    /// Kayıtlı karar varsa onu döndürür; yoksa sorar ve (`remember` ise) kaydeder.
    func resolve(host: String, kinds: [String], remember: Bool) -> Bool {
        let stored = kinds.compactMap { permissions[host]?[$0] }
        if stored.count == kinds.count { return !stored.contains(false) }
        let alert = NSAlert()
        alert.messageText = kinds.count > 1 ? L("\(host) kameranızı ve mikrofonunuzu kullanmak istiyor")
            : kinds.first == "camera" ? L("\(host) kameranızı kullanmak istiyor") : L("\(host) mikrofonunuzu kullanmak istiyor")
        alert.informativeText = remember
            ? L("Seçiminiz bu site için hatırlanır; Ayarlar → Gizlilik bölümünden sıfırlayabilirsiniz.")
            : L("Gizli sekmede seçiminiz hatırlanmaz.")
        alert.addButton(withTitle: L("Reddet")) // varsayılan (Enter) düğme reddetmektir
        alert.addButton(withTitle: L("İzin Ver"))
        let allow = alert.runModal() == .alertSecondButtonReturn
        if remember {
            for kind in kinds { permissions[host, default: [:]][kind] = allow }
            defaults.set(permissions, forKey: "sitePermissions")
        }
        return allow
    }

    func reset(_ host: String) {
        permissions[host] = nil
        defaults.set(permissions, forKey: "sitePermissions")
    }
}

/// "Kapatırken tarama verilerini temizle" açıksa, temizlik bitene kadar çıkışı bekletir.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var startupSound: NSSound?

    /// Açılış sesi (NOX/Resources/startup.mp3, 2 sn). Birim testleri uygulamayı başlattığında çalmaz.
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = PowerMonitor.shared // güç kaynağı değişimini izlemeye başla
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              let url = Bundle.main.url(forResource: "startup", withExtension: "mp3") else { return }
        startupSound = NSSound(contentsOf: url, byReference: true)
        startupSound?.play()
    }

    @MainActor
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard UserDefaults.standard.bool(forKey: "clearOnQuit") else { return .terminateNow }
        TabManager.clearBrowsingData { sender.reply(toApplicationShouldTerminate: true) }
        // WebKit yanıt vermezse uygulama asılı kalmasın.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}
