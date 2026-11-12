import Foundation

struct MediaCandidate: Identifiable {
    let id = UUID()
    let url: URL?              // desteklenmeyenlerde nil olabilir (blob:)
    let name: String
    let label: String          // "Video · 1280×720 · MP4"
    let unsupportedReason: String?
    var isHLS = false
    var size: Int64?
}

/// Sayfadaki doğrudan indirilebilir medya dosyalarını bulur. Betik yalnızca kullanıcı indirmeler panelini
/// açtığında bir kez çalışır; sayfaya kalıcı kod eklenmez, oynatıcıya veya korumalara müdahale edilmez.
enum MediaDetector {
    static let script = """
    (() => {
      const out = [];
      const add = (url, kind, type, w, h) => { if (url && out.length < 200) out.push({url, kind, type: type || '', w: w || 0, h: h || 0}); };
      document.querySelectorAll('video,audio').forEach(m => {
        const kind = m.tagName.toLowerCase();
        add(m.currentSrc || m.src, kind, '', m.videoWidth, m.videoHeight);
        m.querySelectorAll('source').forEach(s =>
          add(s.src, kind, s.type, 0, +((s.getAttribute('res') || s.getAttribute('size') || s.getAttribute('label') || '').replace(/\\D/g, '')) || 0));
      });
      const ext = /\\.(mp4|m4v|mov|webm|mkv|m3u8|mp3|m4a|aac|ogg|oga|opus|wav|flac)([?#]|$)/i;
      document.querySelectorAll('a[href]').forEach(a => { if (ext.test(a.href)) add(a.href, 'link', '', 0, 0); });
      return out;
    })()
    """

    private static let audioExtensions: Set = ["mp3", "m4a", "aac", "ogg", "oga", "opus", "wav", "flac"]

    static func parse(_ raw: [[String: Any]]) -> [MediaCandidate] {
        var seen = Set<String>()
        var out: [MediaCandidate] = []
        for d in raw {
            guard let s = d["url"] as? String, seen.insert(s).inserted else { continue }
            let type = (d["type"] as? String ?? "").lowercased()
            let w = (d["w"] as? NSNumber)?.intValue ?? 0, h = (d["h"] as? NSNumber)?.intValue ?? 0
            let url = URL(string: s)
            let ext = url?.pathExtension.lowercased() ?? ""
            let scheme = url?.scheme?.lowercased() ?? ""

            var reason: String?
            if scheme == "blob" || scheme == "mediasource" {
                reason = L("Akış tabanlı veya korumalı oynatıcı — indirilemez")
            } else if ext == "mpd" || type.contains("dash") {
                reason = L("DASH akışı — desteklenmiyor")
            } else if scheme != "http" && scheme != "https" { continue }

            let kind = d["kind"] as? String
            // <video> içindeki .ogg gibi kaynaklar videodur; uzantıya yalnızca düz bağlantılarda bakılır.
            let isAudio = kind == "audio" || (kind != "video" && (audioExtensions.contains(ext) || type.hasPrefix("audio/")))
            var parts = [isAudio ? L("Ses") : L("Video")]
            if w > 0, h > 0 { parts.append("\(w)×\(h)") } else if h > 0 { parts.append("\(h)p") }
            let format = ext.isEmpty ? (type.split(separator: ";").first?.split(separator: "/").last.map(String.init) ?? "") : ext
            if !format.isEmpty { parts.append(format.uppercased()) }

            let name = url.map { $0.lastPathComponent.isEmpty ? ($0.host ?? s) : $0.lastPathComponent } ?? L("Gömülü oynatıcı")
            let isHLS = reason == nil && (ext == "m3u8" || type.contains("mpegurl"))
            if isHLS { parts.append(L("HLS akışı")) }
            out.append(MediaCandidate(url: reason == nil ? url : nil, name: scheme == "blob" ? L("Gömülü oynatıcı") : name,
                                      label: parts.joined(separator: " · "), unsupportedReason: reason, isHLS: isHLS))
        }
        return out
    }
}
