import AppKit
import SwiftUI

final class KeyboardShortcutMonitor: ObservableObject {
    private var localMonitor: Any?
    private weak var appState: AppState?

    /// Shortcuts are handled by ShortcutHandlingNSView in the responder chain to avoid the system beep.
    func install(appState: AppState) {
        self.appState = appState
        // No NSEvent monitor — handling in keyDown avoids the "unhandled key" beep
    }

    func uninstall() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
        localMonitor = nil
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard let appState = appState else { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasModifiers = !flags.isEmpty && flags != .capsLock

        // Only handle when no modifiers (except for Cmd+, which is in menu)
        if hasModifiers { return event }

        switch event.keyCode {
        case 123: // Left arrow
            appState.adjustOffset(dx: -1, dy: 0)
            return nil
        case 124: // Right arrow
            appState.adjustOffset(dx: 1, dy: 0)
            return nil
        case 125: // Down arrow
            appState.adjustOffset(dx: 0, dy: -1)
            return nil
        case 126: // Up arrow
            appState.adjustOffset(dx: 0, dy: 1)
            return nil
        case 24: // + or =
            appState.zoomIn()
            return nil
        case 27: // -
            appState.zoomOut()
            return nil
        case 15: // r
            appState.resetZoom()
            return nil
        case 44: // /
            appState.flipHorizontal.toggle()
            appState.saveToUserDefaults()
            return nil
        case 9: // v
            appState.flipVertical.toggle()
            appState.saveToUserDefaults()
            return nil
        case 31: // o
            appState.cycleShape()
            return nil
        case 51: // Backspace
            cycleToNextCamera(appState)
            return nil
        case 49: // Space
            toggleWindowSize(appState)
            return nil
        default:
            return event
        }
    }

    private func cycleToNextCamera(_ appState: AppState) {
        let devices = appState.videoDevices
        guard !devices.isEmpty else { return }
        let idx = devices.firstIndex { $0.id == appState.selectedDeviceId } ?? -1
        let nextIdx = (idx + 1) % devices.count
        appState.selectedDeviceId = devices[nextIdx].id
        appState.saveToUserDefaults()
        appState.showToast(devices[nextIdx].name)
    }

    private func toggleWindowSize(_ appState: AppState) {
        appState.windowSizePreset = appState.windowSizePreset == .small ? .large : .small
        appState.saveToUserDefaults()
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible }) else { return }
        setWindowSize(preservingCenter: window, width: appState.windowSizePreset.width, height: appState.windowSizePreset.height)
    }

    private func setWindowSize(preservingCenter window: NSWindow, width: CGFloat, height: CGFloat) {
        let frame = window.frame
        let centerX = frame.midX
        let centerY = frame.midY
        let newSize = CGSize(width: width, height: height)
        let newOrigin = CGPoint(x: centerX - newSize.width / 2, y: centerY - newSize.height / 2)
        window.setFrame(CGRect(origin: newOrigin, size: newSize), display: true)
    }
}
