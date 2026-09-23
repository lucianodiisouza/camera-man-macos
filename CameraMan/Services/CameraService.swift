import AVFoundation
import Combine
import SwiftUI

/// Runs the capture session. Frames go straight to an `AVCaptureVideoPreviewLayer`, so the video is drawn by the GPU
/// and never touches the CPU; color correction is a Core Image filter on that layer (see `CameraPreviewNSView`).
final class CameraService: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session")
    private var currentInput: AVCaptureDeviceInput?
    private var deviceDiscoverySession: AVCaptureDevice.DiscoverySession?

    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var videoDevices: [CameraDevice] = []
    @Published var status: CameraStatus = .loading

    weak var appState: AppState?

    override init() {
        super.init()
        setupDiscoverySession()
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    private func setupDiscoverySession() {
        // .builtInWideAngleCamera covers built-in; .external for USB/webcams.
        // Note: builtInUltraWideCamera is iOS-only; on macOS 0.5x may appear as a separate device or format depending on system.
        deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
    }

    private func configureSession() {
        session.beginConfiguration()
        // The camera's best mode. `.medium` is 480×360 on the Mac, which a Large or Full window on a Retina screen
        // blows up more than twice and shows soft in a recording.
        session.sessionPreset = .high
        session.commitConfiguration()
        refreshDeviceList()
    }

    func refreshDeviceList(completion: (() -> Void)? = nil) {
        guard let discovery = deviceDiscoverySession else { completion?(); return }
        let devices = discovery.devices.map { CameraDevice(id: $0.uniqueID, name: $0.localizedName) }
        DispatchQueue.main.async { [weak self] in
            self?.videoDevices = devices
            self?.appState?.videoDevices = devices
            if devices.isEmpty {
                self?.status = .notFound
                self?.appState?.cameraStatus = .notFound
            } else {
                self?.status = .connected
                self?.appState?.cameraStatus = .connected
            }
            completion?()
        }
    }

    func selectDevice(id: String?) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if let id = id, let device = AVCaptureDevice(uniqueID: id) {
                self.switchToDevice(device)
            } else if id != nil {
                // Saved device not found; fall back to first available on main
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let first = self.videoDevices.first else { return }
                    self.selectDevice(id: first.id)
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let first = self.videoDevices.first else { return }
                    self.selectDevice(id: first.id)
                }
            }
        }
    }

    private func switchToDevice(_ device: AVCaptureDevice) {
        session.beginConfiguration()
        if let old = currentInput {
            session.removeInput(old)
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            // A preset the new camera cannot do would stop the session.
            session.sessionPreset = device.supportsSessionPreset(.high) ? .high : .medium
            if session.canAddInput(input) {
                session.addInput(input)
                currentInput = input
                DispatchQueue.main.async { [weak self] in
                    self?.appState?.selectedDeviceId = device.uniqueID
                    self?.appState?.showToast(device.localizedName)
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.status = .notFound
                self?.appState?.cameraStatus = .notFound
            }
        }
        session.commitConfiguration()
    }

    func cycleToNextDevice() {
        let devices = videoDevices
        guard !devices.isEmpty else { return }
        let currentId = appState?.selectedDeviceId
        let idx = devices.firstIndex { $0.id == currentId } ?? -1
        let nextIdx = (idx + 1) % devices.count
        selectDevice(id: devices[nextIdx].id)
    }

    /// Preferred device id and fallback list (from main) so we add an input before starting the session.
    func startPreviewLayer(size: CGSize, preferredDeviceId: String?, deviceIds: [String]) -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = CGRect(origin: .zero, size: size)
        sessionQueue.async { [weak self] in
            self?.ensureInputThenStart(preferredDeviceId: preferredDeviceId, deviceIds: deviceIds)
        }
        DispatchQueue.main.async { [weak self] in
            self?.previewLayer = layer
        }
        return layer
    }

    /// Run on session queue: add input if missing, then start the session so the camera appears immediately.
    private func ensureInputThenStart(preferredDeviceId: String?, deviceIds: [String]) {
        if currentInput == nil, !deviceIds.isEmpty {
            let idToUse = preferredDeviceId.flatMap { preferred in deviceIds.contains(preferred) ? preferred : deviceIds.first } ?? deviceIds.first
            if let id = idToUse, let device = AVCaptureDevice(uniqueID: id) {
                switchToDevice(device)
            }
        }
        session.startRunning()
    }

    /// Stops capture while the window is hidden or minimized, which also turns the camera light off.
    func pause() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    /// Resume capture when window is visible again.
    func resume() {
        sessionQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }

    func requestPermissionAndSetup(completion: (() -> Void)? = nil) {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .authorized:
            appState?.didGrantCameraPermission()
            if videoDevices.isEmpty {
                refreshDeviceList { [weak self] in
                    self?.selectDeviceAfterRefresh()
                    completion?()
                }
            } else {
                selectDeviceAfterRefresh()
                completion?()
            }
        case .notDetermined:
            appState?.cameraPermissionGranted = nil
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.appState?.didGrantCameraPermission()
                        self?.refreshDeviceList { [weak self] in
                            self?.selectDeviceAfterRefresh()
                            completion?()
                        }
                    } else {
                        self?.appState?.cameraPermissionGranted = false
                        self?.status = .notFound
                        self?.appState?.cameraStatus = .notFound
                        completion?()
                    }
                }
            }
        case .denied, .restricted:
            appState?.cameraPermissionGranted = false
            status = .notFound
            appState?.cameraStatus = .notFound
            completion?()
        @unknown default:
            appState?.cameraPermissionGranted = false
            status = .notFound
            appState?.cameraStatus = .notFound
            completion?()
        }
    }

    private func selectDeviceAfterRefresh() {
        if appState?.selectedDeviceId == nil, let first = videoDevices.first {
            selectDevice(id: first.id)
        } else if let id = appState?.selectedDeviceId {
            selectDevice(id: id)
        }
    }
}
