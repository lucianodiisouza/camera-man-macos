import Carbon.HIToolbox

/// System-wide shortcuts, so the camera can be shown, hidden or resized while another app (the one being recorded) is
/// in front. Carbon hot keys need no Accessibility permission and work inside the App Sandbox.
final class GlobalHotKeys {
    struct Shortcut {
        let keyCode: Int
        let modifiers: Int
        /// How the shortcut reads, for the menus and the Shortcuts page.
        let symbols: [String]
    }

    static let toggleCamera = Shortcut(keyCode: kVK_ANSI_C, modifiers: controlKey | optionKey | cmdKey, symbols: ["⌃", "⌥", "⌘", "C"])
    static let switchSize = Shortcut(keyCode: kVK_ANSI_S, modifiers: controlKey | optionKey | cmdKey, symbols: ["⌃", "⌥", "⌘", "S"])

    private var hotKeys: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var handler: EventHandlerRef?

    func register(_ shortcut: Shortcut, action: @escaping () -> Void) {
        installHandlerIfNeeded()
        let id = UInt32(actions.count + 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode), UInt32(shortcut.modifiers),
            EventHotKeyID(signature: OSType(0x434D_414E), id: id),  // "CMAN"
            GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return }
        hotKeys.append(ref)
        actions[id] = action
    }

    func unregisterAll() {
        hotKeys.forEach { UnregisterEventHotKey($0) }
        hotKeys = []
        actions = [:]
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                let hotKeys = Unmanaged<GlobalHotKeys>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { hotKeys.actions[hotKeyID.id]?() }
                return noErr
            },
            1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
}
