import AppKit
import ServiceManagement
import SwiftUI

// One view per page of the settings window. Every control writes through `appState.saving(...)`, which persists the
// change as it happens.

extension AppState {
    /// A binding that saves the settings after every change.
    func saving<T>(_ keyPath: ReferenceWritableKeyPath<AppState, T>) -> Binding<T> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: {
                self[keyPath: keyPath] = $0
                self.saveToUserDefaults()
            })
    }

    /// `saving` for the CGFloat settings, which sliders want as Double.
    func saving(_ keyPath: ReferenceWritableKeyPath<AppState, CGFloat>) -> Binding<Double> {
        Binding(
            get: { Double(self[keyPath: keyPath]) },
            set: {
                self[keyPath: keyPath] = CGFloat($0)
                self.saveToUserDefaults()
            })
    }
}

private var appDelegate: AppDelegate? { NSApp.delegate as? AppDelegate }

private extension ClosedRange where Bound == CGFloat {
    var asDouble: ClosedRange<Double> { Double(lowerBound)...Double(upperBound) }
}

// MARK: - Camera

struct CameraSettingsPage: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "Camera", subtitle: "Which camera shows in the floating window")
            SettingsGroup(footer: "Backspace in the camera window jumps to the next camera.") {
                SettingsPickerRow(
                    symbol: "video.fill", color: SettingsPageID.camera.color, title: "Video source",
                    subtitle: appState.videoDevices.isEmpty ? "No camera found" : "\(appState.videoDevices.count) available",
                    selection: appState.saving(\.selectedDeviceId)
                ) {
                    Text("System default").tag(nil as String?)
                    ForEach(appState.videoDevices) { device in
                        Text(device.name).tag(device.id as String?)
                    }
                }
            }
            if appState.cameraPermissionGranted == false {
                SettingsGroup {
                    SettingsRow(
                        symbol: "lock.fill", color: Color(hex: "#F97316"), title: "Camera access is off",
                        subtitle: "Allow CameraMan in System Settings → Privacy & Security → Camera"
                    ) {
                        Button("Open…") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Shape

struct ShapeSettingsPage: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "Shape", subtitle: "The outline your camera is cut to. O cycles through them")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 14)], spacing: 14) {
                ForEach(ShapeType.allCases) { shape in
                    VisualChoiceCard(title: shape.shortName, isSelected: appState.shapeType == shape) {
                        appState.shapeType = shape
                        appState.saveToUserDefaults()
                    } preview: {
                        ShapePreview(shape: shape, cornerRadius: appState.shapeCornerRadius)
                    }
                }
            }
            SettingsGroup {
                SettingsSliderRow(
                    symbol: "rectangle.roundedtop", color: SettingsPageID.shape.color, title: "Corner radius",
                    subtitle: "Rounds the corners of the square and the rectangles",
                    value: appState.saving(\.shapeCornerRadius), range: AppState.shapeCornerRadiusRange.asDouble,
                    step: 2, format: { "\(Int($0)) pt" })
            }
            .disabled(appState.shapeType == .circle)
        }
    }
}

/// A person silhouette cut to a shape, on the preview backdrop.
private struct ShapePreview: View {
    let shape: ShapeType
    let cornerRadius: CGFloat

    var body: some View {
        // The camera window is about five times this preview, so the radius is scaled to match.
        let clip = ShapeTypeShape(shapeType: shape, cornerRadius: cornerRadius / 5)
        LinearGradient(colors: [Color(hex: "#64748B"), Color(hex: "#334155")], startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .bottom) {
                Image(systemName: "person.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.85))
                    .offset(y: 8)
            }
            .clipShape(clip)
            .overlay(clip.stroke(Color.white.opacity(0.25), lineWidth: 1))
            .frame(width: 84, height: 84)
    }
}

// MARK: - Framing

struct FramingSettingsPage: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "Framing", subtitle: "Where you sit inside the shape")
            SettingsGroup(footer: "The arrow keys move the image and + / − zoom while the camera window is focused.") {
                SettingsSliderRow(
                    symbol: "arrow.left.and.right", color: SettingsPageID.framing.color, title: "Horizontal position",
                    value: appState.saving(\.offsetX), range: AppState.offsetRange, format: { "\(Int($0))%" })
                SettingsSliderRow(
                    symbol: "arrow.up.and.down", color: SettingsPageID.framing.color, title: "Vertical position",
                    value: appState.saving(\.offsetY), range: AppState.offsetRange, format: { "\(Int($0))%" })
                SettingsSliderRow(
                    symbol: "plus.magnifyingglass", color: SettingsPageID.framing.color, title: "Zoom",
                    value: appState.saving(\.scale), range: AppState.scaleRange, step: 0.1,
                    format: { String(format: "%.1f×", $0) })
            }
            SettingsGroup(title: "Orientation") {
                SettingsToggleRow(
                    symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill", color: Color(hex: "#14B8A6"),
                    title: "Mirror horizontally", subtitle: "See yourself the way a mirror shows you",
                    isOn: appState.saving(\.flipHorizontal))
                SettingsToggleRow(
                    symbol: "arrow.up.and.down.righttriangle.up.righttriangle.down.fill", color: Color(hex: "#14B8A6"),
                    title: "Flip vertically", subtitle: "For a camera mounted upside down",
                    isOn: appState.saving(\.flipVertical))
            }
            HStack {
                Spacer()
                Button("Reset framing") {
                    appState.offsetX = 0
                    appState.offsetY = 0
                    appState.scale = 1
                    appState.saveToUserDefaults()
                }
            }
        }
    }
}

