import SwiftUI

/// Komut paleti (⌘K): tek kutudan komut çalıştırma, açık sekmeye geçme, yer imi/geçmiş açma veya arama.
struct CommandPalette: View {
    @EnvironmentObject var tm: TabManager
    @State private var query = ""
    @State private var index = 0
    @FocusState private var focused: Bool

    struct Item: Identifiable {
        let id: String
        let icon: String
        let title: String
        var subtitle = ""
        let run: () -> Void
    }

    private func toggle(_ key: String) { UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key) }

    private var commands: [Item] {
        [
            Item(id: "c.new", icon: "plus", title: "Yeni Sekme") { tm.newTab() },
            Item(id: "c.private", icon: "eyeglasses", title: "Yeni Gizli Sekme") { tm.newTab(isPrivate: true) },
            Item(id: "c.reopen", icon: "arrow.uturn.backward", title: "Kapatılan Sekmeyi Yeniden Aç") { tm.reopenClosed() },
            Item(id: "c.pin", icon: "pin", title: "Sekmeyi Sabitle / Sabitlemeyi Kaldır") { if let id = tm.selectedID { tm.togglePin(id) } },
            Item(id: "c.split", icon: "rectangle.split.2x1", title: "Bölünmüş Görünüm") { tm.toggleSplit() },
            Item(id: "c.pip", icon: "pip", title: "Resim İçinde Resim") { tm.selected?.togglePiP() },
            Item(id: "c.downloads", icon: "arrow.down.circle", title: "İndirmeler") { tm.downloadsVisible = true },
            Item(id: "c.find", icon: "magnifyingglass", title: "Sayfada Bul") { tm.findVisible = true },
            Item(id: "c.bookmark", icon: "star", title: "Yer İmi Ekle / Kaldır") { tm.toggleBookmark() },
            Item(id: "c.dark", icon: "moon", title: "Web Sayfalarını Karart") { toggle("darkWeb") },
            Item(id: "c.vertical", icon: "sidebar.squares.left", title: "Dikey Sekmeler") { toggle("verticalTabs") },
            Item(id: "c.sidebar", icon: "sidebar.left", title: "Kenar Çubuğu") { toggle("showSidebar") },
            Item(id: "c.saver", icon: "leaf", title: "Pil Tasarrufu Modu") { toggle("batterySaver") },
            Item(id: "c.game", icon: "moon.stars", title: "Spirit Quest'i Oyna") { tm.newTab(url: GameSchemeHandler.gameURL) },
            Item(id: "c.update", icon: "arrow.triangle.2.circlepath", title: "Güncellemeleri Denetle") { Updater.shared.checkManually() },
        ] + tm.workspaces.filter { $0 != tm.workspace }.map { ws in
            Item(id: "w." + ws, icon: "square.stack.3d.up", title: "Çalışma Alanı: \(ws)") { tm.setWorkspace(ws) }
        }
    }

    private var items: [Item] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return commands }
        let has = { (s: String) in s.localizedCaseInsensitiveContains(q) }
        let tabs = tm.tabs.filter { has($0.title) || has($0.url?.absoluteString ?? "") }.map { tab in
            Item(id: "t." + tab.id.uuidString, icon: "rectangle.on.rectangle", title: tab.title, subtitle: "Sekmeye geç") {
                tm.setWorkspace(tab.workspace)
                tm.select(tab.id)
            }
        }
        let sites = (tm.bookmarks.matching(q).prefix(4).map { ($0, "star") } + tm.history.matching(q).prefix(4).map { ($0, "clock") }).map { site, icon in
            Item(id: "s." + site.id.uuidString, icon: icon, title: site.title, subtitle: site.url.host ?? "") { tm.newTab(url: site.url) }
        }
        let open = Item(id: "open", icon: "arrow.right.circle", title: q, subtitle: "Ara veya adrese git") { tm.open(q) }
        return Array((commands.filter { has($0.title) } + tabs + sites).prefix(11)) + [open]
    }

    private func close() { tm.paletteVisible = false }
    private func run(_ item: Item?) { close(); item?.run() }

    var body: some View {
        let list = items
        ZStack(alignment: .top) {
            Color.black.opacity(0.35).contentShape(Rectangle()).onTapGesture(perform: close)
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "command").foregroundStyle(Color.noxNeon)
                    TextField("Komut, sekme, yer imi veya arama…", text: $query)
                        .textFieldStyle(.plain).font(.system(size: 15)).focused($focused)
                        .onSubmit { run(list.indices.contains(index) ? list[index] : list.first) }
                        .onKeyPress(.downArrow) { index = min(index + 1, list.count - 1); return .handled }
                        .onKeyPress(.upArrow) { index = max(index - 1, 0); return .handled }
                        .onKeyPress(.escape) { close(); return .handled }
                }
                .padding(12)
                Color.noxSilver.opacity(0.15).frame(height: 1)
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, item in
                            Button { run(item) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: item.icon).frame(width: 18).foregroundStyle(Color.noxNeon)
                                    Text(item.title).lineLimit(1).foregroundStyle(.white)
                                    Spacer(minLength: 8)
                                    Text(item.subtitle).lineLimit(1).font(.caption).foregroundStyle(Color.noxSilver.opacity(0.7))
                                }
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.noxPurple.opacity(i == index ? 0.45 : 0)))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 340)
            }
            .frame(width: 540)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.noxPanel))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.noxPurple.opacity(0.8), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
            .padding(.top, 90)
        }
        .onAppear { focused = true }
        .onChange(of: query) { index = 0 }
    }
}
