import Darwin
import Foundation

/// Bir sürecin çekirdekten okunan kümülatif kaynak sayaçları.
struct ProcSample {
    let cpuNs: UInt64   // kullanıcı + sistem CPU süresi
    let wakeups: UInt64 // işlemciyi boştan uyandırma sayısı (boşta pil tüketiminin ana göstergesi)
    let memory: UInt64  // fiziksel bellek ayak izi (Etkinlik Monitörü'ndeki "Bellek")

    init?(pid: pid_t) {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
        }
        guard result == 0 else { return nil }
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb) // Apple Silicon'da süreler mach birimindedir; Intel'de 1/1
        cpuNs = (info.ri_user_time + info.ri_system_time) * UInt64(tb.numer) / UInt64(tb.denom)
        wakeups = info.ri_pkg_idle_wkups + info.ri_interrupt_wkups
        memory = info.ri_phys_footprint
    }
}

struct PerfRow: Identifiable {
    let id: String
    let title: String
    var cpu: Double?     // % (bir çekirdek = 100)
    var memory: UInt64?  // bayt
    var wakeups: Double? // saniyede
    var tab: Tab?
}

/// Yalnızca performans paneli açıkken örnekleme yapar; panel kapalıyken hiçbir maliyeti yoktur.
@MainActor
final class PerformanceMonitor: ObservableObject {
    @Published private(set) var rows: [PerfRow] = []
    @Published private(set) var total = PerfRow(id: "total", title: "Toplam")
    private var last: [pid_t: (sample: ProcSample, time: TimeInterval)] = [:]

    func refresh(tabs: [Tab]) {
        let now = ProcessInfo.processInfo.systemUptime
        var next: [pid_t: (sample: ProcSample, time: TimeInterval)] = [:]
        var sum = PerfRow(id: "total", title: "Toplam", cpu: 0, memory: 0, wakeups: 0)

        func row(id: String, title: String, pid: pid_t?, tab: Tab?) -> PerfRow {
            var r = PerfRow(id: id, title: title, tab: tab)
            guard let pid, let s = ProcSample(pid: pid) else { return r }
            r.memory = s.memory
            if let prev = last[pid], now > prev.time {
                let dt = now - prev.time
                r.cpu = Double(s.cpuNs &- prev.sample.cpuNs) / 1e9 / dt * 100
                r.wakeups = Double(s.wakeups &- prev.sample.wakeups) / dt
            }
            if next[pid] == nil { // aynı süreci paylaşan sekmeler toplamda bir kez sayılır
                sum.memory! += s.memory
                sum.cpu! += r.cpu ?? 0
                sum.wakeups! += r.wakeups ?? 0
                next[pid] = (s, now)
            }
            return r
        }

        let app = row(id: "app", title: "NOX (arayüz)", pid: getpid(), tab: nil)
        let tabRows = tabs.map { row(id: $0.id.uuidString, title: $0.title, pid: $0.processID, tab: $0) }
            .sorted { ($0.cpu ?? -1, $0.memory ?? 0) > ($1.cpu ?? -1, $1.memory ?? 0) }
        if last.isEmpty { sum.cpu = nil; sum.wakeups = nil } // ilk örnekte hız hesaplanamaz
        last = next
        rows = [app] + tabRows
        total = sum
    }
}
