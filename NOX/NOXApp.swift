import SwiftUI

@main
struct NOXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() { Language.apply() } // menüler ve pencereler oluşmadan önce

    var body: some Scene {
        // Her pencerenin kendi sekmeleri vardır; geçmiş, yer imleri vb. Services üzerinden ortaktır.
        WindowGroup {
            WindowRoot()
        }
        .windowStyle(.hiddenTitleBar)
        .commands { NoxCommands() }

        Settings { SettingsView() }
    }
}

private struct WindowRoot: View {
    @StateObject private var tm = TabManager()

    var body: some View {
        BrowserView()
            .environmentObject(tm)
            .focusedSceneObject(tm) // menü komutları öndeki pencerenin sekmelerine uygulanır
            .frame(minWidth: 760, minHeight: 480)
    }
}

private struct NoxCommands: Commands {
    @FocusedObject private var tm: TabManager?
    @AppStorage("showSidebar") private var showSidebar = false
    @AppStorage("showBookmarksBar") private var showBookmarksBar = true
    @AppStorage("verticalTabs") private var verticalTabs = false
    @AppStorage("darkWeb") private var darkWeb = false

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Güncellemeleri Denetle…") { Updater.shared.checkManually() }
        }
        // Sistemin "Yeni Pencere" (⌘N) komutu korunur; sekme komutları onun altına eklenir.
        CommandGroup(after: .newItem) {
            Group {
                Button("Yeni Sekme") { tm?.newTab() }.keyboardShortcut("t")
                Button("Yeni Gizli Sekme") { tm?.newTab(isPrivate: true) }.keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Sekmeyi Kapat") { if let id = tm?.selectedID { tm?.close(id) } }.keyboardShortcut("w")
                Button("Kapatılan Sekmeyi Yeniden Aç") { tm?.reopenClosed() }.keyboardShortcut("t", modifiers: [.command, .shift])
                Button("Adres Çubuğuna Git") { tm?.focusAddress += 1 }.keyboardShortcut("l")
                Button("Komut Paleti") { tm?.paletteVisible.toggle() }.keyboardShortcut("k")
            }
            .disabled(tm == nil)
        }
        CommandGroup(before: .toolbar) {
            Group {
                Button("Yenile") { tm?.selected?.reload() }.keyboardShortcut("r")
                Button("Sayfada Bul") { tm?.findVisible = true }.keyboardShortcut("f")
                Button("Yakınlaştır") { tm?.selected?.zoom(1.1) }.keyboardShortcut("=")
                Button("Uzaklaştır") { tm?.selected?.zoom(1 / 1.1) }.keyboardShortcut("-")
                Button("Gerçek Boyut") { tm?.selected?.zoom(nil) }.keyboardShortcut("0")
                Divider()
                Button("Bölünmüş Görünüm") { tm?.toggleSplit() }.keyboardShortcut("s", modifiers: [.command, .control])
                Button("Resim İçinde Resim") { tm?.selected?.togglePiP() }.keyboardShortcut("p", modifiers: [.command, .option])
            }
            .disabled(tm == nil)
            Divider()
            Toggle("Dikey Sekmeler", isOn: $verticalTabs)
            Toggle("Web Sayfalarını Karart", isOn: $darkWeb).keyboardShortcut("k", modifiers: [.command, .shift])
            Toggle("Kenar Çubuğu", isOn: $showSidebar).keyboardShortcut("l", modifiers: [.command, .shift])
            Toggle("Yer İmleri Çubuğu", isOn: $showBookmarksBar).keyboardShortcut("b", modifiers: [.command, .shift])
            Divider()
        }
        CommandMenu("Gezinme") {
            Group {
                Button("Geri") { tm?.selected?.webView?.goBack() }.keyboardShortcut("[")
                Button("İleri") { tm?.selected?.webView?.goForward() }.keyboardShortcut("]")
                Button("Ana Sayfa") { tm?.goHome() }.keyboardShortcut("h", modifiers: [.command, .shift])
                Divider()
                Button("Spirit Quest'i Oyna") { tm?.newTab(url: GameSchemeHandler.gameURL) }.keyboardShortcut("g", modifiers: [.command, .shift])
                Button("İndirmeler") { tm?.downloadsVisible.toggle() }.keyboardShortcut("l", modifiers: [.command, .option])
                Button("Yer İmi Ekle/Kaldır") { tm?.toggleBookmark() }.keyboardShortcut("d")
                Button("Sekmeyi Sabitle/Kaldır") { if let id = tm?.selectedID { tm?.togglePin(id) } }
                Divider()
                Button("Sonraki Sekme") { tm?.cycle(1) }.keyboardShortcut(.tab, modifiers: .control)
                Button("Önceki Sekme") { tm?.cycle(-1) }.keyboardShortcut(.tab, modifiers: [.control, .shift])
            }
            .disabled(tm == nil)
        }
    }
}
