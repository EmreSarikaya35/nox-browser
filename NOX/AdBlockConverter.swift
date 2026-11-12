import Foundation

/// Adblock Plus / uBlock Origin filtre sözdizimini WebKit içerik engelleyici (WKContentRuleList) kurallarına çevirir.
/// WebKit'in ifade edemediği kurallar (scriptlet, prosedürel kozmetik, redirect, csp, regex kuralları…) atlanır;
/// yanlış çevirmek yerine atlamak siteleri bozmamak için bilinçli tercihtir.
enum AdBlockConverter {
    static let maxRules = 150_000 // WebKit'in liste başına sınırı

    private static let types = [
        "script": "script", "image": "image", "stylesheet": "style-sheet", "css": "style-sheet",
        "xmlhttprequest": "raw", "xhr": "raw", "subdocument": "document", "frame": "document",
        "font": "font", "media": "media", "websocket": "websocket", "ping": "ping", "beacon": "ping",
        "other": "other", "object": "other", "popup": "popup",
    ]
    private static let unsupportedSelectors = [
        ":has-text(", ":contains(", ":-abp-", ":upward(", ":matches-css", ":xpath(", ":remove(", ":style(",
        ":matches-path(", ":min-text-length(", ":watch-attr(", ":others(", ":nth-ancestor(", ":matches-attr(", ":matches-media(",
    ]

    static func encode(_ text: String) -> (json: String, count: Int) {
        let r = rules(from: text)
        let data = (try? JSONSerialization.data(withJSONObject: r)) ?? Data("[]".utf8)
        return (String(decoding: data, as: UTF8.self), r.count)
    }

    static func rules(from text: String) -> [[String: Any]] {
        var blocks: [[String: Any]] = [], exceptions: [[String: Any]] = [], cosmetics: [[String: Any]] = []
        text.enumerateLines { line, _ in
            let l = line.trimmingCharacters(in: .whitespaces)
            guard let first = l.first, first != "!", first != "[", l.utf8.allSatisfy({ $0 > 31 && $0 < 127 }) else { return }
            if let hash = l.firstIndex(of: "#"), !l[..<hash].contains(where: { "/|@\"!$".contains($0) }) {
                let rest = l[l.index(after: hash)...]
                if rest.hasPrefix("#") {
                    if let c = cosmetic(domains: l[..<hash], selector: rest.dropFirst()) { cosmetics.append(c) }
                    return
                }
                if let c = rest.first, "@?$%".contains(c) { return } // kozmetik istisna / prosedürel / scriptlet
            }
            if let (rule, isException) = network(l) {
                if isException { exceptions.append(rule) } else { blocks.append(rule) }
            }
        }
        if blocks.isEmpty && cosmetics.isEmpty { return [] }
        // ABP'de ağ kuralları ana sayfa gezinmesini engellemez: üst çerçeve belgesi için önceki kuralları yok say.
        // Kozmetik kurallar bundan SONRA gelmeli, yoksa onlar da iptal olur.
        let top: [String: Any] = [
            "trigger": ["url-filter": ".*", "resource-type": ["document"], "load-context": ["top-frame"]],
            "action": ["type": "ignore-previous-rules"],
        ]
        return Array((blocks + exceptions + [top] + cosmetics).prefix(maxRules))
    }

    private static func cosmetic(domains: Substring, selector: Substring) -> [String: Any]? {
        let sel = String(selector)
        guard !sel.isEmpty, !sel.hasPrefix("+js"), !sel.hasPrefix("^"), !unsupportedSelectors.contains(where: sel.contains) else { return nil }
        var trigger: [String: Any] = ["url-filter": ".*"]
        guard addDomains(domains.split(separator: ","), to: &trigger) else { return nil }
        return ["trigger": trigger, "action": ["type": "css-display-none", "selector": sel]]
    }

    private static func network(_ line: String) -> (rule: [String: Any], isException: Bool)? {
        var s = Substring(line)
        let isException = s.hasPrefix("@@")
        if isException { s.removeFirst(2) }
        var options: [Substring] = []
        if let d = s.lastIndex(of: "$") {
            options = s[s.index(after: d)...].split(separator: ",")
            s = s[..<d]
        }
        if s.count > 1, s.hasPrefix("/"), s.hasSuffix("/") { return nil } // regex kuralı
        var trigger: [String: Any] = [:]
        var resourceTypes = Set<String>()
        for option in options {
            let o = option.lowercased()
            switch o {
            case "third-party", "3p": trigger["load-type"] = ["third-party"]
            case "~third-party", "1p", "first-party": trigger["load-type"] = ["first-party"]
            case "important": break
            case "match-case": trigger["url-filter-is-case-sensitive"] = true
            default:
                if o.hasPrefix("domain=") || o.hasPrefix("from=") {
                    guard addDomains(o.drop { $0 != "=" }.dropFirst().split(separator: "|"), to: &trigger) else { return nil }
                } else if let t = types[o] { resourceTypes.insert(t) } else { return nil } // desteklenmeyen seçenek
            }
        }
        guard let filter = regex(s) else { return nil }
        if filter == ".*", trigger["if-domain"] == nil { return nil } // her şeyi engelleyecek kural
        trigger["url-filter"] = filter
        if !resourceTypes.isEmpty { trigger["resource-type"] = resourceTypes.sorted() }
        return (["trigger": trigger, "action": ["type": isException ? "ignore-previous-rules" : "block"]], isException)
    }

    /// `~` ile başlayanlar hariç tutma listesidir; WebKit ikisini aynı kuralda kabul etmez.
    private static func addDomains(_ list: [Substring], to trigger: inout [String: Any]) -> Bool {
        if list.isEmpty { return true }
        let negated = list.filter { $0.hasPrefix("~") }
        guard negated.isEmpty || negated.count == list.count, !list.contains(where: { $0.contains("*") }) else { return false }
        trigger[negated.isEmpty ? "if-domain" : "unless-domain"] = list.map { "*" + $0.drop { $0 == "~" }.lowercased() }
        return true
    }

    private static func regex(_ pattern: Substring) -> String? {
        var p = pattern
        var out = ""
        if p.hasPrefix("||") { out = "^[^:]+:(//)?([^/]+\\.)?"; p.removeFirst(2) }
        else if p.hasPrefix("|") { out = "^"; p.removeFirst() }
        let anchoredEnd = p.hasSuffix("|")
        if anchoredEnd { p.removeLast() }
        while p.hasPrefix("*") { p.removeFirst() }
        while p.hasSuffix("*") { p.removeLast() }
        if p.isEmpty { return out.isEmpty ? ".*" : nil }
        for ch in p {
            switch ch {
            case "*": out += ".*"
            case "^": out += "[^a-zA-Z0-9_.%-]" // ABP ayırıcı karakteri
            case ".", "+", "?", "$", "{", "}", "(", ")", "[", "]", "\\", "|": out += "\\" + String(ch)
            default: out.append(ch)
            }
        }
        return out + (anchoredEnd ? "$" : "")
    }
}