// MARK: - Image

struct ImageSettingsPage: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "Image", subtitle: "Color correction, applied to the preview in real time")
            SettingsGroup {
                SettingsSliderRow(
                    symbol: "sun.max.fill", color: SettingsPageID.image.color, title: "Brightness",
                    value: appState.saving(\.brightness), range: AppState.brightnessRange, step: 0.05,
                    format: { String(format: "%+.2f", $0) })
                SettingsSliderRow(
                    symbol: "circle.lefthalf.filled", color: SettingsPageID.image.color, title: "Contrast",
                    value: appState.saving(\.contrast), range: AppState.contrastRange, step: 0.1,
                    format: { String(format: "%.1f", $0) })
                SettingsSliderRow(
                    symbol: "drop.fill", color: SettingsPageID.image.color, title: "Saturation",
                    value: appState.saving(\.saturation), range: AppState.saturationRange, step: 0.1,
                    format: { String(format: "%.1f", $0) })
            }
            HStack {
                Spacer()
                Button("Reset image") {
                    appState.brightness = 0
                    appState.contrast = 1
                    appState.saturation = 1
                    appState.saveToUserDefaults()
                }
            }
        }
    }
}

// MARK: - Border & shadow

struct BorderSettingsPage: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let accent = SettingsPageID.border.color
        SettingsPage {
            SettingsSectionTitle(title: "Border & Shadow", subtitle: "An outline and a glow around the shape")
            SettingsGroup(title: "Border") {
                SettingsToggleRow(
                    symbol: "square.dashed", color: accent, title: "Show border", isOn: appState.saving(\.showBorder))
                if appState.showBorder {
                    SettingsSliderRow(
                        symbol: "lineweight", color: accent, title: "Width",
                        value: appState.saving(\.borderWidth), range: AppState.borderWidthRange.asDouble,
                        format: { "\(Int($0)) pt" })
                    SettingsToggleRow(
                        symbol: "paintpalette.fill", color: accent, title: "Gradient",
                        subtitle: "Blend two colors from corner to corner", isOn: appState.saving(\.borderUseGradient))
                    if appState.borderUseGradient {
                        SettingsColorRow(
                            symbol: "circle.fill", color: accent, title: "Start color",
                            selection: appState.saving(\.borderGradientStartColor))
                        SettingsColorRow(
                            symbol: "circle.fill", color: accent, title: "End color",
                            selection: appState.saving(\.borderGradientEndColor))
                    } else {
                        SettingsColorRow(
                            symbol: "circle.fill", color: accent, title: "Color", selection: appState.saving(\.borderColor))
                    }
                }
            }
            SettingsGroup(title: "Shadow") {
                SettingsToggleRow(
                    symbol: "circle.bottomhalf.filled", color: Color(hex: "#475569"), title: "Show shadow",
                    subtitle: "Works with or without a border", isOn: appState.saving(\.showShadow))
                if appState.showShadow {
                    SettingsSliderRow(
                        symbol: "circle.dashed", color: Color(hex: "#475569"), title: "Radius",
                        value: appState.saving(\.borderShadowRadius), range: AppState.borderShadowRadiusRange.asDouble,
                        format: { "\(Int($0)) pt" })
                    SettingsColorRow(
                        symbol: "circle.fill", color: Color(hex: "#475569"), title: "Shadow color",
                        selection: appState.saving(\.borderShadowColor))
                }
            }
        }
    }
}

// MARK: - Window

