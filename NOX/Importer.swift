import Foundation

/// Başka tarayıcılardan içe aktarma. Safari, Chrome ve Firefox'un dışa aktardığı dosyaları okur:
/// yer imleri için HTML (Netscape biçimi), parolalar için CSV.
enum Importer {
    static func bookmarks(fromHTML html: String) -> [(title: String, url: URL)] {
        let regex = try! NSRegularExpression(pattern: #"<a\s[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let ns = html as NSString
        return regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            guard let url = URL(string: decode(ns.substring(with: m.range(at: 1)))), url.scheme == "http" || url.scheme == "https" else { return nil }
            let title = decode(ns.substring(with: m.range(at: 2)).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
            return (title.isEmpty ? (url.host ?? url.absoluteString) : title, url)
        }
    }

    private static func decode(_ s: String) -> String {
        [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'")]
            .reduce(s) { $0.replacingOccurrences(of: $1.0, with: $1.1) }.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// RFC 4180: tırnaklı alanlar, alan içinde virgül, satır sonu ve "" kaçışı.
    static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], field = "", quoted = false
        var it = text.replacingOccurrences(of: "\r\n", with: "\n").makeIterator()
        var pending = it.next()
        while let ch = pending {
            pending = it.next()
            if quoted {
                if ch == "\"" {
                    if pending == "\"" { field.append("\""); pending = it.next() } else { quoted = false }
                } else { field.append(ch) }
            } else if ch == "\"" { quoted = true }
            else if ch == "," { row.append(field); field = "" }
            else if ch == "\n" || ch == "\r" { row.append(field); field = ""; rows.append(row); row = [] }
            else { field.append(ch) }
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows.filter { $0 != [""] }
    }

    /// Başlık satırındaki "url", "username", "password" sütunlarını bulur (Chrome, Safari ve Firefox dışa aktarımları).
    static func passwords(fromCSV text: String) -> [(host: String, username: String, password: String)] {
        let rows = parseCSV(text)
        guard let header = rows.first?.map({ $0.lowercased().trimmingCharacters(in: .whitespaces) }),
              let u = header.firstIndex(where: { $0 == "url" || $0 == "origin" || $0 == "login_uri" }),
              let n = header.firstIndex(where: { $0 == "username" || $0 == "login_username" }),
              let p = header.firstIndex(where: { $0 == "password" || $0 == "login_password" }) else { return [] }
        return rows.dropFirst().compactMap { r in
            guard r.count > max(u, n, p), !r[p].isEmpty, let host = URL(string: r[u])?.host else { return nil }
            return (host, r[n], r[p])
        }
    }
}
