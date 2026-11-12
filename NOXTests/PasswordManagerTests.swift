import XCTest
@testable import NOX

final class PasswordManagerTests: XCTestCase {
    @MainActor
    func testKeychainRoundTrip() {
        let pm = PasswordManager()
        let host = "nox-test-\(UUID().uuidString).invalid"
        let c = Credential(host: host, username: "deneme")
        defer { pm.delete(c) }

        XCTAssertTrue(pm.save(host: host, username: "deneme", password: "ilk"))
        XCTAssertTrue(pm.save(host: host, username: "deneme", password: "ikinci ş")) // üzerine yazar, çoğaltmaz
        XCTAssertEqual(pm.credentials(for: host), [c])
        XCTAssertEqual(pm.password(for: c), "ikinci ş")
        XCTAssertTrue(pm.credentials(for: "evil-" + host).isEmpty) // yalnızca tam alan adı
        pm.delete(c)
        XCTAssertTrue(pm.credentials(for: host).isEmpty)
        XCTAssertNil(pm.password(for: c))
    }
}