struct WindowSettingsPage: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let accent = SettingsPageID.window.color
        SettingsPage {
            SettingsSectionTitle(title: "Window", subtitle: "Size and place of the floating camera")
            SettingsGroup {
                SettingsPickerRow(
                    symbol: "arrow.up.left.and.arrow.down.right", color: accent, title: "Size",
                    subtitle: "Each size remembers where you last put it",
                    selection: Binding(
                        get: { appState.windowSizePreset },
                        set: {
                            appState.setWindowSizePreset($0)
                            appDelegate?.applyWindowPreset()
                        })
                ) {
                    ForEach(WindowSizePreset.allCases) { Text($0.displayName).tag($0) }
                }
                SettingsPickerRow(
                    symbol: "rectangle.inset.topleft.filled", color: accent, title: "Screen corner",
                    subtitle: "Snaps the window to a corner of the screen",
                    selection: Binding(
                        get: { appState.screenEdge },
                        set: {
                            appState.setScreenEdge($0)
                            appDelegate?.applyWindowPreset()
                        })
                ) {
                    ForEach(ScreenEdge.allCases) { Text($0.displayName).tag($0) }
                }
            }
            SettingsGroup(title: "Space bar", footer: "Space in the camera window switches between these two sizes.") {
                SettingsPickerRow(
                    symbol: "1.circle.fill", color: Color(hex: "#6366F1"), title: "Space bar: first size",
                    selection: appState.saving(\.spaceSlot1)
                ) {
                    ForEach(WindowSizePreset.allCases) { Text($0.displayName).tag($0) }
                }
                SettingsPickerRow(
                    symbol: "2.circle.fill", color: Color(hex: "#6366F1"), title: "Space bar: second size",
                    selection: appState.saving(\.spaceSlot2)
                ) {
                    ForEach(WindowSizePreset.allCases) { Text($0.displayName).tag($0) }
                }
            }
        }
    }
}

// MARK: - General

struct GeneralSettingsPage: View {
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "General")
            SettingsGroup(footer: loginItemError) {
                SettingsToggleRow(
                    symbol: "power", color: Color(hex: "#22C55E"), title: "Open at login",
                    subtitle: "Start CameraMan when you log in to your Mac",
                    isOn: Binding(get: { opensAtLogin }, set: setOpensAtLogin))
            }
            SettingsGroup {
                SettingsRow(
                    symbol: "arrow.counterclockwise", color: Color(hex: "#EF4444"), title: "Restore defaults",
                    subtitle: "Put every setting back the way it was on first launch"
                ) {
                    Button("Restore…") { appDelegate?.confirmRestoreDefaults() }
                }
            }
        }
    }

    private func setOpensAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }
}

// MARK: - Shortcuts

struct ShortcutsSettingsPage: View {
    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "Shortcuts", subtitle: "Keys that work while the camera window is focused")
            SettingsGroup(title: "Camera window") {
                ShortcutRow(symbol: "arrow.up.and.down.and.arrow.left.and.right", title: "Move the image", keys: ["←", "→", "↑", "↓"])
                ShortcutRow(symbol: "plus.magnifyingglass", title: "Zoom in / out", keys: ["+", "−"])
                ShortcutRow(symbol: "1.magnifyingglass", title: "Reset zoom", keys: ["R"])
                ShortcutRow(symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill", title: "Mirror horizontally", keys: ["/"])
                ShortcutRow(symbol: "arrow.up.and.down.righttriangle.up.righttriangle.down.fill", title: "Flip vertically", keys: ["V"])
                ShortcutRow(symbol: "square.on.circle", title: "Next shape", keys: ["O"])
                ShortcutRow(symbol: "video.fill", title: "Next camera", keys: ["⌫"])
                ShortcutRow(symbol: "arrow.up.left.and.arrow.down.right", title: "Switch window size", keys: ["Space"])
            }
            SettingsGroup(title: "Menu bar") {
                ShortcutRow(symbol: "gearshape.fill", title: "Settings", keys: ["⌘", ","])
                ShortcutRow(symbol: "power", title: "Quit CameraMan", keys: ["⌘", "Q"])
            }
        }
    }
}

private struct ShortcutRow: View {
    let symbol: String
    let title: String
    let keys: [String]

    var body: some View {
        SettingsRow(symbol: symbol, color: SettingsPageID.shortcuts.color, title: title) {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 7)
                        .frame(minWidth: 24, minHeight: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.primary.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.12)))
                        )
                }
            }
        }
    }
}

// MARK: - About

struct AboutSettingsPage: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        SettingsPage {
            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                Text("CameraMan")
                    .font(.system(size: 22, weight: .bold))
                Text(version)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("A floating camera for screen recordings, demos and calls.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)

            SettingsGroup {
                SettingsRow(
                    symbol: "chevron.left.forwardslash.chevron.right", color: SettingsPageID.about.color,
                    title: "Source code", subtitle: "github.com/lucianodiisouza/camera-man-macos"
                ) {
                    Button("Open") {
                        NSWorkspace.shared.open(URL(string: "https://github.com/lucianodiisouza/camera-man-macos")!)
                    }
                }
            }
        }
    }
}
