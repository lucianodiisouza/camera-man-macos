import AVFoundation
import Combine
import CoreImage
import SwiftUI

final class CameraService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session")
    private let videoOutputQueue = DispatchQueue(label: "camera.videoOutput")
    private var currentInput: AVCaptureDeviceInput?
    private var deviceDiscoverySession: AVCaptureDevice.DiscoverySession?
    private lazy var ciContext: CIContext = CIContext(options: [.useSoftwareRenderer: false])

    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    /// Frame atual com correção de cor aplicada (nil até o primeiro frame).
    @Published var currentFrame: CGImage?
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
        session.sessionPreset = .medium

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()
        refreshDeviceList()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let b = appState?.brightness ?? 0
        let c = appState?.contrast ?? 1.0
        let s = appState?.saturation ?? 1.0
        let inputImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let filter = CIFilter(name: "CIColorControls") else { return }
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(b, forKey: kCIInputBrightnessKey)
        filter.setValue(c, forKey: kCIInputContrastKey)
        filter.setValue(s, forKey: kCIInputSaturationKey)
        guard let outputImage = filter.outputImage else { return }
        let extent = outputImage.extent
        guard extent.width > 0, extent.height > 0 else { return }
        guard let cgImage = ciContext.createCGImage(outputImage, from: extent) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.currentFrame = cgImage
        }
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

    /// Pause capture when window is minimized to save CPU and power.
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
