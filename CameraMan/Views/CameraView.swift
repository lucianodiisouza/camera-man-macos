import SwiftUI
import AVFoundation
import QuartzCore

struct CameraView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraService = CameraService()
    @State private var previewLayer: AVCaptureVideoPreviewLayer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Organic breathing redraws the outline 15 times a second (the motion is slow enough not to need more), and only
    /// while someone can see it.
    private var isBreathing: Bool {
        appState.shapeType == .organic && appState.organicBreathing && appState.isWindowVisible && !reduceMotion
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Group {
                if appState.cameraPermissionGranted == true {
                    // Só mostra o shape da câmera depois que o usuário aceitou a permissão
                    cameraShapeStack(size: size)
                } else {
                    // Antes de aceitar (ou se negou): tela cheia, sem shape
                    permissionPlaceholderView(size: size)
                }
            }
            .onAppear {
                cameraService.appState = appState
                cameraService.requestPermissionAndSetup { [weak cameraService] in
                    guard let cameraService = cameraService else { return }
                    guard cameraService.status != .notFound else { return }
                    let preferredId = appState.selectedDeviceId
                    let deviceIds = cameraService.videoDevices.map(\.id)
                    previewLayer = cameraService.startPreviewLayer(size: geo.size, preferredDeviceId: preferredId, deviceIds: deviceIds)
                }
            }
            .onChange(of: appState.selectedDeviceId) { _, newId in
                cameraService.selectDevice(id: newId)
            }
            .onChange(of: appState.isWindowVisible) { _, visible in
                if visible {
                    cameraService.resume()
                } else {
                    cameraService.pause()
                }
            }
            // Nobody can see the camera while the screen sleeps or is locked: stop it, which also turns the light off.
            .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidSleepNotification)) { _ in
                cameraService.pause()
            }
            .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidResignActiveNotification)) { _ in
                cameraService.pause()
            }
            .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidWakeNotification)) { _ in
                if appState.isWindowVisible { cameraService.resume() }
            }
            .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidBecomeActiveNotification)) { _ in
                if appState.isWindowVisible { cameraService.resume() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .statusMenuWillOpen)) { _ in
                cameraService.refreshDeviceList {
                    NotificationCenter.default.post(name: .statusMenuShouldRebuild, object: nil)
                }
            }
        }
        .background(Color.clear)
    }

    @ViewBuilder
    private func cameraShapeStack(size: CGSize) -> some View {
        let shapeView = shape(time: 0)
        ZStack {
            if appState.showShadow, appState.borderShadowRadius > 0 {
                let shadowStrokeWidth: CGFloat = (appState.showBorder && appState.borderWidth > 0)
                    ? appState.borderWidth + 2 * appState.borderShadowRadius
                    : 2 * appState.borderShadowRadius
                outline { shape in
                    shape
                        .stroke(appState.borderShadowColor, lineWidth: shadowStrokeWidth)
                        .compositingGroup()
                        .blur(radius: appState.borderShadowRadius)
                }
            }

            if let layer = previewLayer {
                Group {
                    CameraPreviewRepresentable(
                        layer: layer,
                        brightness: appState.brightness,
                        contrast: appState.contrast,
                        saturation: appState.saturation
                    )
                    .scaleEffect(
                        x: appState.flipHorizontal ? -1 : 1,
                        y: appState.flipVertical ? -1 : 1,
                        anchor: .center
                    )
                    .scaleEffect(appState.scale)
                    .offset(
                        x: size.width * (appState.offsetX / 100),
                        y: size.height * (-appState.offsetY / 100)
                    )
                }
                .frame(width: size.width, height: size.height)
                .mask {
                    // Only the mask breathes; the camera view under it is not redrawn.
                    outline { shape in
                        if appState.softEdge > 0 {
                            // Inset by the blur radius, so the fade never runs past the outline.
                            shape.fill().padding(appState.softEdge).blur(radius: appState.softEdge)
                        } else {
                            shape.fill()
                        }
                    }
                }
            } else {
                Color.black
                    .overlay {
                        if appState.cameraStatus == .loading {
                            ProgressView()
                                .scaleEffect(1.5)
                        } else if appState.cameraStatus == .notFound {
                            VStack(spacing: 12) {
                                Image(systemName: "video.slash")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                Text("No camera found")
                                    .font(.headline)
                                Text("Connect a camera or check permissions in System Settings.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(24)
                        }
                    }
            }

            // A border would draw a hard line around a feathered edge, so a soft edge replaces it.
            if appState.showBorder, appState.borderWidth > 0, appState.softEdge == 0 {
                outline { borderStrokeView(shape: $0) }
            }
        }
        .contentShape(shapeView)
    }

    @ViewBuilder
    private func permissionPlaceholderView(size: CGSize) -> some View {
        Color.black
            .frame(width: size.width, height: size.height)
            .overlay {
                if appState.cameraPermissionGranted == false {
                    VStack(spacing: 16) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Camera access was denied")
                            .font(.headline)
                        Text("Open System Settings → Privacy & Security → Camera to allow CameraMan.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(24)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Requesting camera access…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
    }

    /// Draws `content` with the current outline; while breathing, only this part is redrawn on every tick.
    @ViewBuilder
    private func outline<Content: View>(@ViewBuilder _ content: @escaping (ShapeTypeShape) -> Content) -> some View {
        if isBreathing {
            TimelineView(.animation(minimumInterval: 1.0 / 15)) { context in
                content(shape(time: context.date.timeIntervalSinceReferenceDate))
            }
        } else {
            content(shape(time: 0))
        }
    }

    private func shape(time: Double) -> ShapeTypeShape {
        ShapeTypeShape(
            shapeType: appState.shapeType, cornerRadius: appState.shapeCornerRadius, blob: appState.organicBlob, time: time)
    }

    /// Border stroke only (gradient or solid). Shadow is drawn as a separate layer behind the preview so it stays external.
    /// Drawn on the clip shape so border always matches the visible camera outline (including when zoom < 1).
    @ViewBuilder
    private func borderStrokeView(shape: ShapeTypeShape) -> some View {
        let lineWidth = appState.borderWidth
        Group {
            if appState.borderUseGradient {
                shape.stroke(
                    LinearGradient(
                        colors: [appState.borderGradientStartColor, appState.borderGradientEndColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: lineWidth
                )
            } else {
                shape.stroke(appState.borderColor, lineWidth: lineWidth)
            }
        }
    }
}

