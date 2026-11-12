import Combine
import UserNotifications
import WebKit

@MainActor
final class DownloadItem: ObservableObject, Identifiable {
    enum State: Equatable { case downloading, paused, finished, failed(String), cancelled }

    let id = UUID()
    let source: URL?
    let isPrivate: Bool
    let date: Date
    @Published var filename: String
    @Published var state: State
    @Published var received: Int64 = 0
    @Published var total: Int64 = -1 // bilinmiyorsa -1
    var destination: URL?

    fileprivate var download: WKDownload?
    @Published fileprivate var resumeData: Data? // yayınlanır: gelince "Devam Et" düğmesi etkinleşir
    fileprivate weak var webView: WKWebView?
    fileprivate var progressSub: AnyCancellable?

    var canResume: Bool { resumeData != nil }

    fileprivate init(source: URL?, isPrivate: Bool, filename: String, state: State = .downloading, date: Date = Date()) {
        self.source = source; self.isPrivate = isPrivate; self.filename = filename; self.state = state; self.date = date
    }
}

/// Tüm indirmeler WebKit'in WKDownload API'siyle yapılır: sayfanın çerezlerini/oturumunu kullanır,
/// duraklatma (resume data) ve karantina işaretlemesi WebKit tarafından sağlanır.
@MainActor
final class DownloadManager: NSObject, ObservableObject, WKDownloadDelegate {
    @Published private(set) var items: [DownloadItem] = []
    @Published var folder: URL { didSet { UserDefaults.standard.set(folder.path, forKey: "downloadFolder") } }
    var onStart: (() -> Void)?

    private var byDownload: [ObjectIdentifier: DownloadItem] = [:]
    private lazy var helper = WKWebView() // kaynak sekme kapanmışsa devam ettirmek için; sayfa yüklemez
    private let historyFile: URL

    private struct Record: Codable {
        var filename: String, path: String?, source: URL?, size: Int64, date: Date, error: String?
    }

    var activeCount: Int { items.filter { $0.state == .downloading }.count }

    override init() {
        let fm = FileManager.default
        folder = UserDefaults.standard.string(forKey: "downloadFolder").map { URL(fileURLWithPath: $0) }
            ?? fm.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        historyFile = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("NOX/downloads.json")
        super.init()
        let records = (try? JSONDecoder().decode([Record].self, from: Data(contentsOf: historyFile))) ?? []
        items = records.map {
            let item = DownloadItem(source: $0.source, isPrivate: false, filename: $0.filename,
                                    state: $0.error.map { .failed($0) } ?? .finished, date: $0.date)
            item.destination = $0.path.map { URL(fileURLWithPath: $0) }
            item.received = $0.size; item.total = $0.size
            return item
        }
    }

    // MARK: Başlatma

    /// Verilen adresi (ör. tespit edilen medya dosyası) sekmenin oturumuyla indirir.
    func start(_ url: URL, referer: URL?, from webView: WKWebView, isPrivate: Bool) {
        var request = URLRequest(url: url)
        if let referer { request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer") }
        Task { adopt(await webView.startDownload(using: request), from: webView, isPrivate: isPrivate) }
    }

    /// Gezinmenin dönüştüğü indirmeyi devralır.
    func adopt(_ download: WKDownload, from webView: WKWebView, isPrivate: Bool) {
        let url = download.originalRequest?.url
        let item = DownloadItem(source: url, isPrivate: isPrivate, filename: url?.lastPathComponent ?? "indirilen")
        item.webView = webView
        attach(download, to: item)
        items.insert(item, at: 0)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } // sistem yalnızca ilk seferde sorar
        onStart?()
    }

