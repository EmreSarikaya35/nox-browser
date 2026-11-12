import SwiftUI

struct AdBlockPanel: View {
    @ObservedObject var engine: AdBlockEngine
    @ObservedObject var tab: Tab

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Reklam ve takipçi engelleme", isOn: Binding(get: { engine.enabled }, set: { engine.enabled = $0; tab.reload() }))
                .font(.headline)
            if let host = tab.url?.host {
                Toggle("\(host) üzerinde engelle", isOn: Binding(get: { !engine.isWhitelisted(host) },
                                                                 set: { _ in engine.toggleSite(host); tab.reload() }))
                    .disabled(!engine.enabled)
            }
            HStack(spacing: 24) {
                stat("Bu sayfada engellenen", tab.blockedCount)
                stat("Toplam", engine.totalBlocked)
            }
            Divider()
            Text("Filtre listeleri").font(.caption).foregroundStyle(.secondary)
            ForEach(AdBlockEngine.lists) { list in
                Toggle(isOn: Binding(get: { engine.enabledLists.contains(list.id) }, set: { engine.setList(list.id, on: $0) })) {
                    HStack {
                        Text(list.name)
                        Spacer()
                        if let n = engine.ruleCounts[list.id] { Text("\(n) kural").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .disabled(engine.busy)
            }
            HStack {
                Button("Listeleri Güncelle") { Task { await engine.update() } }.disabled(engine.busy)
                Spacer()
                if let d = engine.lastUpdate {
                    Text("Son: \(d.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                }
            }
            if !engine.status.isEmpty {
                Text(engine.status).font(.caption).foregroundStyle(Color.noxNeon).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Text("Özel filtreler (Adblock Plus sözdizimi, satır başına bir kural)").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $engine.customFilters)
                .font(.system(size: 11, design: .monospaced))
                .frame(height: 70)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.noxSilver.opacity(0.25), lineWidth: 1))
                .accessibilityLabel("Özel filtreler")
            Button("Özel Filtreleri Uygula") { engine.applyCustomFilters() }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(.noxPurple)
        .padding(14)
        .frame(width: 360)
        .background(Color.noxPanel) // cam efektli popover üzerinde metin okunmuyor
        .preferredColorScheme(.dark)
    }

    private func stat(_ label: LocalizedStringKey, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)").font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundStyle(Color.noxNeon)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
