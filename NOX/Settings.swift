import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var tm: TabManager

    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("Genel", systemImage: "gearshape") }
            PrivacySettings(tm: tm, privacy: tm.privacy).tabItem { Label("Gizlilik", systemImage: "hand.raised") }
            PasswordSettings(passwords: tm.passwords).tabItem { Label("Parolalar", systemImage: "key") }
        }
        .frame(width: 520, height: 360)
    }
}

private struct GeneralSettings: View {
    @AppStorage("searchEngine") private var engine = SearchEngine.duckduckgo.rawValue
    @AppStorage("homepage") private var homepage = ""
    @AppStorage("restoreSession") private var restoreSession = true
    @AppStorage("startBackground") private var startBackground = ""

    var body: some View {
        Form {
            Picker("Arama motoru", selection: $engine) {
                ForEach(SearchEngine.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            TextField("Ana sayfa", text: $homepage, prompt: Text("Boş bırakılırsa başlangıç sayfası"))
            Toggle("Açılışta önceki oturumu geri yükle", isOn: $restoreSession)
            LabeledContent("Başlangıç sayfası arka planı") {
                HStack {
                    Text(startBackground.isEmpty ? "Yok" : (startBackground as NSString).lastPathComponent)
                        .lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                    Button("Seç…") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.image]
                        if panel.runModal() == .OK, let url = panel.url { startBackground = url.path }
                    }
                    Button("Kaldır") { startBackground = "" }.disabled(startBackground.isEmpty)
                }
            }
        }
        .padding(20)
    }
}

private struct PrivacySettings: View {
    let tm: TabManager
    @ObservedObject var privacy: PrivacyManager
    @AppStorage("clearOnQuit") private var clearOnQuit = false
    @State private var cleared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Kapatırken geçmişi, çerezleri ve site verilerini temizle", isOn: $clearOnQuit)
            Text("Açıkken oturum (açık sekmeler) de geri yüklenmez.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Şimdi Temizle") { tm.clearBrowsingData(); cleared = true }
                if cleared { Text("Temizlendi").foregroundStyle(.secondary) }
            }
            Divider()
            Text("Site izinleri (kamera ve mikrofon)").font(.headline)
            if privacy.permissions.isEmpty {
                Text("Henüz karar verilmiş site yok. Bir site kamera veya mikrofon istediğinde sorulur.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                List(privacy.permissions.keys.sorted(), id: \.self) { host in
                    HStack {
                        Text(host).lineLimit(1)
                        Spacer()
                        Text(describe(privacy.permissions[host] ?? [:])).font(.caption).foregroundStyle(.secondary)
                        Button("Sıfırla") { privacy.reset(host) }.controlSize(.small)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func describe(_ p: [String: Bool]) -> String {
        [("camera", "Kamera"), ("microphone", "Mikrofon")]
            .compactMap { key, name in p[key].map { "\(name): \($0 ? "izinli" : "engelli")" } }
            .joined(separator: " · ")
    }
}

private struct PasswordSettings: View {
    @ObservedObject var passwords: PasswordManager
    @State private var copied: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Parolalar macOS Anahtar Zinciri'nde saklanır. Kaydetmek ve doldurmak için araç çubuğundaki anahtar düğmesini kullanın.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if passwords.credentials.isEmpty {
                Text("Kayıtlı parola yok.").foregroundStyle(.secondary)
            } else {
                List(passwords.credentials) { c in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(c.host).lineLimit(1)
                            Text(c.username.isEmpty ? "(kullanıcı adı yok)" : c.username).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if copied == c.id { Text("Kopyalandı").font(.caption).foregroundStyle(.secondary) }
                        Button("Parolayı Kopyala") {
                            guard let p = passwords.password(for: c) else { return }
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(p, forType: .string)
                            copied = c.id
                        }
                        Button("Sil", role: .destructive) { passwords.delete(c) }
                    }
                    .controlSize(.small)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .onAppear { passwords.reload() }
    }
}
