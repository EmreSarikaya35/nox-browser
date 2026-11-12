import XCTest
@testable import NOX

final class URLResolverTests: XCTestCase {
    private func r(_ s: String) -> String? { URLResolver.resolve(s, engine: .duckduckgo)?.absoluteString }

    func testAddresses() {
        XCTAssertEqual(r("https://apple.com/mac"), "https://apple.com/mac")
        XCTAssertEqual(r("  apple.com "), "https://apple.com")
        XCTAssertEqual(r("example.org/a?b=1"), "https://example.org/a?b=1")
        XCTAssertEqual(r("localhost:3000"), "http://localhost:3000")
        XCTAssertEqual(r("nox://game/index.html"), "nox://game/index.html")
        XCTAssertEqual(r("192.168.1.1/admin"), "http://192.168.1.1/admin")
    }

    func testSearches() {
        XCTAssertNil(r("   "))
        XCTAssertEqual(r("swift nedir"), "https://duckduckgo.com/?q=swift%20nedir")
        XCTAssertEqual(r("merhaba"), "https://duckduckgo.com/?q=merhaba")
        XCTAssertEqual(r("3.14"), "https://duckduckgo.com/?q=3.14")
        XCTAssertEqual(r("c++"), "https://duckduckgo.com/?q=c%2B%2B")
        XCTAssertEqual(r("apple.com nedir"), "https://duckduckgo.com/?q=apple.com%20nedir")
    }
}
