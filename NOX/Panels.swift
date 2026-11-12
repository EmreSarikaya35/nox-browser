import SwiftUI

struct StartPage: View {
    @EnvironmentObject var tm: TabManager
    @ObservedObject var bookmarks: SiteStore
    @State private var query = ""
    @AppStorage("startBackground") private var backgroundPath = ""
    @State private var background: NSImage?

    var body: some View {
        VStack(spacing: 18) {
            // Dakikada bir güncellenir; saniyelik timer yok.
            TimelineView(.everyMinute) { ctx in
                VStack(spacing: 4) {
                    Text(ctx.date, format: .dateTime.hour().minute())
                        .font(.system(size: 64, weight: .thin, design: .rounded)).foregroundStyle(.white)
                    Text(ctx.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .foregroundStyle(Color.noxSilver)
                }
            }
            TextField("Web'de ara", text: $query)
                .textFieldStyle(.plain).font(.system(size: 15))
                .padding(.horizontal, 16).frame(width: 460, height: 40)
                .background(Capsule().fill(Color.noxPanel))
                .overlay(Capsule().stroke(Color.noxPurple.opacity(0.7), lineWidth: 1))
                .onSubmit { tm.open(query) }
            Button { tm.selected?.load(GameSchemeHandler.gameURL) } label: {
                Label("Spirit Quest: The Forgotten Shrine", systemImage: "moon.stars.fill")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.noxNeon)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .overlay(Capsule().stroke(Color.noxPurple.opacity(0.7), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Gömülü oyunu aç (⇧⌘G)")
            if !bookmarks.items.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(96)), count: 4), spacing: 14) {
                    ForEach(bookmarks.items.prefix(8)) { site in
                        Button { tm.open(site.url.absoluteString) } label: {
                            VStack(spacing: 6) {
                                Group {
                                    if let icon = Favicons.cached(site.url.host) {
                                        Image(nsImage: icon).resizable().interpolation(.high).frame(width: 24, height: 24)
                                    } else {
                                        Text(String((site.url.host ?? site.title).replacingOccurrences(of: "www.", with: "").prefix(1)).uppercased())
                                            .font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.noxNeon)
                                    }
                                }
                                    .frame(width: 48, height: 48)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.noxPanel))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.noxSilver.opacity(0.25), lineWidth: 1))
                                Text(site.title).font(.caption).lineLimit(1).foregroundStyle(Color.noxSilver)
                            }
                            .frame(width: 96)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if let background {
                // Metin okunaklı kalsın diye görselin üstüne koyu bir katman konur.
                Image(nsImage: background).resizable().scaledToFill().overlay(Color.noxBlack.opacity(0.55))
            } else { Color.noxBlack }
        }
        .clipped()
        .task(id: backgroundPath) { background = backgroundPath.isEmpty ? nil : NSImage(contentsOfFile: backgroundPath) }
    }
}

struct BookmarksBar: View {
    @EnvironmentObject var tm: TabManager
    @ObservedObject var bookmarks: SiteStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(bookmarks.items) { site in
                    Button { tm.open(site.url.absoluteString) } label: {
                        HStack(spacing: 4) {
                            if let icon = Favicons.cached(site.url.host) { Image(nsImage: icon).resizable().interpolation(.high).frame(width: 12, height: 12) }
                            Text(site.title)
                        }
                    }
                        .buttonStyle(.plain).font(.system(size: 11)).lineLimit(1)
                        .foregroundStyle(Color.noxSilver)
                        .padding(.horizontal, 8).padding(.vertical, 4).frame(maxWidth: 160)
                        .help(site.url.absoluteString)
                        .contextMenu { Button("Yer İmini Sil") { bookmarks.remove(site.url) } }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 26)
        .background(Color.noxPanel.opacity(0.6))
    }
}

struct Sidebar: View {
    @EnvironmentObject var tm: TabManager
    @ObservedObject var bookmarks: SiteStore
    @ObservedObject var history: SiteStore
    @State private var showHistory = false

    var body: some View {
        let store = showHistory ? history : bookmarks
        VStack(spacing: 0) {
            Picker("", selection: $showHistory) {
                Text("Yer İmleri").tag(false)
                Text("Geçmiş").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().padding(8)
            if store.items.isEmpty {
                Text(showHistory ? "Geçmiş boş" : "Henüz yer imi yok (⌘D)")
                    .font(.caption).foregroundStyle(Color.noxSilver.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.items) { site in
                    Button { tm.open(site.url.absoluteString) } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(site.title).lineLimit(1).foregroundStyle(.white)
                            Text(site.url.host ?? site.url.absoluteString).font(.caption2).lineLimit(1).foregroundStyle(Color.noxSilver.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu { Button("Sil") { store.remove(site.url) } }
                }
                .scrollContentBackground(.hidden)
                if showHistory {
                    Button("Geçmişi Temizle") { history.clear() }.buttonStyle(.plain)
                        .font(.caption).foregroundStyle(Color.noxNeon).padding(8)
                }
            }
        }
        .background(Color.noxPanel.opacity(0.5))
    }
}
