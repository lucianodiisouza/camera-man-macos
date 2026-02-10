import SwiftUI
import AppKit

@main
struct CameraManApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        let _ = (appDelegate.appState = appState)
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 200, minHeight: 200)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 400, height: 400)
        .commands {
            // Settings no menu da app (menu bar) para poder abrir clicando no nome do app
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appState.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        let settingsWidth = max(400, (NSScreen.main?.visibleFrame.width ?? 1280) / 3)
        Window("Settings", id: "settings") {
            SettingsPanel()
                .environmentObject(appState)
                .onDisappear { appState.showSettings = false }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: settingsWidth, height: 500)
        .defaultPosition(.center)
    }
}
