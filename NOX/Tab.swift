import Combine
import WebKit

/// Tek bir sekme. WKWebView ilk yüklemeye kadar oluşturulmaz (boş/uyuyan sekme bellek harcamaz).
@MainActor
final class Tab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
    let id = UUID()
    let isPrivate: Bool
    @Published var title = "Yeni Sekme"
    @Published var url: URL?
    @Published var isLoading = false
    @Published var progress = 0.0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var error: String?
    @Published private(set) var webView: WKWebView?

    var onNewTab: ((URL) -> Void)?
    var onVisit: ((String, URL) -> Void)?

    @Published private(set) var blockedCount = 0

    private let dataStore: WKWebsiteDataStore
    private let adBlock: AdBlockEngine
    private let downloads: DownloadManager
    private let privacy: PrivacyManager
    private var appliedRules: Int? // en son uygulanan kural sürümü (-1: bu sitede kapalı)
    private var pendingURL: URL?
    private var savedState: Any?
    private var sleepTask: Task<Void, Never>?
    private var subs = Set<AnyCancellable>()

    /// `loadNow: false` → oturumdan geri yüklenen sekme; seçilene kadar yüklenmez.
    init(url: URL?, isPrivate: Bool, dataStore: WKWebsiteDataStore, adBlock: AdBlockEngine,
         downloads: DownloadManager, privacy: PrivacyManager, loadNow: Bool = true) {
        self.isPrivate = isPrivate
        self.dataStore = dataStore
        self.adBlock = adBlock
        self.downloads = downloads
        self.privacy = privacy
        super.init()
        guard let url else { return }
        if loadNow { load(url) } else {
            pendingURL = url
            self.url = url
            title = url.host ?? url.absoluteString
        }
    }

    func load(_ url: URL) {
        pendingURL = nil
        savedState = nil
        error = nil
        self.url = url
        makeWebView().load(URLRequest(url: url))
    }

    func wake() {
        cancelSleep()
        if let state = savedState {
            savedState = nil
            pendingURL = nil
            makeWebView().interactionState = state // geri/ileri geçmişiyle birlikte geri yükler
        } else if let pendingURL { load(pendingURL) }
    }

    // MARK: Uyutma (arka plan sekmesinin WebView'ını ve web sürecini serbest bırakır)

    var isSleeping: Bool { webView == nil && url != nil }

    /// WebContent sürecinin kimliği (performans paneli için).
    /// shortcut: `_webProcessIdentifier` WebKit'in özel API'si; kaldırılırsa panelde sekme satırları boş kalır.
    var processID: pid_t? {
        guard let webView, webView.responds(to: Selector(("_webProcessIdentifier"))) else { return nil }
        return webView.value(forKey: "_webProcessIdentifier") as? pid_t
    }

    // shortcut: uyutulan sekmede form girdileri ve kaydırma konumu kaybolur; gerekirse uyutmadan önce JS ile sakla.
    func sleep() {
        guard let webView else { return }
        cancelSleep()
        savedState = webView.interactionState
        pendingURL = webView.url ?? url
        subs.removeAll()
        self.webView = nil
        appliedRules = nil
        isLoading = false; canGoBack = false; canGoForward = false
    }

    /// Tek seferlik zamanlayıcı; ses/video oynatan veya kamera/mikrofon kullanan sekme uyutulmaz, süre yeniden başlar.
    func scheduleSleep(after seconds: Int) {
        cancelSleep()
        guard webView != nil else { return }
        sleepTask = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(seconds))
                guard let self, !Task.isCancelled, let webView = self.webView else { return }
                if webView.cameraCaptureState != .none || webView.microphoneCaptureState != .none { continue }
                if self.downloads.isBusy(webView) { continue } // süren indirme kesilmesin
                // shortcut: yalnızca ana çerçevedeki medya görülür; iframe içindeki oynatıcılar (gömülü video) fark edilmez.
                let playing = try? await webView.evaluateJavaScript(
                    "[...document.querySelectorAll('video,audio')].some(m => !m.paused && !m.ended)")
                if Task.isCancelled { return }
                if playing as? Bool == true { continue }
                self.sleep()
                return
            }
        }
    }

    func cancelSleep() {
        sleepTask?.cancel()
        sleepTask = nil
    }

    func reload() {
        if error != nil || webView?.url == nil { if let url { load(url) } } else { webView?.reload() }
    }

    /// Başlangıç sayfasına döner ve WebView'ı serbest bırakır.
    func reset() {
        cancelSleep()
        subs.removeAll()
        webView = nil
        savedState = nil; pendingURL = nil
        appliedRules = nil; blockedCount = 0
        url = nil; error = nil; title = "Yeni Sekme"
        isLoading = false; canGoBack = false; canGoForward = false
    }

    /// `factor` nil ise yakınlaştırmayı sıfırlar.
    func zoom(_ factor: Double?) {
        guard let webView else { return }
        webView.pageZoom = factor.map { min(3, max(0.5, webView.pageZoom * $0)) } ?? 1
    }

    func find(_ text: String, backwards: Bool = false) async -> Bool {
        let c = WKFindConfiguration()
        c.backwards = backwards
        c.wraps = true
        return (try? await webView?.find(text, configuration: c))?.matchFound ?? false
    }

    private func makeWebView() -> WKWebView {
        if let webView { return webView }
        let c = WKWebViewConfiguration()
        c.websiteDataStore = dataStore
        c.applicationNameForUserAgent = "Version/17.5 Safari/605.1.15" // siteler Safari gibi davransın
        c.preferences.javaScriptCanOpenWindowsAutomatically = false // kullanıcı tıklaması olmayan pop-up'ları engelle
        c.preferences.isElementFullscreenEnabled = true
        c.setURLSchemeHandler(GameSchemeHandler(), forURLScheme: GameSchemeHandler.scheme) // gömülü oyun: nox://game/
        c.userContentController.add(GameMessageProxy { [weak self] in self?.reset() }, name: "spiritQuest")
        if UserDefaults.standard.bool(forKey: "blockAutoplay") { c.mediaTypesRequiringUserActionForPlayback = .all }
        let w = WKWebView(frame: .zero, configuration: c)
        w.navigationDelegate = self
        w.uiDelegate = self
        w.allowsBackForwardNavigationGestures = true
        w.allowsMagnification = true
        w.publisher(for: \.title).sink { [weak self] in if let t = $0, !t.isEmpty { self?.title = t } }.store(in: &subs)
        w.publisher(for: \.url).sink { [weak self] in if let u = $0 { self?.url = u } }.store(in: &subs)
        w.publisher(for: \.isLoading).sink { [weak self] in self?.isLoading = $0 }.store(in: &subs)
        w.publisher(for: \.estimatedProgress).sink { [weak self] in self?.progress = $0 }.store(in: &subs)
        w.publisher(for: \.canGoBack).sink { [weak self] in self?.canGoBack = $0 }.store(in: &subs)
        w.publisher(for: \.canGoForward).sink { [weak self] in self?.canGoForward = $0 }.store(in: &subs)
        webView = w
        return w
    }

    // MARK: WKNavigationDelegate
    // Sertifika doğrulaması WebKit varsayılanına bırakıldı: geçersiz sertifika yüklenmez, hata kullanıcıya gösterilir.

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { error = nil; blockedCount = 0 }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.targetFrame?.isMainFrame == true, let url = navigationAction.request.url {
            // Uygulamanın kendi iç sayfalarına filtre uygulanmaz.
            applyContentRules(host: url.host, internalPage: url.scheme == GameSchemeHandler.scheme)
        }
        decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let disposition = (navigationResponse.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition") ?? ""
        if disposition.lowercased().hasPrefix("attachment") { decisionHandler(.download) }
        else if navigationResponse.canShowMIMEType { decisionHandler(.allow) }
        // Gösterilemeyen içerik yalnızca ana çerçevede indirilir; gömülü çerçeveler (reklam vb.) dosya indirtemez.
        else { decisionHandler(navigationResponse.isForMainFrame ? .download : .cancel) }
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        downloads.adopt(download, from: webView, isPrivate: isPrivate)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        downloads.adopt(download, from: webView, isPrivate: isPrivate)
    }

    /// Sayfadaki indirilebilir medya kaynaklarını listeler (yalnızca ana çerçeve).
    func detectMedia() async -> [MediaCandidate] {
        guard let webView, let raw = try? await webView.evaluateJavaScript(MediaDetector.script) as? [[String: Any]] else { return [] }
        return MediaDetector.parse(raw)
    }

    /// Gidilen siteye göre reklam engelleme kurallarını takar/çıkarır (beyaz liste, genel anahtar, liste güncellemesi).
    func applyContentRules(host: String?, internalPage: Bool? = nil) {
        guard let webView else { return }
        let isInternal = internalPage ?? (webView.url?.scheme == GameSchemeHandler.scheme)
        let active = !isInternal && adBlock.isActive(on: host)
        let key = active ? adBlock.revision : -1
        guard key != appliedRules else { return }
        appliedRules = key
        let controller = webView.configuration.userContentController
        controller.removeAllContentRuleLists()
        if active { adBlock.activeLists(for: host).forEach(controller.add) }
    }

    // shortcut: engellenen istek sayacı için tek yol WebKit'in özel (private) delegate çağrısı; App Store'a uygun değil.
    // WebKit bu çağrıyı kaldırırsa sayaç 0 kalır, engelleme etkilenmez.
    @objc(_webView:contentRuleListWithIdentifier:performedAction:forURL:)
    func webView(_ webView: WKWebView, contentRuleListWithIdentifier identifier: String, performedAction action: NSObject, forURL url: URL) {
        guard action.responds(to: Selector(("blockedLoad"))), action.value(forKey: "blockedLoad") as? Bool == true else { return }
        blockedCount += 1
        adBlock.noteBlocked()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !isPrivate, let u = webView.url { onVisit?(webView.title ?? "", u) }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { show(error) }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { show(error) }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        error = "Sayfa işlemi beklenmedik şekilde sonlandı."
    }

    private func show(_ e: Error) {
        let ns = e as NSError
        if ns.code == NSURLErrorCancelled || (ns.domain == "WebKitErrorDomain" && ns.code == 102) { return }
        error = e.localizedDescription
    }

    // MARK: WKUIDelegate

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let u = navigationAction.request.url { onNewTab?(u) }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        alert(frame, message, cancel: false).runModal()
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(alert(frame, message, cancel: true).runModal() == .alertFirstButtonReturn)
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        completionHandler(panel.runModal() == .OK ? panel.urls : nil)
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let kinds = type == .camera ? ["camera"] : type == .microphone ? ["microphone"] : ["camera", "microphone"]
        decisionHandler(privacy.resolve(host: origin.host, kinds: kinds, remember: !isPrivate) ? .grant : .deny)
    }

    // MARK: Parola doldurma
    // Betikler yalnızca kullanıcı panelden istediğinde, sayfanın kendi betiklerinden yalıtılmış dünyada çalışır;
    // değerler dizgeye gömülmez, argüman olarak geçer.

    var isSecureForPasswords: Bool {
        error == nil && (url?.scheme == "https" || ["localhost", "127.0.0.1"].contains(url?.host ?? ""))
    }

    private static let loginJS = """
    const textLike = e => ['text', 'email', 'tel', ''].includes((e.getAttribute('type') || '').toLowerCase());
    const visible = e => e.offsetParent !== null;
    const passwords = [...document.querySelectorAll('input[type=password]')].filter(visible);
    const userFor = p => [...(p.form || document).querySelectorAll('input')]
      .filter(e => textLike(e) && visible(e) && (e.compareDocumentPosition(p) & Node.DOCUMENT_POSITION_FOLLOWING)).pop();
    const set = (el, v) => {
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(el, v);
      el.dispatchEvent(new Event('input', {bubbles: true}));
      el.dispatchEvent(new Event('change', {bubbles: true}));
    };
    """

    /// Sayfada parolası yazılmış giriş formunu okur.
    func readLoginForm() async -> (username: String, password: String)? {
        let js = Self.loginJS + """
        const p = passwords.find(e => e.value);
        if (!p) return null;
        const u = userFor(p);
        return {username: u ? u.value : '', password: p.value};
        """
        guard let webView, isSecureForPasswords,
              let r = try? await webView.callAsyncJavaScript(js, arguments: [:], in: nil, contentWorld: .defaultClient) as? [String: String],
              let password = r["password"], !password.isEmpty else { return nil }
        return (r["username"] ?? "", password)
    }

    /// Giriş formunu doldurur; yalnızca kullanıcı adı alanı varsa (iki adımlı giriş) onu doldurur. Form gönderilmez.
    func fillLogin(username: String, password: String) async -> Bool {
        let js = Self.loginJS + """
        const p = passwords[0];
        if (p) { const usr = userFor(p); if (usr) set(usr, user); set(p, pass); return 2; }
        const only = [...document.querySelectorAll('input')].find(e => visible(e) && textLike(e));
        if (only) { set(only, user); return 1; }
        return 0;
        """
        guard let webView, isSecureForPasswords else { return false }
        let r = try? await webView.callAsyncJavaScript(js, arguments: ["user": username, "pass": password], in: nil, contentWorld: .defaultClient)
        return ((r as? NSNumber)?.intValue ?? 0) > 0
    }

    private func alert(_ frame: WKFrameInfo, _ message: String, cancel: Bool) -> NSAlert {
        let a = NSAlert()
        a.messageText = frame.request.url?.host ?? "Sayfa"
        a.informativeText = message
        a.addButton(withTitle: "Tamam")
        if cancel { a.addButton(withTitle: "Vazgeç") }
        return a
    }
}
