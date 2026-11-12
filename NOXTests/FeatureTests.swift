import XCTest
@testable import NOX

final class FeatureTests: XCTestCase {
    func testBookmarkImport() {
        let html = """
        <!DOCTYPE NETSCAPE-Bookmark-file-1>
        <DL><p>
        <DT><H3>Klasör</H3>
        <DT><A HREF="https://example.com/a?x=1&amp;y=2" ADD_DATE="1">Örnek &amp; Site</A>
        <DT><a href="http://test.org/">  </a>
        <DT><A HREF="javascript:alert(1)">Kötü</A>
        <DT><A HREF="place:sort=8">Firefox özel</A>
        </DL>
        """
        let b = Importer.bookmarks(fromHTML: html)
        XCTAssertEqual(b.map(\.url.absoluteString), ["https://example.com/a?x=1&y=2", "http://test.org/"])
        XCTAssertEqual(b.map(\.title), ["Örnek & Site", "test.org"])
    }

    func testPasswordCSV() {
        XCTAssertEqual(Importer.parseCSV("a,\"b,c\",\"d \"\"e\"\"\"\r\n1,,3\n"), [["a", "b,c", "d \"e\""], ["1", "", "3"]])
        let chrome = "name,url,username,password,note\nSite,https://login.example.com/in,ali,\"p,a\"\"ss\",\nBoş,https://x.com,veli,,\nBozuk,adres-degil,u,p,\n"
        let p = Importer.passwords(fromCSV: chrome)
        XCTAssertEqual(p.count, 1)
        XCTAssertEqual(p.first?.host, "login.example.com")
        XCTAssertEqual(p.first?.username, "ali")
        XCTAssertEqual(p.first?.password, "p,a\"ss")
        XCTAssertEqual(Importer.passwords(fromCSV: "Title,URL,Username,Password,Notes,OTPAuth\nA,https://a.com/,u,p,,\n").first?.host, "a.com") // Safari
        XCTAssertTrue(Importer.passwords(fromCSV: "a,b\n1,2\n").isEmpty)
    }

    func testHLSParsing() {
        let base = URL(string: "https://cdn.example.com/v/master.m3u8")!
        let master = HLSPlaylist.parse("""
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
        low/index.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2"
        https://other.example.com/hi/index.m3u8
        """, base: base)
        XCTAssertEqual(master.variants.map(\.bandwidth), [800000, 2800000])
        XCTAssertEqual(master.variants.max { $0.bandwidth < $1.bandwidth }?.url.absoluteString, "https://other.example.com/hi/index.m3u8")
        XCTAssertEqual(master.variants[0].url.absoluteString, "https://cdn.example.com/v/low/index.m3u8")
        XCTAssertTrue(master.segments.isEmpty)

        let media = HLSPlaylist.parse("#EXTM3U\n#EXT-X-MAP:URI=\"init.mp4\"\n#EXTINF:4.0,\nseg0.m4s\n#EXTINF:4.0,\nseg1.m4s\n#EXT-X-ENDLIST\n", base: base)
        XCTAssertEqual(media.segments.map(\.lastPathComponent), ["seg0.m4s", "seg1.m4s"])
        XCTAssertEqual(media.initSegment?.absoluteString, "https://cdn.example.com/v/init.mp4")
        XCTAssertTrue(media.ended)
        XCTAssertFalse(media.encrypted)

        let locked = HLSPlaylist.parse("#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI=\"key\"\n#EXTINF:4,\na.ts\n", base: base)
        XCTAssertTrue(locked.encrypted)
        XCTAssertFalse(locked.ended) // canlı yayın
        XCTAssertFalse(HLSPlaylist.parse("#EXT-X-KEY:METHOD=NONE\n#EXTINF:4,\na.ts\n", base: base).encrypted)
    }

    @MainActor
    func testHLSDownloadConcatenatesSegments() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let write = { (name: String, text: String) in try Data(text.utf8).write(to: dir.appendingPathComponent(name)) }
        try write("master.m3u8", "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=100\nlow.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=900\nhigh.m3u8\n")
        try write("low.m3u8", "#EXTM3U\n#EXTINF:1,\nlow0.ts\n#EXT-X-ENDLIST\n")
        try write("high.m3u8", "#EXTM3U\n#EXT-X-MAP:URI=\"init.mp4\"\n#EXTINF:1,\na.m4s\n#EXTINF:1,\nb.m4s\n#EXT-X-ENDLIST\n")
        try write("init.mp4", "INIT"); try write("a.m4s", "AAA"); try write("b.m4s", "BB"); try write("low0.ts", "LOW")
        try write("locked.m3u8", "#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI=\"k\"\n#EXTINF:1,\na.m4s\n#EXT-X-ENDLIST\n")
        try write("live.m3u8", "#EXTM3U\n#EXTINF:1,\na.m4s\n")

        var progress: [Int64] = [], started: URL?
        let out = dir.appendingPathComponent("out")
        let dest = try await HLSPlaylist.download(dir.appendingPathComponent("master.m3u8"), referer: nil, to: out, name: "film",
                                                  started: { started = $0 }, progress: { got, _ in progress.append(got) })
        XCTAssertEqual(dest.lastPathComponent, "film.mp4") // fMP4 başlığı var → .mp4; en yüksek kalite seçildi
        XCTAssertEqual(started, dest)
        XCTAssertEqual(try String(contentsOf: dest, encoding: .utf8), "INITAAABB")
        XCTAssertEqual(progress, [4, 7, 9])

        for (name, _) in [("locked.m3u8", "şifreli"), ("live.m3u8", "canlı")] {
            do {
                _ = try await HLSPlaylist.download(dir.appendingPathComponent(name), referer: nil, to: out, name: "x", started: { _ in }, progress: { _, _ in })
                XCTFail("\(name) indirilmemeliydi")
            } catch { XCTAssertTrue(error is HLSError) }
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: out.path), ["film.mp4"]) // reddedilenler dosya bırakmaz
    }

    func testLanguageSelection() {
        XCTAssertEqual(Language.code(setting: "system", system: ["tr-TR", "en-US"]), "tr")
        XCTAssertEqual(Language.code(setting: "system", system: ["en-US"]), "en")
        XCTAssertEqual(Language.code(setting: "system", system: ["de-DE", "tr-TR"]), "en") // birinci dil Türkçe değil
        XCTAssertEqual(Language.code(setting: "system", system: ["ja-JP"]), "en")
        XCTAssertEqual(Language.code(setting: "system", system: []), "en")
        XCTAssertEqual(Language.code(setting: "en", system: ["tr-TR"]), "en") // ayar sistem dilini ezer
        XCTAssertEqual(Language.code(setting: "tr", system: ["de-DE"]), "tr")
    }

    func testVersionCompare() {
        XCTAssertTrue(Updater.isNewer("v0.7.0", than: "0.6.0"))
        XCTAssertTrue(Updater.isNewer("0.10.0", than: "0.9.9"))
        XCTAssertTrue(Updater.isNewer("1.0", than: "0.9.9"))
        XCTAssertFalse(Updater.isNewer("v0.6.0", than: "0.6.0"))
        XCTAssertFalse(Updater.isNewer("0.6", than: "0.6.0"))
        XCTAssertFalse(Updater.isNewer("0.5.9", than: "0.6.0"))
    }
}
