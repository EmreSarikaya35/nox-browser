import Foundation

enum SearchEngine: String, CaseIterable, Identifiable {
    case duckduckgo = "DuckDuckGo", google = "Google", bing = "Bing", brave = "Brave"
    var id: String { rawValue }
    var searchURL: String {
        switch self {
        case .duckduckgo: return "https://duckduckgo.com/"
        case .google: return "https://www.google.com/search"
        case .bing: return "https://www.bing.com/search"
        case .brave: return "https://search.brave.com/search"
        }
    }
    static var current: SearchEngine {
        SearchEngine(rawValue: UserDefaults.standard.string(forKey: "searchEngine") ?? "") ?? .duckduckgo
    }
}

enum URLResolver {
    /// Adres çubuğu girdisini URL'ye çevirir: adres gibi görünüyorsa adres, değilse arama.
    static func resolve(_ input: String, engine: SearchEngine) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains(" ") {
            if let url = URL(string: text), ["http", "https", "file", "nox"].contains(url.scheme?.lowercased() ?? "") { return url }
            let host = text.prefix { $0 != "/" && $0 != ":" && $0 != "?" }
            let parts = host.split(separator: ".", omittingEmptySubsequences: false)
            let isIP = parts.count == 4 && parts.allSatisfy { UInt8($0) != nil }
            if host == "localhost" || isIP, let url = URL(string: "http://" + text) { return url }
            if parts.count > 1, !parts.contains(""), parts.last!.contains(where: \.isLetter),
               let url = URL(string: "https://" + text) { return url }
        }
        var c = URLComponents(string: engine.searchURL)!
        c.queryItems = [URLQueryItem(name: "q", value: text)]
        // URLComponents "+" işaretini kodlamaz; arama motorları onu boşluk sayar.
        c.percentEncodedQuery = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return c.url
    }
}
