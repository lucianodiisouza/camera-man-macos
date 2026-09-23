import AppKit
import AVFoundation
import CoreImage
import QuartzCore
import SwiftUI

/// Hosts the camera's preview layer. Brightness, contrast and saturation are a Core Image filter on the layer, so the
/// window server applies them on the GPU instead of the app filtering every frame on the CPU.
struct CameraPreviewRepresentable: NSViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer
    var brightness: Double = 0
    var contrast: Double = 1
    var saturation: Double = 1

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.layerUsesCoreImageFilters = true
        view.previewLayer = layer
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = CGRect(origin: .zero, size: view.bounds.size)
        CATransaction.commit()
        view.layer = layer
        view.wantsLayer = true
        view.appliedColorControls = [brightness, contrast, saturation]
        applyColorControls(to: layer)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        guard let layer = nsView.previewLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = nsView.frame
        // Rebuilding the filter makes the window server recompile it; only do that when a value changed.
        let values = [brightness, contrast, saturation]
        if nsView.appliedColorControls != values {
            nsView.appliedColorControls = values
            applyColorControls(to: layer)
        }
        CATransaction.commit()
    }

    private func applyColorControls(to layer: CALayer) {
        let isNeutral = brightness == 0 && contrast == 1 && saturation == 1
        guard !isNeutral, let filter = CIFilter(name: "CIColorControls") else {
            layer.filters = nil
            return
        }
        filter.setDefaults()
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        filter.setValue(saturation, forKey: kCIInputSaturationKey)
        layer.filters = [filter]
    }
}

final class CameraPreviewNSView: NSView {
    /// Brightness, contrast and saturation the layer's filter was last built with.
    var appliedColorControls: [Double]?

    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            if let layer = previewLayer {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                layer.frame = CGRect(origin: .zero, size: bounds.size)
                CATransaction.commit()
                self.layer?.addSublayer(layer)
            }
        }
    }

    override func layout() {
        super.layout()
        guard let layer = previewLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Use view's frame in superview so the layer stays aligned when window resizes (toggle size).
        layer.frame = frame
        CATransaction.commit()
    }
}