    private func attach(_ download: WKDownload, to item: DownloadItem) {
        download.delegate = self
        item.download = download
        item.state = .downloading
        byDownload[ObjectIdentifier(download)] = item
        // Progress KVO'su arka iş parçacığından gelir; arayüzü saniyede en çok 4 kez güncelle.
        item.progressSub = download.progress.publisher(for: \.fractionCompleted)
            .throttle(for: .milliseconds(250), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak item, weak download] _ in
                guard let item, let p = download?.progress else { return }
                item.received = p.completedUnitCount
                if p.totalUnitCount > 0 { item.total = p.totalUnitCount }
            }
    }

    private func detach(_ item: DownloadItem) -> WKDownload? {
        let d = item.download
        if let d { byDownload[ObjectIdentifier(d)] = nil }
        item.download = nil
        item.progressSub = nil
        return d
    }

    /// Uyutma kararı için: bu WebView'dan süren indirme var mı?
    func isBusy(_ webView: WKWebView) -> Bool {
        items.contains { $0.webView === webView && $0.state == .downloading }
    }

    // MARK: Kullanıcı eylemleri

    func pause(_ item: DownloadItem) {
        guard item.state == .downloading, let d = detach(item) else { return }
        item.state = .paused
        Task {
            item.resumeData = await d.cancel()
            if item.resumeData == nil { item.state = .failed("Sunucu devam ettirmeyi desteklemiyor") ; save() }
        }
    }

    func resume(_ item: DownloadItem) {
        guard let data = item.resumeData else { return }
        item.resumeData = nil
        Task { attach(await (item.webView ?? helper).resumeDownload(fromResumeData: data), to: item) }
    }

    func cancel(_ item: DownloadItem) {
        if let d = detach(item) { Task { _ = await d.cancel() } }
        item.resumeData = nil
        item.state = .cancelled
        if let dest = item.destination { try? FileManager.default.removeItem(at: dest) } // yarım kalan kendi dosyamız
        save()
    }

    func remove(_ item: DownloadItem) {
        if item.state == .downloading || item.state == .paused { cancel(item) }
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearInactive() {
        items.removeAll { $0.state != .downloading && $0.state != .paused }
        save()
    }

    func reveal(_ item: DownloadItem) {
        if let dest = item.destination { NSWorkspace.shared.activateFileViewerSelecting([dest]) }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = folder
        if panel.runModal() == .OK, let url = panel.url { folder = url }
    }

    // MARK: WKDownloadDelegate

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        guard let item = byDownload[ObjectIdentifier(download)] else { return completionHandler(nil) }
        if let existing = item.destination { return completionHandler(existing) } // devam ettirilen indirme
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let dest = Self.uniqueURL(in: folder, name: Self.safeName(suggestedFilename))
        item.filename = dest.lastPathComponent
        item.destination = dest
        if response.expectedContentLength > 0 { item.total = response.expectedContentLength }
        completionHandler(dest)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let item = byDownload[ObjectIdentifier(download)] else { return }
        _ = detach(item)
        let size = item.destination.flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }.map(Int64.init)
        item.received = size ?? item.received
        item.total = item.received
        item.state = .finished
        save()
        let content = UNMutableNotificationContent()
        content.title = "İndirme tamamlandı"
        content.body = item.filename
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: nil))
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let item = byDownload[ObjectIdentifier(download)] else { return } // duraklatma/iptal: zaten ayrıldı
        _ = detach(item)
        item.resumeData = resumeData
        item.state = .failed(error.localizedDescription)
        save()
    }

    // MARK: Yardımcılar

    /// Sunucunun önerdiği adı güvenli hale getirir: yol bileşenleri ve gizli dosya noktaları atılır.
    nonisolated static func safeName(_ suggested: String) -> String {
        let name = (suggested as NSString).lastPathComponent
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .drop { $0 == "." }
        return name.isEmpty || name == "/" ? "indirilen" : String(name)
    }

    /// Var olan dosyanın üzerine yazmamak için "ad (2).uzantı" biçiminde boş bir ad bulur.
    nonisolated static func uniqueURL(in folder: URL, name: String) -> URL {
        let base = (name as NSString).deletingPathExtension, ext = (name as NSString).pathExtension
        var url = folder.appendingPathComponent(name)
        var n = 1
        while FileManager.default.fileExists(atPath: url.path) {
            n += 1
            url = folder.appendingPathComponent(ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)")
        }
        return url
    }

    /// Dosya boyutunu HEAD isteğiyle sorar (çerez saklamayan oturumla). Sunucu söylemezse nil.
    static func size(of url: URL, referer: URL?) async -> Int64? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        if let referer { request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer") }
        guard let (_, response) = try? await headSession.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200, response.expectedContentLength > 0 else { return nil }
        return response.expectedContentLength
    }
    private static let headSession = URLSession(configuration: .ephemeral)

    // Geçmişe yalnızca bitmiş/başarısız ve gizli olmayan indirmeler yazılır.
    // shortcut: duraklatılmış indirmeler uygulama kapanınca kaybolur (resume data saklanmıyor), yarım dosya diskte kalır.
    private func save() {
        let records = items.filter { !$0.isPrivate }.compactMap { item -> Record? in
            switch item.state {
            case .finished: return Record(filename: item.filename, path: item.destination?.path, source: item.source, size: item.received, date: item.date, error: nil)
            case .failed(let e): return Record(filename: item.filename, path: nil, source: item.source, size: item.received, date: item.date, error: e)
            default: return nil
            }
        }
        try? JSONEncoder().encode(Array(records.prefix(200))).write(to: historyFile, options: .atomic)
    }
}
