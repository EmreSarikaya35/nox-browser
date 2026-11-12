import SwiftUI

@main
struct NOXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var tm = TabManager()
    @AppStorage("showSidebar") private var showSidebar = false
    @AppStorage("showBookmarksBar") private var showBookmarksBar = true

    var body: some Scene {
        // shortcut: tek pencere (Window); çoklu pencere gerekirse pencere başına TabManager ile WindowGroup'a geç.
        Window("NOX Browser", id: "main") {
            BrowserView()
                .environmentObject(tm)
                .frame(minWidth: 760, minHeight: 480)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Yeni Sekme") { tm.newTab() }.keyboardShortcut("t")
                Button("Yeni Gizli Sekme") { tm.newTab(isPrivate: true) }.keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Sekmeyi Kapat") { if let id = tm.selectedID { tm.close(id) } }.keyboardShortcut("w")
                Button("Kapatılan Sekmeyi Yeniden Aç") { tm.reopenClosed() }.keyboardShortcut("t", modifiers: [.command, .shift])
                Button("Adres Çubuğuna Git") { tm.focusAddress += 1 }.keyboardShortcut("l")
            }
            CommandGroup(before: .toolbar) {
                Button("Yenile") { tm.selected?.reload() }.keyboardShortcut("r")
                Button("Sayfada Bul") { tm.findVisible = true }.keyboardShortcut("f")
                Button("Yakınlaştır") { tm.selected?.zoom(1.1) }.keyboardShortcut("=")
                Button("Uzaklaştır") { tm.selected?.zoom(1 / 1.1) }.keyboardShortcut("-")
                Button("Gerçek Boyut") { tm.selected?.zoom(nil) }.keyboardShortcut("0")
                Divider()
                Toggle("Kenar Çubuğu", isOn: $showSidebar).keyboardShortcut("l", modifiers: [.command, .shift])
                Toggle("Yer İmleri Çubuğu", isOn: $showBookmarksBar).keyboardShortcut("b", modifiers: [.command, .shift])
                Divider()
            }
            CommandMenu("Gezinme") {
                Button("Geri") { tm.selected?.webView?.goBack() }.keyboardShortcut("[")
                Button("İleri") { tm.selected?.webView?.goForward() }.keyboardShortcut("]")
                Button("Ana Sayfa") { tm.goHome() }.keyboardShortcut("h", modifiers: [.command, .shift])
                Divider()
                Button("Spirit Quest'i Oyna") { tm.newTab(url: GameSchemeHandler.gameURL) }.keyboardShortcut("g", modifiers: [.command, .shift])
                Button("İndirmeler") { tm.downloadsVisible.toggle() }.keyboardShortcut("l", modifiers: [.command, .option])
                Button("Yer İmi Ekle/Kaldır") { tm.toggleBookmark() }.keyboardShortcut("d")
                Divider()
                Button("Sonraki Sekme") { tm.cycle(1) }.keyboardShortcut(.tab, modifiers: .control)
                Button("Önceki Sekme") { tm.cycle(-1) }.keyboardShortcut(.tab, modifiers: [.control, .shift])
            }
        }

        Settings { SettingsView().environmentObject(tm) }
    }
}
