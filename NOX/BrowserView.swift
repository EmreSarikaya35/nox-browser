import SwiftUI
import WebKit

struct BrowserView: View {
    @EnvironmentObject var tm: TabManager
    @AppStorage("batterySaver") private var batterySaver = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            TabBar()
            if let tab = tm.selected {
                TabContent(tab: tab, bookmarks: tm.bookmarks, history: tm.history, adBlock: tm.adBlock,
                           downloads: tm.downloads).id(tab.id)
            }
        }
        .background(Color.noxBlack)
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(.dark)
        // Pil tasarrufunda veya sistemde "Hareketi azalt" açıkken tüm arayüz animasyonları kapanır.
        .transaction { if batterySaver || reduceMotion { $0.animation = nil } }
        .onAppear { AppDelegate.tabManager = tm }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in tm.saveSession() }
    }
}

// MARK: Sekme çubuğu

struct TabBar: View {
    @EnvironmentObject var tm: TabManager

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tm.tabs) { TabChip(tab: $0, selected: $0.id == tm.selectedID) }
                }
            }
            NoxIconButton(symbol: "plus", help: "Yeni Sekme (⌘T)") { tm.newTab() }
            NoxIconButton(symbol: "eyeglasses", help: "Yeni Gizli Sekme (⇧⌘N)") { tm.newTab(isPrivate: true) }
            Color.clear.frame(width: 40) // pencereyi sürüklemek için boş alan
        }
        .padding(.leading, 78) // trafik ışıkları
        .frame(height: 38)
        .background(Color.noxGray)
    }
}

struct TabChip: View {
    @EnvironmentObject var tm: TabManager
    @ObservedObject var tab: Tab
    let selected: Bool
    @State private var hover = false

