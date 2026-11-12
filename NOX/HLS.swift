import Foundation

/// HLS (.m3u8) çalma listesi ayrıştırıcısı. Yalnızca korumasız, bitmiş (canlı olmayan) akışlar indirilebilir.
struct HLSPlaylist {
    var variants: [(bandwidth: Int, url: URL)] = []  // ana liste: kalite seçenekleri
    var segments: [URL] = []                         // medya listesi: parçalar
    var initSegment: URL?                            // fMP4 başlığı (#EXT-X-MAP); varsa çıktı .mp4, yoksa .ts
    var encrypted = false                            // #EXT-X-KEY (AES/DRM): indirilmez
    var ended = false                                // #EXT-X-ENDLIST yoksa canlı yayındır
    var byteRanges = false                           // tek dosyadan bayt aralığı: desteklenmiyor

    static func parse(_ text: String, base: URL) -> HLSPlaylist {
        var p = HLSPlaylist()
        var pendingBandwidth: Int?
        let attr = { (line: String, key: String) -> String? in
            guard let r = line.range(of: key + "=") else { return nil }
            let rest = line[r.upperBound...]
            return rest.hasPrefix("\"") ? String(rest.dropFirst().prefix { $0 != "\"" }) : String(rest.prefix { $0 != "," })
        }
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#EXT-X-STREAM-INF") { pendingBandwidth = Int(attr(line, "BANDWIDTH") ?? "") ?? 0 }
            else if line.hasPrefix("#EXT-X-KEY") { if attr(line, "METHOD") != "NONE" { p.encrypted = true } }
            else if line.hasPrefix("#EXT-X-MAP") { p.initSegment = attr(line, "URI").flatMap { URL(string: $0, relativeTo: base)?.absoluteURL } }
            else if line.hasPrefix("#EXT-X-BYTERANGE") { p.byteRanges = true }
            else if line.hasPrefix("#EXT-X-ENDLIST") { p.ended = true }
            else if !line.isEmpty, !line.hasPrefix("#"), let url = URL(string: line, relativeTo: base)?.absoluteURL {
                if let b = pendingBandwidth { p.variants.append((b, url)); pendingBandwidth = nil } else { p.segments.append(url) }
            }
        }
        return p
    }
}

extension HLSPlaylist {
    /// Akışı indirir: ana listede en yüksek kaliteyi seçer, parçaları sırayla tek dosyaya yazar ve dosyayı döndürür.
    /// `started` hedef dosya belli olunca, `progress` her parçadan sonra (inen bayt, tahmini toplam) çağrılır.
    @MainActor
    static func download(_ url: URL, referer: URL?, to folder: URL, name: String,
                         started: (URL) -> Void, progress: (Int64, Int64) -> Void) async throws -> URL {
        let session = URLSession(configuration: .ephemeral)
        let fetch = { (u: URL) async throws -> Data in
            var request = URLRequest(url: u)
            if let referer { request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer") }
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw URLError(.badServerResponse) }
            return data
        }
        var list = parse(String(decoding: try await fetch(url), as: UTF8.self), base: url)
        if let best = list.variants.max(by: { $0.bandwidth < $1.bandwidth }) {
            list = parse(String(decoding: try await fetch(best.url), as: UTF8.self), base: best.url)
        }
        if list.encrypted { throw HLSError(L("Akış şifreli veya korumalı; indirilemez.")) }
        if !list.ended { throw HLSError(L("Canlı yayınlar indirilemez.")) }
        if list.byteRanges || list.segments.isEmpty { throw HLSError(L("Bu akış biçimi desteklenmiyor.")) }

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let dest = DownloadManager.uniqueURL(in: folder, name: name + (list.initSegment == nil ? ".ts" : ".mp4"))
        FileManager.default.createFile(atPath: dest.path, contents: nil)
        started(dest)
        let handle = try FileHandle(forWritingTo: dest)
        defer { try? handle.close() }
        let parts = [list.initSegment].compactMap { $0 } + list.segments
        var received: Int64 = 0
        for (i, part) in parts.enumerated() {
            try Task.checkCancellation()
            let data = try await fetch(part)
            try handle.write(contentsOf: data)
            received += Int64(data.count)
            progress(received, received * Int64(parts.count) / Int64(i + 1)) // toplam: kalan parçalara göre tahmin
        }
        return dest
    }
}

struct HLSError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
