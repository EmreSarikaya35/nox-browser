import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("Genel", systemImage: "gearshape") }
            PrivacySettings(privacy: Services.privacy).tabItem { Label("Gizlilik", systemImage: "hand.raised") }
            PasswordSettings(passwords: Services.passwords).tabItem { Label("Parolalar", systemImage: "key") }
        }
        .frame(width: 560, height: 560)
    }
}

private struct GeneralSettings: View {
    @AppStorage("searchEngine") private var engine = SearchEngine.duckduckgo.rawValue
    @AppStorage("homepage") private var homepage = ""
    @AppStorage("restoreSession") private var restoreSession = true
    @AppStorage("startBackground") private var startBackground = ""
    @AppStorage("verticalTabs") private var verticalTabs = false
    @AppStorage("darkWeb") private var darkWeb = false
    @AppStorage("autoUpdateCheck") private var autoUpdateCheck = true
    @State private var importResult = ""
    @AppStorage("appLanguage") private var appLanguage = "system"
    @State private var languageChanged = false
    @State private var isDefaultBrowser = DefaultBrowser.isDefault
    @State private var newWorkspace = ""
    @ObservedObject private var workspaces = Services.workspaces

    var body: some View {
        Form {
            // "Sistem dili": macOS dili Türkçeyse Türkçe, başka herhangi bir dilse İngilizce.
            Picker("Dil / Language", selection: $appLanguage) {
                Text("Sistem dili").tag("system")
                Text(verbatim: "Türkçe").tag("tr")
                Text(verbatim: "English").tag("en")
            }
            .onChange(of: appLanguage) {
                Language.apply() // yeni dil bir sonraki açılışta geçerli olur
                languageChanged = true
            }
            if languageChanged {
                LabeledContent("") {
                    HStack {
                        Text("Dil değişikliği yeniden başlatınca geçerli olur.").font(.caption).foregroundStyle(.secondary)
                        Button("Yeniden Başlat") { Updater.shared.relaunch() }.controlSize(.small)
                    }
                }
            }
            LabeledContent("Varsayılan tarayıcı") {
                if isDefaultBrowser { Text("NOX varsayılan tarayıcınız.").foregroundStyle(.secondary) }
                else { Button("Varsayılan Yap…") { DefaultBrowser.makeDefault { isDefaultBrowser = DefaultBrowser.isDefault } } }
            }
            Picker("Arama motoru", selection: $engine) {
                ForEach(SearchEngine.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            TextField("Ana sayfa", text: $homepage, prompt: Text("Boş bırakılırsa başlangıç sayfası"))
            Toggle("Açılışta önceki oturumu geri yükle", isOn: $restoreSession)
            Toggle("Dikey sekmeler (sekmeleri solda listele)", isOn: $verticalTabs)
            Toggle("Web sayfalarını karart (açık zeminli siteleri koyulaştır)", isOn: $darkWeb)
            Toggle("Güncellemeleri otomatik denetle ve kur", isOn: $autoUpdateCheck)
            LabeledContent("Çalışma alanları") {
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(workspaces.names.dropFirst(), id: \.self) { name in
                        HStack {
                            Text(name)
                            Button("Sil") { deleteWorkspace(name) }.controlSize(.small)
                        }
                    }
                    HStack {
                        TextField("Yeni alan adı (ör. İş)", text: $newWorkspace).frame(width: 170).onSubmit(addWorkspace)
                        Button("Ekle", action: addWorkspace).disabled(newWorkspace.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Text("İkinci bir alan eklenince sekme çubuğunda alan değiştirici görünür.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            LabeledContent("İçe aktar") {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Button("Yer İmleri (HTML)…") { importBookmarks() }
                        Button("Parolalar (CSV)…") { importPasswords() }
                    }
                    Text(importResult.isEmpty ? L("Safari, Chrome veya Firefox'tan dışa aktarılan dosyayı seçin.") : importResult)
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            LabeledContent("Başlangıç sayfası arka planı") {
                HStack {
                    Text(startBackground.isEmpty ? L("Yok") : (startBackground as NSString).lastPathComponent)
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

    private func addWorkspace() {
        if workspaces.add(newWorkspace) != nil { newWorkspace = "" }
    }

    private func deleteWorkspace(_ name: String) {
        let alert = NSAlert()
        alert.messageText = L("“\(name)” alanı silinsin mi?")
        alert.informativeText = L("Bu alandaki bütün sekmeler kapatılır.")
        alert.addButton(withTitle: L("Vazgeç"))
        alert.addButton(withTitle: L("Sil"))
        if alert.runModal() == .alertSecondButtonReturn { workspaces.remove(name) }
    }

    private func pick(_ ext: String) -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [ext == "csv" ? .commaSeparatedText : .html]
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func importBookmarks() {
        guard let html = pick("html") else { return }
        let found = Importer.bookmarks(fromHTML: html)
        importResult = found.isEmpty ? L("Dosyada yer imi bulunamadı.") : L("\(Services.bookmarks.addMany(found)) yer imi eklendi (\(found.count) bulundu).")
    }

    private func importPasswords() {
        guard let csv = pick("csv") else { return }
        let found = Importer.passwords(fromCSV: csv)
        let saved = found.filter { Services.passwords.save(host: $0.host, username: $0.username, password: $0.password) }.count
        importResult = found.isEmpty ? L("Dosyada parola bulunamadı (url, username, password sütunları gerekli).")
            : L("\(saved) parola Anahtar Zinciri'ne kaydedildi. CSV dosyası parolaları açık metin içerir; işiniz bitince silin.")
    }
}

private struct PrivacySettings: View {
    @ObservedObject var privacy: PrivacyManager
    @AppStorage("clearOnQuit") private var clearOnQuit = false
    @State private var cleared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Kapatırken geçmişi, çerezleri ve site verilerini temizle", isOn: $clearOnQuit)
            Text("Açıkken oturum (açık sekmeler) de geri yüklenmez.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Şimdi Temizle") { TabManager.clearBrowsingData(); cleared = true }
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
        [("camera", L("Kamera")), ("microphone", L("Mikrofon"))]
            .compactMap { key, name in p[key].map { "\(name): \($0 ? L("izinli") : L("engelli"))" } }
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
                            Text(c.username.isEmpty ? L("(kullanıcı adı yok)") : c.username).font(.caption).foregroundStyle(.secondary)
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
