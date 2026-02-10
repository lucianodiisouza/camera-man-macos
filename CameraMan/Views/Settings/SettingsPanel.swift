import SwiftUI
import AppKit

struct SettingsPanel: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                cameraSection
                shapeSection
                positionSection
                zoomSection
                flipSection
                borderSection
                windowSection
                aboutSection
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Restore defaults", role: .destructive) {
                        appState.showResetConfirmation = true
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .alert("Restore defaults?", isPresented: $appState.showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                appState.resetToDefaults()
            }
        } message: {
            Text("All settings will be reset to their initial values.")
        }
    }

    private var cameraSection: some View {
        Section {
            Picker(selection: $appState.selectedDeviceId) {
                Text("System default").tag(nil as String?)
                ForEach(appState.videoDevices) { device in
                    Text(device.name).tag(device.id as String?)
                }
            } label: {
                Label("Camera", systemImage: "video.fill")
            }
            .onChange(of: appState.selectedDeviceId) { _, _ in appState.saveToUserDefaults() }
        } header: {
            Text("Camera")
        }
    }

    private var shapeSection: some View {
        Section {
            Picker(selection: $appState.shapeType) {
                ForEach(ShapeType.allCases) { shape in
                    Text(shape.displayName).tag(shape)
                }
            } label: {
                Label("Shape", systemImage: "square.on.circle")
            }
            .onChange(of: appState.shapeType) { _, _ in appState.saveToUserDefaults() }
            if appState.shapeType != .circle {
                HStack {
                    Label("Corner radius", systemImage: "square.roundedbottomright")
                    Slider(value: $appState.shapeCornerRadius, in: AppState.shapeCornerRadiusRange, step: 2)
                        .onChange(of: appState.shapeCornerRadius) { _, _ in appState.saveToUserDefaults() }
                    Text("\(Int(appState.shapeCornerRadius))").frame(width: 32, alignment: .trailing)
                }
            }
        } header: {
            Text("Shape")
        }
    }

    private var positionSection: some View {
        Section {
            HStack {
                Label("Horizontal", systemImage: "arrow.left.and.right")
                Slider(value: $appState.offsetX, in: AppState.offsetRange, step: 1)
                    .onChange(of: appState.offsetX) { _, _ in appState.saveToUserDefaults() }
                Text("\(Int(appState.offsetX))%").frame(width: 36, alignment: .trailing)
            }
            HStack {
                Label("Vertical", systemImage: "arrow.up.and.down")
                Slider(value: $appState.offsetY, in: AppState.offsetRange, step: 1)
                    .onChange(of: appState.offsetY) { _, _ in appState.saveToUserDefaults() }
                Text("\(Int(appState.offsetY))%").frame(width: 36, alignment: .trailing)
            }
        } header: {
            Text("Position")
        }
    }

    private var zoomSection: some View {
        Section {
            HStack {
                Label("Zoom", systemImage: "magnifyingglass")
                Slider(value: $appState.scale, in: AppState.scaleRange, step: 0.1)
                    .onChange(of: appState.scale) { _, _ in appState.saveToUserDefaults() }
                Text(String(format: "%.1f", appState.scale)).frame(width: 36, alignment: .trailing)
            }
        } header: {
            Text("Zoom")
        }
    }

    private var flipSection: some View {
        Section {
            Toggle(isOn: $appState.flipHorizontal) {
                Label("Flip horizontal", systemImage: "arrow.left.and.right.righttriangle.split.2x2")
            }
            .onChange(of: appState.flipHorizontal) { _, _ in appState.saveToUserDefaults() }
            Toggle(isOn: $appState.flipVertical) {
                Label("Flip vertical", systemImage: "arrow.up.and.down")
            }
            .onChange(of: appState.flipVertical) { _, _ in appState.saveToUserDefaults() }
        }
    }

    private var borderSection: some View {
        Section {
            // Border (isolado — pode usar só borda, só sombra, ou os dois)
            Toggle(isOn: $appState.showBorder) {
                Label("Show border", systemImage: "rectangle.dashed")
            }
            .onChange(of: appState.showBorder) { _, _ in appState.saveToUserDefaults() }
            if appState.showBorder {
                HStack {
                    Label("Width", systemImage: "ruler")
                    Slider(value: $appState.borderWidth, in: AppState.borderWidthRange, step: 1)
                        .onChange(of: appState.borderWidth) { _, _ in appState.saveToUserDefaults() }
                    Text("\(Int(appState.borderWidth)) pt").frame(width: 44, alignment: .trailing)
                }
                Toggle("Gradient", isOn: $appState.borderUseGradient)
                    .onChange(of: appState.borderUseGradient) { _, _ in appState.saveToUserDefaults() }
                if appState.borderUseGradient {
                    ColorPicker("Start", selection: $appState.borderGradientStartColor)
                        .onChange(of: appState.borderGradientStartColor) { _, _ in appState.saveToUserDefaults() }
                    ColorPicker("End", selection: $appState.borderGradientEndColor)
                        .onChange(of: appState.borderGradientEndColor) { _, _ in appState.saveToUserDefaults() }
                } else {
                    ColorPicker("Color", selection: $appState.borderColor)
                        .onChange(of: appState.borderColor) { _, _ in appState.saveToUserDefaults() }
                }
            }
            // Shadow (independente — pode ter só sombra sem borda)
            Toggle(isOn: $appState.showShadow) {
                Label("Show shadow", systemImage: "drop.shadow")
            }
            .onChange(of: appState.showShadow) { _, _ in appState.saveToUserDefaults() }
            if appState.showShadow {
                HStack {
                    Label("Radius", systemImage: "circle.lefthalf.filled")
                    Slider(value: $appState.borderShadowRadius, in: AppState.borderShadowRadiusRange, step: 1)
                        .onChange(of: appState.borderShadowRadius) { _, _ in appState.saveToUserDefaults() }
                    Text("\(Int(appState.borderShadowRadius))").frame(width: 28, alignment: .trailing)
                }
                ColorPicker("Shadow color", selection: $appState.borderShadowColor)
                    .onChange(of: appState.borderShadowColor) { _, _ in appState.saveToUserDefaults() }
            }
        } header: {
            Text("Border & shadow")
        }
    }

    private var windowSection: some View {
        Section {
            Picker(selection: $appState.windowSizePreset) {
                ForEach(WindowSizePreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            } label: {
                Label("Window size", systemImage: "rectangle.compress.vertical")
            }
            .onChange(of: appState.windowSizePreset) { _, new in
                appState.saveToUserDefaults()
                resizeMainWindow(to: new)
            }
            Picker(selection: $appState.screenEdge) {
                ForEach(ScreenEdge.allCases) { edge in
                    Text(edge.displayName).tag(edge)
                }
            } label: {
                Label("Screen edge", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .onChange(of: appState.screenEdge) { _, _ in
                appState.saveToUserDefaults()
                moveWindowToScreenEdge(appState.screenEdge)
            }
        } header: {
            Text("Window")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Camera-Man")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
            Link("Source code", destination: URL(string: "https://github.com/camera-man/camera-man")!)
        } header: {
            Text("About")
        }
    }

    private func resizeMainWindow(to preset: WindowSizePreset) {
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible }) else { return }
        let frame = window.frame
        let centerX = frame.midX
        let centerY = frame.midY
        let newSize = CGSize(width: preset.width, height: preset.height)
        let newOrigin = CGPoint(x: centerX - newSize.width / 2, y: centerY - newSize.height / 2)
        window.setFrame(CGRect(origin: newOrigin, size: newSize), display: true)
    }

    private func moveWindowToScreenEdge(_ edge: ScreenEdge) {
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible }),
              let screen = window.screen ?? NSScreen.main else { return }
        let frame = screen.visibleFrame
        var newOrigin = window.frame.origin
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
}
