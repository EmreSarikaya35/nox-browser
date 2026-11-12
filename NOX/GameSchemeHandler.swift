import WebKit

/// Gömülü oyunu (uygulama paketindeki `SpiritQuest/` klasörü) `nox://game/…` adresinden sunar.
/// file:// yerine özel şema kullanılır: JavaScript modülleri yüklenebilir ve oyunun kayıtları
/// (localStorage) sabit bir kökene bağlanır. Ağ erişimi gerekmez.
final class GameSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "nox"
    static let gameURL = URL(string: "nox://game/index.html")!
    private static let mime = ["html": "text/html", "js": "text/javascript", "css": "text/css", "json": "application/json",
                               "png": "image/png", "svg": "image/svg+xml", "md": "text/plain"]

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, url.host == "game",
              let root = Bundle.main.resourceURL?.appendingPathComponent("SpiritQuest").standardizedFileURL else {
            return task.didFailWithError(URLError(.badURL))
        }
        let path = url.path.isEmpty || url.path == "/" ? "index.html" : String(url.path.dropFirst())
        let file = root.appendingPathComponent(path).standardizedFileURL
        // Paket dışına çıkan yollar ("..") sunulmaz.
        guard file.path.hasPrefix(root.path + "/"), let data = try? Data(contentsOf: file) else {
            return task.didFailWithError(URLError(.fileDoesNotExist))
        }
        let type = (Self.mime[file.pathExtension] ?? "application/octet-stream") + "; charset=utf-8"
        task.didReceive(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                        headerFields: ["Content-Type": type, "Content-Length": String(data.count), "Cache-Control": "no-cache"])!)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

/// Oyunun "Tarayıcıya Dön" düğmesinden gelen mesajı sekmeye iletir (zayıf bağ: sekme kapanınca sızıntı olmaz).
final class GameMessageProxy: NSObject, WKScriptMessageHandler {
    private let onExit: () -> Void
    init(onExit: @escaping () -> Void) { self.onExit = onExit }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        // Yalnızca oyunun kendi sayfasından gelen mesaj kabul edilir.
        guard message.frameInfo.isMainFrame, message.frameInfo.request.url?.scheme == GameSchemeHandler.scheme,
              message.body as? String == "exit" else { return }
        onExit()
    }
}
