import SwiftUI
import AVFoundation
import QuartzCore

struct CameraView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraService = CameraService()
    @State private var previewLayer: AVCaptureVideoPreviewLayer?

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
        ZStack {
            if appState.showShadow, appState.borderShadowRadius > 0 {
                let shadowStrokeWidth: CGFloat = (appState.showBorder && appState.borderWidth > 0)
                    ? appState.borderWidth + 2 * appState.borderShadowRadius
                    : 2 * appState.borderShadowRadius
                shapeView
                    .stroke(appState.borderShadowColor, lineWidth: shadowStrokeWidth)
                    .compositingGroup()
                    .blur(radius: appState.borderShadowRadius)
            }

            if let frame = cameraService.currentFrame {
                Group {
                    FilteredCameraPreviewView(cgImage: frame)
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
                .clipShape(shapeView)
            } else if let layer = previewLayer {
                Group {
                    CameraPreviewRepresentable(layer: layer)
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
                .clipShape(shapeView)
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

            if appState.showBorder, appState.borderWidth > 0 {
                borderStrokeView()
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

    private var shapeView: some Shape {
        ShapeTypeShape(shapeType: appState.shapeType, cornerRadius: appState.shapeCornerRadius)
    }

    /// Border stroke only (gradient or solid). Shadow is drawn as a separate layer behind the preview so it stays external.
    /// Drawn on the clip shape so border always matches the visible camera outline (including when zoom < 1).
    @ViewBuilder
    private func borderStrokeView() -> some View {
        let shape = shapeView
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
