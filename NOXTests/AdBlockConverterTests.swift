import XCTest
@testable import NOX

final class AdBlockConverterTests: XCTestCase {
    private func convert(_ lines: String...) -> [[String: Any]] { AdBlockConverter.rules(from: lines.joined(separator: "\n")) }
    private func trigger(_ r: [String: Any]) -> [String: Any] { r["trigger"] as! [String: Any] }
    private func action(_ r: [String: Any]) -> [String: String] { r["action"] as! [String: String] }

    func testNetworkRules() {
        let r = convert("||ads.example.com^", "/banner/*/img$third-party,domain=A.com|b.com", "@@||good.com/ok.js$script")
        XCTAssertEqual(r.count, 4) // 2 engelleme + 1 istisna + üst çerçeve kuralı
        XCTAssertEqual(trigger(r[0])["url-filter"] as? String, "^[^:]+:(//)?([^/]+\\.)?ads\\.example\\.com[^a-zA-Z0-9_.%-]")
        XCTAssertEqual(action(r[0])["type"], "block")
        XCTAssertEqual(trigger(r[1])["url-filter"] as? String, "/banner/.*/img")
        XCTAssertEqual(trigger(r[1])["load-type"] as? [String], ["third-party"])
        XCTAssertEqual(trigger(r[1])["if-domain"] as? [String], ["*a.com", "*b.com"])
        XCTAssertEqual(action(r[2])["type"], "ignore-previous-rules")
        XCTAssertEqual(trigger(r[2])["resource-type"] as? [String], ["script"])
        XCTAssertEqual(trigger(r[3])["load-context"] as? [String], ["top-frame"])
    }

    func testCosmeticRulesComeAfterTopFrameRule() {
        let r = convert("##.sponsored", "example.com,~sub.example.com##.x", "site.com##.ad", "||t.co^")
        XCTAssertEqual(r.count, 4) // karışık (dahil+hariç) alan adlı kural atlanır
        XCTAssertEqual(action(r[0])["type"], "block")
        XCTAssertEqual(action(r[1])["type"], "ignore-previous-rules")
        XCTAssertEqual(action(r[2]), ["type": "css-display-none", "selector": ".sponsored"])
        XCTAssertNil(trigger(r[2])["if-domain"])
        XCTAssertEqual(trigger(r[3])["if-domain"] as? [String], ["*site.com"])
    }

    func testUnsupportedRulesAreSkipped() {
        XCTAssertTrue(convert(
            "! yorum", "[Adblock Plus 2.0]", "||x.com^$redirect=noop.js", "example.com#@#.ad", "##div:has-text(Reklam)",
            "example.com##+js(aopr, foo)", "/ads[0-9]+/", "||x.com^$~script", "$third-party", "*$image", "||reklam.com/ç"
        ).isEmpty)
    }
}
