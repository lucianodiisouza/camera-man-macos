import AppKit
import SwiftUI

/// Handles shortcut keys in the responder chain so the system does not play the "unhandled key" beep.
final class ShortcutHandlingNSView: NSView {
    weak var appState: AppState?
    private var windowObserver: NSObjectProtocol?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let w = window {
            // Defer so we run after SwiftUI's layout and win first responder
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.window == w else { return }
                w.makeFirstResponder(self)
            }
            setupWindowObserver(window: w)
        } else {
            windowObserver = nil
        }
    }

    private func setupWindowObserver(window: NSWindow) {
        windowObserver = nil
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, let w = self.window, w.isKeyWindow else { return }
            w.makeFirstResponder(self)
        }
    }

    deinit {
        if let o = windowObserver {
            NotificationCenter.default.removeObserver(o)
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
            toggleSpaceSlotSize(appState)
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

    private func toggleSpaceSlotSize(_ appState: AppState) {
        let newPreset = appState.spaceToggleTargetPreset()
        appState.setWindowSizePreset(newPreset)
        guard let window = window ?? NSApplication.shared.windows.first(where: { $0.isVisible }),
              let screen = window.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let newSize = newPreset.size(visibleFrame: visibleFrame)
        let origin = appState.originToApply(for: newPreset, visibleFrame: visibleFrame, windowSize: newSize)
        window.setFrame(CGRect(origin: origin, size: newSize), display: true)
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
