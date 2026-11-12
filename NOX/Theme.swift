import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    static let noxBlack = Color(hex: 0x09090D)
    static let noxPanel = Color(hex: 0x17171F)
    static let noxGray = Color(hex: 0x3C3C42) // sekme çubuğu
    static let noxSilver = Color(hex: 0xC0C0CA)
    static let noxPurple = Color(hex: 0x7546C8)
    static let noxNeon = Color(hex: 0xA77BFF)
}

/// Arayüz metni. Türkçe kaynak metin anahtardır; İngilizce karşılığı en.lproj/Localizable.strings içindedir.
/// SwiftUI'nin kendiliğinden çevirmediği yerlerde (uyarı pencereleri, durum mesajları, String değişkenleri) kullanılır.
func L(_ key: String.LocalizationValue) -> String { String(localized: key) }

/// Arayüz dili. Ayar "system" ise macOS'un birinci dili Türkçeyse Türkçe, başka herhangi bir dilse İngilizce.
enum Language {
    static func code(setting: String, system: [String]) -> String {
        if setting == "tr" || setting == "en" { return setting }
        return system.first?.lowercased().hasPrefix("tr") == true ? "tr" : "en"
    }

    /// Uygulamanın dil tercihini yazar. Açılışta, hiçbir metin yüklenmeden önce çağrılır; ayar sonradan
    /// değişirse yeni dil bir sonraki açılışta geçerli olur.
    static func apply() {
        let d = UserDefaults.standard
        let system = d.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String] ?? []
        d.set([code(setting: d.string(forKey: "appLanguage") ?? "system", system: system)], forKey: "AppleLanguages")
    }
}

struct NoxIconButton: View {
    let symbol: String
    let help: LocalizedStringKey
    var disabled = false
    var tint = Color.noxSilver
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hover ? Color.noxNeon : tint)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.noxPurple.opacity(hover ? 0.25 : 0)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .onHover { hover = $0 && !disabled }
        .help(help)
        .accessibilityLabel(help)
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}
