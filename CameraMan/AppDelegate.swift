import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted when the status bar menu is about to open; observers can refresh device list.
    static let statusMenuWillOpen = Notification.Name("statusMenuWillOpen")
    /// Posted when device list was updated so the status menu can rebuild (e.g. after refresh).
    static let statusMenuShouldRebuild = Notification.Name("statusMenuShouldRebuild")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    weak var appState: AppState?
    private var settingsController: SettingsWindowController?
    private let hotKeys = GlobalHotKeys()
    private weak var knownCameraWindow: NSWindow?

    /// The floating camera window. Remembered once styled, because a hidden window no longer shows up as visible;
    /// before that, the visible app window that is not the settings window (status bar windows are visible too, but
    /// can never become main).
    var cameraWindow: NSWindow? {
        knownCameraWindow
            ?? NSApp.windows.first { $0.isVisible && $0.canBecomeMain && $0 !== settingsController?.window }
    }

    var isCameraShown: Bool { cameraWindow?.isVisible ?? false }

    /// Hides the camera (and stops it, so the camera light goes out) or brings it back, without taking focus from
    /// the app being recorded.
    func toggleCamera() {
        guard let window = cameraWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
            appState?.isWindowVisible = false
        } else {
            appState?.isWindowVisible = true
            window.orderFrontRegardless()
        }
        rebuildStatusMenu()
    }

    /// Space bar's size switch, from anywhere.
    func switchWindowSize() {
        guard let appState else { return }
        appState.setWindowSizePreset(appState.spaceToggleTargetPreset())
        applyWindowPreset()
    }

    func applyGlobalShortcuts() {
        hotKeys.unregisterAll()
        guard appState?.globalShortcutsEnabled ?? true else { return }
        hotKeys.register(GlobalHotKeys.toggleCamera) { [weak self] in self?.toggleCamera() }
        hotKeys.register(GlobalHotKeys.switchSize) { [weak self] in self?.switchWindowSize() }
    }

    /// A menu bar app has no Dock icon and no app menu; the status bar item is always there either way.
    func applyDockIconPolicy() {
        let hides = appState?.hidesDockIcon ?? UserDefaults.standard.bool(forKey: "hidesDockIcon")
        NSApp.setActivationPolicy(hides ? .accessory : .regular)
        // Changing the policy deactivates the app; keep the settings window in front if that is where it came from.
        if let settings = settingsController?.window, settings.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            settings.makeKeyAndOrderFront(nil)
        }
    }

    func showSettings(_ page: SettingsPageID? = nil) {
        guard let appState else { return }
        if settingsController == nil {
            settingsController = SettingsWindowController(appState: appState)
        }
        settingsController?.show(page)
    }

    /// Resizes and places the camera window for the current size preset.
    func applyWindowPreset() {
        guard let appState, let window = cameraWindow, let screen = window.screen ?? NSScreen.main else { return }
        let preset = appState.windowSizePreset
        let visibleFrame = screen.visibleFrame
        let newSize = preset.size(visibleFrame: visibleFrame)
        let origin = appState.originToApply(for: preset, visibleFrame: visibleFrame, windowSize: newSize)
        window.setFrame(CGRect(origin: origin, size: newSize), display: true)
    }

    func confirmRestoreDefaults() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Restore defaults?")
        alert.informativeText = String(localized: "All settings will be reset to their initial values.")
        alert.addButton(withTitle: String(localized: "Restore"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.buttons.first?.hasDestructiveAction = true
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        appState?.resetToDefaults()
        applyWindowPreset()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        applyDockIconPolicy()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyGlobalShortcuts()
        setupStatusBar()
        setupStatusBarMenuRebuildObserver()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setupWindowStyle()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        NotificationCenter.default.post(name: .statusMenuWillOpen, object: nil)
        rebuildStatusMenu()
    }

    func setupStatusBarMenuRebuildObserver() {
        NotificationCenter.default.addObserver(
            forName: .statusMenuShouldRebuild,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildStatusMenu()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Garante que a janela da câmera recebe teclado (setas) quando o app está ativo,
        // sem roubar o foco da janela de Settings
        if NSApp.keyWindow == nil {
            cameraWindow?.makeKey()
        }
    }

    /// Clicking the Dock icon brings a hidden camera back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !isCameraShown { toggleCamera() }
        return false
    }

    /// ⌘W hides the camera instead of closing it, so it can always come back from the menu bar or the shortcut.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === knownCameraWindow else { return true }
        toggleCamera()
        return false
    }

    private func setupWindowStyle() {
        guard let window = cameraWindow else { return }
        knownCameraWindow = window
        // Follows you to every desktop and over full-screen apps (Keynote, a full-screen editor), where the
        // recording usually happens.
        window.collectionBehavior.formUnion([.canJoinAllSpaces, .fullScreenAuxiliary])
        window.styleMask.insert(.fullSizeContentView)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.delegate = self
        // Sem botões de fechar/minimizar/zoom — só o shape e a câmera
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        // Remove a linha sutil entre title bar e conteúdo (baseline separator)
        if window.toolbar != nil {
            window.toolbar?.showsBaselineSeparator = false
        } else {
            let toolbar = NSToolbar(identifier: "CameraManMain")
            toolbar.showsBaselineSeparator = false
            window.toolbar = toolbar
        }
        // Title bar separator pode estar na hierarquia do contentView ou do container da janela
        if let container = window.contentView?.superview {
            hideTitleBarSeparatorLine(in: container)
        }
        // Garante que a janela recebe teclado (setas etc.)
        window.ignoresMouseEvents = false
    }

    /// Esconde a linha de 1px que o sistema desenha entre a title bar e o conteúdo.
    private func hideTitleBarSeparatorLine(in view: NSView?) {
        guard let view = view else { return }
        let className = String(describing: type(of: view))
        // Vista que parece separador (muito fina e larga) ou tem nome sugerindo separador
        let looksLikeSeparator = view.frame.height > 0 && view.frame.height <= 2 && view.frame.width > 50
        let nameSuggestSeparator = className.lowercased().contains("separator") || className.lowercased().contains("divider") || className.contains("Baseline")
        if looksLikeSeparator || nameSuggestSeparator {
            view.isHidden = true
        }
        for subview in view.subviews {
            hideTitleBarSeparatorLine(in: subview)
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenu = NSMenu()
        statusMenu?.delegate = self
        statusItem?.menu = statusMenu
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "CameraMan")
            button.image?.isTemplate = true
            button.toolTip = "CameraMan"
        }
        rebuildStatusMenu()
    }

    func rebuildStatusMenu() {
        guard let menu = statusMenu else { return }
        menu.removeAllItems()
        if let appState = appState {
            for item in buildStatusMenuItems(appState: appState) {
                menu.addItem(item)
            }
        } else {
            // Menu mínimo: sempre mostra Settings e Quit
            let settingsItem = NSMenuItem(title: String(localized: "Settings..."), action: #selector(openSettings), keyEquivalent: ",")
            settingsItem.target = self
            menu.addItem(settingsItem)
            let quitItem = NSMenuItem(title: String(localized: "Quit CameraMan"), action: #selector(quit), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
        }
    }

    private func buildStatusMenuItems(appState: AppState) -> [NSMenuItem] {
        var items: [NSMenuItem] = []

        let toggleItem = NSMenuItem(
            title: isCameraShown ? String(localized: "Hide Camera") : String(localized: "Show Camera"), action: #selector(toggleCameraFromMenu),
            keyEquivalent: appState.globalShortcutsEnabled ? "c" : "")
        toggleItem.keyEquivalentModifierMask = [.control, .option, .command]
        toggleItem.target = self
        items.append(toggleItem)
        items.append(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: String(localized: "Settings..."), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        items.append(settingsItem)
        let restoreItem = NSMenuItem(title: String(localized: "Restore defaults"), action: #selector(restoreDefaults), keyEquivalent: "")
        restoreItem.target = self
        items.append(restoreItem)
        items.append(NSMenuItem.separator())

        let sizeMenu = NSMenu()
        for preset in WindowSizePreset.allCases {
            let item = NSMenuItem(title: preset.displayName.localized, action: #selector(selectWindowSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset
            item.state = appState.windowSizePreset == preset ? .on : .off
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: String(localized: "Window size"), action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        items.append(sizeItem)

        let slot1Menu = NSMenu()
        for preset in WindowSizePreset.allCases {
            let item = NSMenuItem(title: preset.displayName.localized, action: #selector(selectSpaceSlot1(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset
            item.state = appState.spaceSlot1 == preset ? .on : .off
            slot1Menu.addItem(item)
        }
        let slot1Item = NSMenuItem(title: String(localized: "Space bar: Slot 1"), action: nil, keyEquivalent: "")
        slot1Item.submenu = slot1Menu
        items.append(slot1Item)

        let slot2Menu = NSMenu()
        for preset in WindowSizePreset.allCases {
            let item = NSMenuItem(title: preset.displayName.localized, action: #selector(selectSpaceSlot2(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset
            item.state = appState.spaceSlot2 == preset ? .on : .off
            slot2Menu.addItem(item)
        }
        let slot2Item = NSMenuItem(title: String(localized: "Space bar: Slot 2"), action: nil, keyEquivalent: "")
        slot2Item.submenu = slot2Menu
        items.append(slot2Item)

        let edgeMenu = NSMenu()
        for edge in ScreenEdge.allCases {
            let item = NSMenuItem(title: edge.displayName.localized, action: #selector(selectScreenEdge(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = edge
            item.state = appState.screenEdge == edge ? .on : .off
            edgeMenu.addItem(item)
        }
        let edgeItem = NSMenuItem(title: String(localized: "Screen edge"), action: nil, keyEquivalent: "")
        edgeItem.submenu = edgeMenu
        items.append(edgeItem)

        let cameraMenu = NSMenu()
        if appState.videoDevices.isEmpty {
            let noCamerasItem = NSMenuItem(title: String(localized: "No cameras"), action: nil, keyEquivalent: "")
            noCamerasItem.isEnabled = false
            cameraMenu.addItem(noCamerasItem)
        } else {
            for device in appState.videoDevices {
                let item = NSMenuItem(title: device.name, action: #selector(selectCamera(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = device.id
                item.state = appState.selectedDeviceId == device.id ? .on : .off
                cameraMenu.addItem(item)
            }
        }
        let cameraItem = NSMenuItem(title: String(localized: "Camera"), action: nil, keyEquivalent: "")
        cameraItem.submenu = cameraMenu
        items.append(cameraItem)

        let quitItem = NSMenuItem(title: String(localized: "Quit CameraMan"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        items.append(quitItem)

        return items
    }

    @objc private func toggleCameraFromMenu() {
        toggleCamera()
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func restoreDefaults() {
        confirmRestoreDefaults()
    }

    @objc private func selectSpaceSlot1(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? WindowSizePreset else { return }
        appState?.spaceSlot1 = preset
        appState?.saveToUserDefaults()
    }

    @objc private func selectSpaceSlot2(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? WindowSizePreset else { return }
        appState?.spaceSlot2 = preset
        appState?.saveToUserDefaults()
    }

    @objc private func selectWindowSize(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? WindowSizePreset else { return }
        appState?.setWindowSizePreset(preset)
        applyWindowPreset()
    }

    @objc private func selectScreenEdge(_ sender: NSMenuItem) {
        guard let edge = sender.representedObject as? ScreenEdge else { return }
        appState?.setScreenEdge(edge)
        applyWindowPreset()
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.isVisible,
              let appState = appState else { return }
        appState.setOriginForCurrentPreset(window.frame.origin)
    }

    func windowDidMiniaturize(_ notification: Notification) {
        appState?.isWindowVisible = false
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        appState?.isWindowVisible = true
    }

    @objc private func selectCamera(_ sender: NSMenuItem) {
        guard let deviceId = sender.representedObject as? String else { return }
        appState?.selectedDeviceId = deviceId
        appState?.saveToUserDefaults()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
