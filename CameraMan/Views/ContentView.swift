import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.openWindow) private var openWindow
    @StateObject private var keyboardMonitor = KeyboardShortcutMonitor()

    /// Padding so border and/or shadow fit inside the window and shadow blur is not clipped.
    private var borderPadding: CGFloat {
        var padding: CGFloat = 0
        if appState.showBorder, appState.borderWidth > 0 { padding += appState.borderWidth }
        if appState.showShadow, appState.borderShadowRadius > 0 { padding += 2 * appState.borderShadowRadius }
        return padding
    }

    /// Inset so content is not clipped by the window's rounded corners (macOS), keeping square shape with sharp corners.
    private let windowCornerInset: CGFloat = 12

    var body: some View {
        let _ = (NSApplication.shared.delegate as? AppDelegate)?.appState = appState
        return ZStack(alignment: .topTrailing) {
            CameraView()
                .ignoresSafeArea()
            // Invisible view that becomes first responder and handles shortcuts (avoids system beep)
            ShortcutHandlingViewRepresentable(appState: appState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

            if let toast = appState.toastMessage {
                Text(toast)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(12)
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(1)
            }
        }
        .padding(borderPadding + windowCornerInset)
        .onAppear {
            (NSApplication.shared.delegate as? AppDelegate)?.appState = appState
            keyboardMonitor.install(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            appState.showSettings = true
        }
        .onChange(of: appState.showSettings) { _, newValue in
            if newValue { openWindow(id: "settings") }
        }
    }
}