    var body: some View {
        HStack(spacing: 6) {
            if tab.isPrivate { Image(systemName: "eyeglasses").foregroundStyle(Color.noxNeon) }
            if tab.isLoading { Circle().fill(Color.noxNeon).frame(width: 6, height: 6) }
            if tab.isSleeping { Image(systemName: "moon.zzz").font(.system(size: 10)).foregroundStyle(Color.noxSilver.opacity(0.7)).help("Uyuyor") }
            Text(tab.title).lineLimit(1).font(.system(size: 12))
                .foregroundStyle(selected ? Color.white : Color.noxSilver)
            Spacer(minLength: 0)
            if hover || selected {
                Button { tm.close(tab.id) } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).frame(width: 16, height: 16).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(Color.noxSilver).help("Sekmeyi Kapat (⌘W)").accessibilityLabel("Sekmeyi kapat")
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 180, height: 28)
        .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Color.noxPanel : Color.noxPurple.opacity(hover ? 0.18 : 0)))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(tab.isPrivate ? Color.noxPurple : Color.noxSilver.opacity(selected ? 0.3 : 0), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { tm.select(tab.id) }
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: Araç çubuğu + sayfa

struct TabContent: View {
    @EnvironmentObject var tm: TabManager
    @ObservedObject var tab: Tab
    @ObservedObject var bookmarks: SiteStore
    @ObservedObject var history: SiteStore
    @ObservedObject var adBlock: AdBlockEngine
    @ObservedObject var downloads: DownloadManager
    @State private var showPasswords = false
    @AppStorage("showSidebar") private var showSidebar = false
    @AppStorage("showBookmarksBar") private var showBookmarksBar = true
    @AppStorage("batterySaver") private var batterySaver = false
    @State private var showAdBlock = false
    @State private var showPerformance = false
    @State private var text = ""
    @State private var findText = ""
    @State private var findFailed = false
    @FocusState private var addressFocused: Bool
    @FocusState private var findFocused: Bool

    private var suggestions: [Site] {
        guard addressFocused, !text.isEmpty, text != tab.url?.absoluteString else { return [] }
        return Array((bookmarks.matching(text) + history.matching(text)).prefix(6))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if showBookmarksBar, !bookmarks.items.isEmpty { BookmarksBar(bookmarks: bookmarks) }
            Color.noxSilver.opacity(0.15).frame(height: 1)
            HStack(spacing: 0) {
                if showSidebar {
                    Sidebar(bookmarks: bookmarks, history: history).frame(width: 240)
                    Color.noxSilver.opacity(0.15).frame(width: 1)
                }
                ZStack(alignment: .top) {
                    page
                    if !suggestions.isEmpty { suggestionList }
                    if tm.findVisible { findBar.frame(maxWidth: .infinity, alignment: .trailing) }
                }
            }
        }
        .onAppear {
            text = tab.url?.absoluteString ?? ""
            // Yüklü sayfada pencerenin varsayılan odağı adres çubuğuna düşmesin.
            DispatchQueue.main.async { addressFocused = tab.url == nil }
        }
        .onChange(of: tab.url) { if !addressFocused { text = tab.url?.absoluteString ?? "" } }
        .onChange(of: tm.focusAddress) { addressFocused = true }
        .onChange(of: tm.findVisible) { findFocused = tm.findVisible }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            NoxIconButton(symbol: "chevron.left", help: "Geri (⌘[)", disabled: !tab.canGoBack) { tab.webView?.goBack() }
            NoxIconButton(symbol: "chevron.right", help: "İleri (⌘])", disabled: !tab.canGoForward) { tab.webView?.goForward() }
            if tab.isLoading {
                NoxIconButton(symbol: "xmark", help: "Durdur") { tab.webView?.stopLoading() }
            } else {
                NoxIconButton(symbol: "arrow.clockwise", help: "Yenile (⌘R)", disabled: tab.url == nil) { tab.reload() }
            }
            NoxIconButton(symbol: "house", help: "Ana Sayfa (⇧⌘H)") { tm.goHome() }
            addressField
            shieldButton
            downloadsButton
            NoxIconButton(symbol: "speedometer", help: "Pil ve performans", tint: batterySaver ? .noxNeon : .noxSilver) { showPerformance.toggle() }
                .popover(isPresented: $showPerformance, arrowEdge: .bottom) { PerformancePanel(tm: tm) }
            NoxIconButton(symbol: "key", help: "Parolalar") { showPasswords.toggle() }
                .popover(isPresented: $showPasswords, arrowEdge: .bottom) { PasswordPanel(passwords: tm.passwords, tab: tab) }
            NoxIconButton(symbol: bookmarks.contains(tab.url) ? "star.fill" : "star", help: "Yer İmi Ekle/Kaldır (⌘D)",
                          disabled: tab.url == nil, tint: bookmarks.contains(tab.url) ? .noxNeon : .noxSilver) { tm.toggleBookmark() }
            NoxIconButton(symbol: "sidebar.left", help: "Kenar Çubuğu (⇧⌘L)", tint: showSidebar ? .noxNeon : .noxSilver) { showSidebar.toggle() }
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background(batterySaver ? AnyShapeStyle(Color.noxPanel) : AnyShapeStyle(.ultraThinMaterial))
    }

    private var shieldButton: some View {
        let active = adBlock.isActive(on: tab.url?.host)
        return Button { showAdBlock.toggle() } label: {
            HStack(spacing: 3) {
                Image(systemName: active ? "shield.lefthalf.filled" : "shield.slash").font(.system(size: 13, weight: .medium))
                if active, tab.blockedCount > 0 { Text("\(tab.blockedCount)").font(.system(size: 10, weight: .semibold)).monospacedDigit() }
            }
            .foregroundStyle(active ? Color.noxNeon : Color.noxSilver)
            .padding(.horizontal, 6).frame(height: 26).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Reklam engelleyici")
        .accessibilityLabel("Reklam engelleyici, bu sayfada \(tab.blockedCount) engellendi")
        .popover(isPresented: $showAdBlock, arrowEdge: .bottom) { AdBlockPanel(engine: adBlock, tab: tab) }
    }

    private var downloadsButton: some View {
        let active = downloads.activeCount
        return Button { tm.downloadsVisible.toggle() } label: {
            HStack(spacing: 3) {
                Image(systemName: "arrow.down.circle").font(.system(size: 13, weight: .medium))
                if active > 0 { Text("\(active)").font(.system(size: 10, weight: .semibold)).monospacedDigit() }
            }
            .foregroundStyle(active > 0 ? Color.noxNeon : Color.noxSilver)
            .padding(.horizontal, 6).frame(height: 26).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("İndirmeler ve sayfadaki medya (⌥⌘L)")
        .accessibilityLabel("İndirmeler, \(active) etkin")
        .popover(isPresented: $tm.downloadsVisible, arrowEdge: .bottom) { DownloadsPanel(manager: downloads, tab: tab) }
    }

    private var addressField: some View {
        HStack(spacing: 6) {
            switch tab.error == nil ? tab.url?.scheme : nil { // yüklenemeyen sayfada kilit gösterme
            case "https": Image(systemName: "lock.fill").help("Güvenli bağlantı (HTTPS)")
            case "http": Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).help("Bağlantı güvenli değil (HTTP)")
            default: Image(systemName: "magnifyingglass")
            }
            TextField(tab.isPrivate ? "Gizli sekme — ara veya adres gir" : "Ara veya adres gir", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($addressFocused)
                .onSubmit { go(text) }
        }
        .font(.system(size: 11))
        .foregroundStyle(Color.noxSilver)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.noxPanel))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(addressFocused ? Color.noxNeon : Color.noxSilver.opacity(0.25), lineWidth: 1))
        .overlay(alignment: .bottomLeading) {
            if tab.isLoading {
                GeometryReader { g in
                    Capsule().fill(Color.noxNeon).frame(width: g.size.width * tab.progress, height: 2)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .padding(.horizontal, 6)
            }
        }
        .animation(.easeOut(duration: 0.15), value: addressFocused)
    }

    private func go(_ input: String) {
        tm.open(input)
        addressFocused = false
        text = tab.url?.absoluteString ?? input
    }

    @ViewBuilder private var page: some View {
        if let error = tab.error {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 34)).foregroundStyle(Color.noxNeon)
                Text("Sayfa açılamadı").font(.title3).foregroundStyle(.white)
                Text(error).foregroundStyle(Color.noxSilver).multilineTextAlignment(.center).textSelection(.enabled)
                Text(tab.url?.absoluteString ?? "").font(.caption).foregroundStyle(Color.noxSilver.opacity(0.6)).lineLimit(1)
                Button("Yeniden Dene") { tab.reload() }.tint(.noxPurple).buttonStyle(.borderedProminent)
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let webView = tab.webView {
            WebViewHost(webView: webView)
        } else {
            StartPage(bookmarks: bookmarks)
        }
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { site in
                Button { go(site.url.absoluteString) } label: {
                    HStack {
                        Text(site.title).lineLimit(1).foregroundStyle(.white)
                        Text(site.url.absoluteString).lineLimit(1).foregroundStyle(Color.noxNeon)
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 12)).padding(.horizontal, 12).padding(.vertical, 7).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.noxPanel))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.noxSilver.opacity(0.25), lineWidth: 1))
        .frame(maxWidth: 640)
        .padding(.top, 4)
    }

    private var findBar: some View {
        HStack(spacing: 4) {
            TextField("Sayfada bul", text: $findText)
                .textFieldStyle(.plain).frame(width: 180).focused($findFocused)
                .onSubmit { find(backwards: false) }
            if findFailed { Text("Bulunamadı").font(.caption).foregroundStyle(.orange) }
            NoxIconButton(symbol: "chevron.up", help: "Önceki") { find(backwards: true) }
            NoxIconButton(symbol: "chevron.down", help: "Sonraki") { find(backwards: false) }
            NoxIconButton(symbol: "xmark", help: "Kapat") { tm.findVisible = false }
        }
        .padding(.leading, 10).padding(.trailing, 4).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.noxPanel))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.noxPurple, lineWidth: 1))
        .padding(8)
        .onExitCommand { tm.findVisible = false }
    }

    private func find(backwards: Bool) {
        guard !findText.isEmpty else { return }
        Task { findFailed = !(await tab.find(findText, backwards: backwards)) }
    }
}

/// Seçili sekmenin WKWebView'ını gösterir. Arka plandaki sekmelerin view'ları pencereden çıkarıldığı için
/// WebKit onları görünmez sayar ve timer/animasyonlarını kendiliğinden kısar.
struct WebViewHost: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ container: NSView, context: Context) {
        guard webView.superview !== container else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)
    }
}
