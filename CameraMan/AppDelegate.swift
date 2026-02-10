import AppKit
import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    /// Posted when the status bar menu is about to open; observers can refresh device list.
    static let statusMenuWillOpen = Notification.Name("statusMenuWillOpen")
    /// Posted when device list was updated so the status menu can rebuild (e.g. after refresh).
    static let statusMenuShouldRebuild = Notification.Name("statusMenuShouldRebuild")
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    weak var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        // Garante que a janela principal recebe teclado (setas) quando o app está ativo
        if let window = NSApplication.shared.windows.first(where: { $0.isVisible }) {
            window.makeKey()
        }
    }

    private func setupWindowStyle() {
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible }) else { return }
        window.styleMask.insert(.fullSizeContentView)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.isMovableByWindowBackground = true
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
            button.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "Camera-Man")
            button.image?.isTemplate = true
            button.toolTip = "Camera-Man"
        }
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        guard let menu = statusMenu else { return }
        menu.removeAllItems()
        if let appState = appState {
            for item in buildStatusMenuItems(appState: appState) {
                menu.addItem(item)
            }
        } else {
            // Menu mínimo: sempre mostra Settings e Quit (Settings abre via notificação)
            menu.addItem(withTitle: "Camera-Man", action: nil, keyEquivalent: "")
            menu.items.last?.isEnabled = false
            menu.addItem(NSMenuItem.separator())
            let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
            settingsItem.target = self
            menu.addItem(settingsItem)
            menu.addItem(NSMenuItem.separator())
            let quitItem = NSMenuItem(title: "Quit Camera-Man", action: #selector(quit), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
        }
    }

    private func buildStatusMenuItems(appState: AppState) -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        items.append(NSMenuItem(title: "Camera-Man v1.0", action: nil, keyEquivalent: ""))
        items.last?.isEnabled = false
        items.append(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        items.append(settingsItem)
        let restoreItem = NSMenuItem(title: "Restore defaults", action: #selector(restoreDefaults), keyEquivalent: "")
        restoreItem.target = self
        items.append(restoreItem)
        items.append(NSMenuItem.separator())

        let sizeMenu = NSMenu()
        for preset in WindowSizePreset.allCases {
            let item = NSMenuItem(title: preset.displayName, action: #selector(selectWindowSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset
            item.state = appState.windowSizePreset == preset ? .on : .off
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "Window size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        items.append(sizeItem)

        let edgeMenu = NSMenu()
        for edge in ScreenEdge.allCases {
            let item = NSMenuItem(title: edge.displayName, action: #selector(selectScreenEdge(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = edge
            item.state = appState.screenEdge == edge ? .on : .off
            edgeMenu.addItem(item)
        }
        let edgeItem = NSMenuItem(title: "Screen edge", action: nil, keyEquivalent: "")
        edgeItem.submenu = edgeMenu
        items.append(edgeItem)

        let cameraMenu = NSMenu()
        if appState.videoDevices.isEmpty {
            let noCamerasItem = NSMenuItem(title: "No cameras", action: nil, keyEquivalent: "")
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
        let cameraItem = NSMenuItem(title: "Camera", action: nil, keyEquivalent: "")
        cameraItem.submenu = cameraMenu
        items.append(cameraItem)

        items.append(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Camera-Man", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        items.append(quitItem)

        return items
    }

    @objc private func openSettings() {
        if appState != nil {
            appState?.showSettings = true
        } else {
            NotificationCenter.default.post(name: .openSettings, object: nil)
        }
    }

    @objc private func restoreDefaults() {
        appState?.showResetConfirmation = true
    }

    @objc private func selectWindowSize(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? WindowSizePreset else { return }
        appState?.windowSizePreset = preset
        appState?.saveToUserDefaults()
        if let window = NSApplication.shared.windows.first(where: { $0.isVisible }) {
            let frame = window.frame
            // Preserve top-left corner (macOS: origin is bottom-left, so top = origin.y + height)
            let newSize = CGSize(width: preset.width, height: preset.height)
            let newOrigin = CGPoint(
                x: frame.minX,
                y: (frame.origin.y + frame.height) - newSize.height
            )
            window.setFrame(CGRect(origin: newOrigin, size: newSize), display: true)
        }
    }

    @objc private func selectScreenEdge(_ sender: NSMenuItem) {
        guard let edge = sender.representedObject as? ScreenEdge else { return }
        appState?.screenEdge = edge
        appState?.saveToUserDefaults()
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible }),
              let screen = window.screen ?? NSScreen.main else { return }
        let frame = screen.visibleFrame
        var newOrigin: CGPoint
        switch edge {
        case .topLeft:
            newOrigin = CGPoint(x: frame.minX, y: frame.maxY - window.frame.height)
        case .topRight:
            newOrigin = CGPoint(x: frame.maxX - window.frame.width, y: frame.maxY - window.frame.height)
        case .bottomRight:
            newOrigin = CGPoint(x: frame.maxX - window.frame.width, y: frame.minY)
        case .bottomLeft:
            newOrigin = CGPoint(x: frame.minX, y: frame.minY)
        }
        window.setFrameOrigin(newOrigin)
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
