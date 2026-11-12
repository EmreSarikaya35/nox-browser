import SwiftUI

struct PerformancePanel: View {
    @ObservedObject var tm: TabManager
    @StateObject private var monitor = PerformanceMonitor()
    @AppStorage("batterySaver") private var batterySaver = false
    @AppStorage("blockAutoplay") private var blockAutoplay = false
    @AppStorage("autoBatterySaver") private var autoBatterySaver = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Pil tasarrufu modu", isOn: $batterySaver).font(.headline)
            Text("Arka plan sekmeleri 30 dk yerine 5 dk sonra uyutulur; arayüz animasyonları ve cam efekti kapatılır.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Toggle("Pildeyken pil tasarrufunu otomatik aç", isOn: $autoBatterySaver)
            Text("Şarjdan çıkınca açılır, şarja takılınca kapanır.").font(.caption).foregroundStyle(.secondary)
            Toggle("Videoların otomatik oynatılmasını engelle", isOn: $blockAutoplay)
            Text("Yeni açılan veya uyandırılan sekmelerde geçerli olur.").font(.caption).foregroundStyle(.secondary)
            Divider()
            Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 5) {
                GridRow {
                    Text("Süreç").gridColumnAlignment(.leading)
                    Text("CPU"); Text("Bellek"); Text("Uyanma/sn"); Text("")
                }
                .font(.caption).foregroundStyle(.secondary)
                ForEach(monitor.rows) { line($0) }
                Divider()
                line(monitor.total).fontWeight(.semibold)
            }
            .font(.system(size: 12)).monospacedDigit()
            Text("Yalnızca bu panel açıkken, 2 saniyede bir ölçülür. WebKit'in paylaşılan ağ ve GPU süreçleri dahil değildir.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(.noxPurple)
        .padding(14)
        .frame(width: 420)
        .background(Color.noxPanel)
        .preferredColorScheme(.dark)
        .onChange(of: autoBatterySaver) { PowerMonitor.shared.update() }
        .task { // panel kapanınca görev iptal olur, ölçüm durur
            while !Task.isCancelled {
                monitor.refresh(tabs: tm.tabs)
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func line(_ r: PerfRow) -> some View {
        GridRow {
            Text(r.title).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            if r.tab?.isSleeping == true {
                Text("uyuyor").foregroundStyle(.secondary).gridCellColumns(3)
                Text("")
            } else {
                Text(r.cpu.map { String(format: "%.1f%%", $0) } ?? "—")
                    .foregroundStyle((r.cpu ?? 0) > 20 ? Color.orange : Color.white)
                Text(r.memory.map { "\($0 / 1_048_576) MB" } ?? "—")
                Text(r.wakeups.map { String(format: "%.0f", $0) } ?? "—")
                if let tab = r.tab, tab.webView != nil, tab.id != tm.selectedID {
                    NoxIconButton(symbol: "moon.zzz", help: "Bu sekmeyi şimdi uyut") { tab.sleep(); monitor.refresh(tabs: tm.tabs) }
                } else { Text("") }
            }
        }
    }
}
