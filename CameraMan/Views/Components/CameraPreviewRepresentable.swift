import AppKit
import AVFoundation
import QuartzCore
import SwiftUI

/// Exibe um frame de vídeo (CGImage) com aspect fill — usado quando correção de cor está ativa.
struct FilteredCameraPreviewView: View {
    let cgImage: CGImage

    var body: some View {
        Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

struct CameraPreviewRepresentable: NSViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.previewLayer = layer
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = CGRect(origin: .zero, size: view.bounds.size)
        CATransaction.commit()
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        guard let layer = nsView.previewLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = nsView.frame
        CATransaction.commit()
    }
}

final class CameraPreviewNSView: NSView {
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
