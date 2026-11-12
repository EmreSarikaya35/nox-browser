import XCTest
@testable import NOX

final class PerformanceMonitorTests: XCTestCase {
    func testSamplesOwnProcess() throws {
        let a = try XCTUnwrap(ProcSample(pid: getpid()))
        XCTAssertGreaterThan(a.memory, 1_000_000)
        var x = 0.0
        for i in 0..<2_000_000 { x += sin(Double(i)) } // CPU harca
        XCTAssertNotEqual(x, .infinity)
        let b = try XCTUnwrap(ProcSample(pid: getpid()))
        XCTAssertGreaterThan(b.cpuNs, a.cpuNs)
        XCTAssertNil(ProcSample(pid: -1))
    }
}
