import SwiftUI

@main
struct CameraManApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        let _ = (appDelegate.appState = appState)
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 300, minHeight: 300)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 300, height: 300)
        .commands {
            // Settings no menu da app (menu bar) para poder abrir clicando no nome do app
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appState.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Window("Settings", id: "settings") {
            SettingsPanel()
                .environmentObject(appState)
                .onDisappear { appState.showSettings = false }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 500)
        .defaultPosition(.center)
    }
}
