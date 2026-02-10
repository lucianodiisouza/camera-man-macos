import AppKit
import SwiftUI

/// Handles shortcut keys in the responder chain so the system does not play the "unhandled key" beep.
final class ShortcutHandlingNSView: NSView {
    weak var appState: AppState?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard let appState = appState else { super.keyDown(with: event); return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasModifiers = !flags.isEmpty && flags != .capsLock
        if hasModifiers {
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case 123: // Left arrow
            appState.adjustOffset(dx: -1, dy: 0)
        case 124: // Right arrow
            appState.adjustOffset(dx: 1, dy: 0)
        case 125: // Down arrow
            appState.adjustOffset(dx: 0, dy: -1)
        case 126: // Up arrow
            appState.adjustOffset(dx: 0, dy: 1)
        case 24: // + or =
            appState.zoomIn()
        case 27: // -
            appState.zoomOut()
        case 15: // r
            appState.resetZoom()
        case 44: // /
            appState.flipHorizontal.toggle()
            appState.saveToUserDefaults()
        case 9: // v
            appState.flipVertical.toggle()
            appState.saveToUserDefaults()
        case 31: // o
            appState.cycleShape()
        case 51: // Backspace
            cycleToNextCamera(appState)
        case 49: // Space
            toggleWindowSize(appState)
        default:
            super.keyDown(with: event)
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
        guard let window = window ?? NSApplication.shared.windows.first(where: { $0.isVisible }) else { return }
        setWindowSize(preservingCenter: window, width: appState.windowSizePreset.width, height: appState.windowSizePreset.height)
    }

    private func setWindowSize(preservingCenter window: NSWindow, width: CGFloat, height: CGFloat) {
        let frame = window.frame
        // Preserve top-left corner (macOS: origin is bottom-left, so top = origin.y + height)
        let newSize = CGSize(width: width, height: height)
        let newOrigin = CGPoint(
            x: frame.minX,
            y: (frame.origin.y + frame.height) - newSize.height
        )
        window.setFrame(CGRect(origin: newOrigin, size: newSize), display: true)
    }
}

struct ShortcutHandlingViewRepresentable: NSViewRepresentable {
    weak var appState: AppState?

    func makeNSView(context: Context) -> ShortcutHandlingNSView {
        let v = ShortcutHandlingNSView()
        v.appState = appState
        return v
    }

    func updateNSView(_ nsView: ShortcutHandlingNSView, context: Context) {
        nsView.appState = appState
    }
}
