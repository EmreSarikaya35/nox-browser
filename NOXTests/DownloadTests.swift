import XCTest
@testable import NOX

final class DownloadTests: XCTestCase {
    func testSafeName() {
        XCTAssertEqual(DownloadManager.safeName("film.mp4"), "film.mp4")
        XCTAssertEqual(DownloadManager.safeName("../../Library/LaunchAgents/kotu.plist"), "kotu.plist")
        XCTAssertEqual(DownloadManager.safeName("/etc/passwd"), "passwd")
        XCTAssertEqual(DownloadManager.safeName(".gizli"), "gizli")
        XCTAssertEqual(DownloadManager.safeName(".."), "indirilen")
        XCTAssertEqual(DownloadManager.safeName("  "), "indirilen")
    }

    func testUniqueURLDoesNotOverwrite() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertEqual(DownloadManager.uniqueURL(in: dir, name: "a.mp4").lastPathComponent, "a.mp4")
        try Data().write(to: dir.appendingPathComponent("a.mp4"))
        try Data().write(to: dir.appendingPathComponent("a (2).mp4"))
        XCTAssertEqual(DownloadManager.uniqueURL(in: dir, name: "a.mp4").lastPathComponent, "a (3).mp4")
    }

    func testMediaParsing() {
        let m = MediaDetector.parse([
            ["url": "https://cdn.example.com/v/film.mp4", "kind": "video", "type": "", "w": 1280, "h": 720],
            ["url": "https://cdn.example.com/v/film.mp4", "kind": "video", "type": "video/mp4", "w": 0, "h": 0], // yinelenen
            ["url": "https://cdn.example.com/v/film", "kind": "video", "type": "video/webm; codecs=vp9", "w": 0, "h": 480],
            ["url": "https://cdn.example.com/v/film.ogg", "kind": "video", "type": "video/ogg", "w": 0, "h": 0],
            ["url": "https://example.com/podcast.mp3?x=1", "kind": "link", "type": "", "w": 0, "h": 0],
            ["url": "blob:https://youtube.com/1234", "kind": "video", "type": "", "w": 1920, "h": 1080],
            ["url": "https://example.com/live/master.m3u8", "kind": "video", "type": "application/x-mpegurl", "w": 0, "h": 0],
            ["url": "data:video/mp4;base64,AAAA", "kind": "video", "type": "", "w": 0, "h": 0],
        ])
        XCTAssertEqual(m.map(\.label), ["Video · 1280×720 · MP4", "Video · 480p · WEBM", "Video · OGG", "Ses · MP3", "Video · 1920×1080", "Video · M3U8"])
        XCTAssertEqual(m.map { $0.url != nil }, [true, true, true, true, false, false]) // desteklenmeyenlerde indirme adresi yok
        XCTAssertEqual(m.map { $0.unsupportedReason != nil }, [false, false, false, false, true, true])
    }
}
