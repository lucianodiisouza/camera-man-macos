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
                    appDelegate.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
