import SwiftUI

private func bytes(_ n: Int64) -> String { ByteCountFormatter.string(fromByteCount: n, countStyle: .file) }

struct DownloadsPanel: View {
    @ObservedObject var manager: DownloadManager
    @ObservedObject var tab: Tab
    @State private var media: [MediaCandidate] = []
    @State private var scanned = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bu sayfadaki medya").font(.headline)
            if !scanned {
                Text("Taranıyor…").font(.caption).foregroundStyle(.secondary)
            } else if media.isEmpty {
                Text("Bu sayfada doğrudan indirilebilir medya bulunamadı.").font(.caption).foregroundStyle(.secondary)
            } else {
                // Popover içinde ScrollView kendi yüksekliğini bildirmez; yükseklik satır sayısından hesaplanır.
                ScrollView {
                    VStack(spacing: 6) { ForEach(media) { mediaRow($0) } }
                }
                .frame(height: min(150, CGFloat(media.count) * 36))
            }
            Text("Yalnızca doğrudan dosya olarak sunulan medya indirilebilir. Korumasız HLS akışları da indirilir. DRM korumalı içerik ve akış tabanlı oynatıcılar (YouTube, Netflix vb.) desteklenmez.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack {
                Text("İndirmeler").font(.headline)
                Spacer()
                Button("Listeyi Temizle") { manager.clearInactive() }.disabled(manager.items.isEmpty)
            }
            if manager.items.isEmpty {
                Text("Henüz indirme yok.").font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 8) { ForEach(manager.items) { DownloadRow(item: $0, manager: manager) } }
                }
                .frame(height: min(230, CGFloat(manager.items.count) * 58))
            }
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "folder").foregroundStyle(.secondary)
                Text(manager.folder.path).font(.caption).lineLimit(1).truncationMode(.middle).help(manager.folder.path)
                Spacer()
                Button("Değiştir…") { manager.chooseFolder() }
            }
        }
        .controlSize(.small)
        .tint(.noxPurple)
        .padding(14)
        .frame(width: 400)
        .background(Color.noxPanel)
        .preferredColorScheme(.dark)
        .task {
            media = await tab.detectMedia()
            scanned = true
            for i in media.indices {
                if let url = media[i].url, !media[i].isHLS { media[i].size = await DownloadManager.size(of: url, referer: tab.url) }
            }
        }
    }

    private func mediaRow(_ m: MediaCandidate) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(m.name).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                Text(m.unsupportedReason ?? ([m.label] + (m.size.map { [bytes($0)] } ?? [])).joined(separator: " · "))
                    .font(.caption2).foregroundStyle(m.unsupportedReason == nil ? Color.noxSilver : Color.orange)
            }
            Spacer(minLength: 0)
            // Desteklenmeyen kaynakta indirme düğmesi gösterilmez.
            if let url = m.url, let webView = tab.webView {
                NoxIconButton(symbol: "arrow.down.circle", help: "İndir", tint: .noxNeon) {
                    if m.isHLS { manager.startHLS(url, referer: tab.url, from: webView, isPrivate: tab.isPrivate) }
                    else { manager.start(url, referer: tab.url, from: webView, isPrivate: tab.isPrivate) }
                }
            }
        }
        .opacity(m.unsupportedReason == nil ? 1 : 0.7)
    }
}

private struct DownloadRow: View {
    @ObservedObject var item: DownloadItem
    let manager: DownloadManager

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 2) {
                Text(item.filename).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 4)
                switch item.state {
                case .downloading:
                    if !item.isStream { NoxIconButton(symbol: "pause.fill", help: "Duraklat") { manager.pause(item) } }
                    NoxIconButton(symbol: "xmark", help: "İptal Et") { manager.cancel(item) }
                case .paused:
                    NoxIconButton(symbol: "play.fill", help: "Devam Et", disabled: !item.canResume) { manager.resume(item) }
                    NoxIconButton(symbol: "xmark", help: "İptal Et") { manager.cancel(item) }
                case .finished:
                    NoxIconButton(symbol: "magnifyingglass", help: "Finder'da Göster") { manager.reveal(item) }
                    NoxIconButton(symbol: "trash", help: "Listeden Kaldır (dosya silinmez)") { manager.remove(item) }
                case .failed, .cancelled:
                    if item.canResume { NoxIconButton(symbol: "arrow.clockwise", help: "Yeniden Dene") { manager.resume(item) } }
                    NoxIconButton(symbol: "trash", help: "Listeden Kaldır") { manager.remove(item) }
                }
            }
            if item.state == .downloading || item.state == .paused, item.total > 0 {
                ProgressView(value: min(1, Double(item.received) / Double(item.total))).tint(.noxNeon)
            }
            Text(status).font(.caption2).foregroundStyle(statusColor).lineLimit(2)
        }
    }

    private var progressText: String {
        item.total > 0 ? "\(bytes(item.received)) / \(bytes(item.total))" : bytes(item.received)
    }

    private var status: String {
        switch item.state {
        case .downloading: return progressText
        case .paused: return L("Duraklatıldı") + " · " + progressText
        case .finished: return L("Tamamlandı") + " · \(bytes(item.received)) · \(item.date.formatted(date: .abbreviated, time: .shortened))"
        case .failed(let e): return L("Başarısız: \(e)")
        case .cancelled: return L("İptal edildi")
        }
    }

    private var statusColor: Color {
        if case .failed = item.state { return .orange }
        return .noxSilver
    }
}
