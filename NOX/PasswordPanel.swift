import SwiftUI

struct PasswordPanel: View {
    @ObservedObject var passwords: PasswordManager
    @ObservedObject var tab: Tab
    @State private var status = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Parolalar").font(.headline)
            if let host = tab.url?.host, tab.isSecureForPasswords {
                let saved = passwords.credentials(for: host)
                if saved.isEmpty {
                    Text("\(host) için kayıtlı parola yok.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(saved) { c in
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle").foregroundStyle(Color.noxSilver)
                        Text(c.username.isEmpty ? L("(kullanıcı adı yok)") : c.username).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 4)
                        Button("Doldur") { fill(c) }
                        NoxIconButton(symbol: "trash", help: "Parolayı Sil") { passwords.delete(c); status = L("Silindi.") }
                    }
                }
                Divider()
                Button("Sayfadaki Girişi Kaydet") { save(host) }
                Text("Önce sayfadaki forma kullanıcı adınızı ve parolanızı yazın, sonra kaydedin. Parolalar macOS Anahtar Zinciri'nde saklanır.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Parolalar yalnızca güvenli (HTTPS) sayfalarda kaydedilir ve doldurulur.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if !status.isEmpty { Text(status).font(.caption).foregroundStyle(Color.noxNeon).fixedSize(horizontal: false, vertical: true) }
        }
        .controlSize(.small)
        .tint(.noxPurple)
        .padding(14)
        .frame(width: 320)
        .background(Color.noxPanel)
        .preferredColorScheme(.dark)
    }

    private func fill(_ c: Credential) {
        guard let password = passwords.password(for: c) else { status = L("Parola Anahtar Zinciri'nden okunamadı."); return }
        Task {
            status = await tab.fillLogin(username: c.username, password: password)
                ? L("Dolduruldu.") : L("Bu sayfada doldurulacak bir giriş alanı bulunamadı.")
        }
    }

    private func save(_ host: String) {
        Task {
            guard let login = await tab.readLoginForm() else {
                status = L("Bu sayfada parolası yazılmış bir giriş formu bulunamadı.")
                return
            }
            status = passwords.save(host: host, username: login.username, password: login.password)
                ? L("Kaydedildi.") : L("Anahtar Zinciri'ne kaydedilemedi.")
        }
    }
}
