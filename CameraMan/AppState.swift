import SwiftUI
import Combine

final class AppState: ObservableObject {
    // MARK: - Camera
    @Published var selectedDeviceId: String?
    @Published var videoDevices: [CameraDevice] = []
    @Published var cameraStatus: CameraStatus = .loading

    // MARK: - Shape & transform
    @Published var shapeType: ShapeType = .circle
    @Published var shapeCornerRadius: CGFloat = 0
    @Published var offsetX: Double = 0
    @Published var offsetY: Double = 0
    @Published var scale: Double = 1.0
    @Published var flipHorizontal: Bool = false
    @Published var flipVertical: Bool = false

    // MARK: - Border (default sem borda — só shape + câmera)
    @Published var showBorder: Bool = false
    @Published var borderWidth: CGFloat = 0
    @Published var borderColor: Color = .accentColor
    @Published var borderUseGradient: Bool = false
    @Published var borderGradientStartColor: Color = .blue
    @Published var borderGradientEndColor: Color = .purple
    // MARK: - Shadow (independente da borda — pode ter só sombra)
    @Published var showShadow: Bool = false
    @Published var borderShadowRadius: CGFloat = 0
    @Published var borderShadowColor: Color = .black.opacity(0.5)

    // MARK: - Window
    @Published var windowSizePreset: WindowSizePreset = .small
    @Published var screenEdge: ScreenEdge = .topLeft
    @Published var selectedDisplayId: CGDirectDisplayID?
    @Published var isWindowVisible: Bool = true

    // MARK: - UI
    @Published var showSettings: Bool = false
    @Published var toastMessage: String?
    @Published var showResetConfirmation: Bool = false

    // MARK: - Constants
    static let scaleRange: ClosedRange<Double> = 1.0...2.0
    static let offsetRange: ClosedRange<Double> = -50...50
    static let borderWidthRange: ClosedRange<CGFloat> = 0...20
    static let borderShadowRadiusRange: ClosedRange<CGFloat> = 0...24
    static let shapeCornerRadiusRange: ClosedRange<CGFloat> = 0...150

    private let defaults = UserDefaults.standard
    private let defaultsKeys = DefaultsKeys()

    struct DefaultsKeys {
        let selectedDeviceId = "selectedDeviceId"
        let shapeType = "shapeType"
        let shapeCornerRadius = "shapeCornerRadius"
        let offsetX = "offsetX"
        let offsetY = "offsetY"
        let scale = "scale"
        let flipHorizontal = "flipHorizontal"
        let flipVertical = "flipVertical"
        let showBorder = "showBorder"
        let showShadow = "showShadow"
        let borderWidth = "borderWidth"
        let borderColorRed = "borderColorRed"
        let borderColorGreen = "borderColorGreen"
        let borderColorBlue = "borderColorBlue"
        let borderUseGradient = "borderUseGradient"
        let borderGradientStartHex = "borderGradientStartHex"
        let borderGradientEndHex = "borderGradientEndHex"
        let borderShadowRadius = "borderShadowRadius"
        let borderShadowColorHex = "borderShadowColorHex"
        let windowSizePreset = "windowSizePreset"
        let screenEdge = "screenEdge"
    }

    init() {
        loadFromUserDefaults()
    }

    func loadFromUserDefaults() {
        if let id = defaults.string(forKey: defaultsKeys.selectedDeviceId) { selectedDeviceId = id }
        if let raw = defaults.string(forKey: defaultsKeys.shapeType) {
            if let shape = ShapeType(rawValue: raw) {
                shapeType = shape
            } else if raw == "rectangle" {
                shapeType = .square
            } else if raw == "roundedRectangle" {
                shapeType = .horizontalRectangle
            }
        }
        shapeCornerRadius = CGFloat(defaults.double(forKey: defaultsKeys.shapeCornerRadius))
        offsetX = defaults.double(forKey: defaultsKeys.offsetX)
        offsetY = defaults.double(forKey: defaultsKeys.offsetY)
        scale = defaults.double(forKey: defaultsKeys.scale)
        if scale < 1.0 { scale = 1.0 }
        flipHorizontal = defaults.bool(forKey: defaultsKeys.flipHorizontal)
        flipVertical = defaults.bool(forKey: defaultsKeys.flipVertical)
        showBorder = defaults.object(forKey: defaultsKeys.showBorder) as? Bool ?? false
        showShadow = defaults.object(forKey: defaultsKeys.showShadow) as? Bool ?? false
        borderWidth = CGFloat(defaults.double(forKey: defaultsKeys.borderWidth))
        if let hex = defaults.string(forKey: "borderColorHex") {
            borderColor = Color(hex: hex)
        } else {
            borderColor = .accentColor
        }
        borderUseGradient = defaults.bool(forKey: defaultsKeys.borderUseGradient)
        if let hex = defaults.string(forKey: defaultsKeys.borderGradientStartHex) {
            borderGradientStartColor = Color(hex: hex)
        }
        if let hex = defaults.string(forKey: defaultsKeys.borderGradientEndHex) {
            borderGradientEndColor = Color(hex: hex)
        }
        borderShadowRadius = CGFloat(defaults.double(forKey: defaultsKeys.borderShadowRadius))
        if let hex = defaults.string(forKey: defaultsKeys.borderShadowColorHex) {
            borderShadowColor = Color(hex: hex)
        }
        if let raw = defaults.string(forKey: defaultsKeys.windowSizePreset),
           let preset = WindowSizePreset(rawValue: raw) { windowSizePreset = preset }
        if let raw = defaults.string(forKey: defaultsKeys.screenEdge),
           let edge = ScreenEdge(rawValue: raw) { screenEdge = edge }
    }

    func saveToUserDefaults() {
        defaults.set(selectedDeviceId, forKey: defaultsKeys.selectedDeviceId)
        defaults.set(shapeType.rawValue, forKey: defaultsKeys.shapeType)
        defaults.set(Double(shapeCornerRadius), forKey: defaultsKeys.shapeCornerRadius)
        defaults.set(offsetX, forKey: defaultsKeys.offsetX)
        defaults.set(offsetY, forKey: defaultsKeys.offsetY)
        defaults.set(scale, forKey: defaultsKeys.scale)
        defaults.set(flipHorizontal, forKey: defaultsKeys.flipHorizontal)
        defaults.set(flipVertical, forKey: defaultsKeys.flipVertical)
        defaults.set(showBorder, forKey: defaultsKeys.showBorder)
        defaults.set(showShadow, forKey: defaultsKeys.showShadow)
        defaults.set(Double(borderWidth), forKey: defaultsKeys.borderWidth)
        defaults.set(borderColor.hex, forKey: "borderColorHex")
        defaults.set(borderUseGradient, forKey: defaultsKeys.borderUseGradient)
        defaults.set(borderGradientStartColor.hex, forKey: defaultsKeys.borderGradientStartHex)
        defaults.set(borderGradientEndColor.hex, forKey: defaultsKeys.borderGradientEndHex)
        defaults.set(Double(borderShadowRadius), forKey: defaultsKeys.borderShadowRadius)
        defaults.set(borderShadowColor.hex, forKey: defaultsKeys.borderShadowColorHex)
        defaults.set(windowSizePreset.rawValue, forKey: defaultsKeys.windowSizePreset)
        defaults.set(screenEdge.rawValue, forKey: defaultsKeys.screenEdge)
    }

    func resetToDefaults() {
        selectedDeviceId = nil
        shapeType = .circle
        shapeCornerRadius = 0
        offsetX = 0
        offsetY = 0
        scale = 1.0
        flipHorizontal = false
        flipVertical = false
        showBorder = false
        borderWidth = 0
        borderColor = .accentColor
        borderUseGradient = false
        borderGradientStartColor = .blue
        borderGradientEndColor = .purple
        showShadow = false
        borderShadowRadius = 0
        borderShadowColor = .black.opacity(0.5)
        windowSizePreset = .small
        screenEdge = .topLeft
        saveToUserDefaults()
    }

    func cycleShape() {
        let all = ShapeType.allCases
        guard let idx = all.firstIndex(of: shapeType) else { return }
        shapeType = all[(idx + 1) % all.count]
        saveToUserDefaults()
    }

    func adjustOffset(dx: Double, dy: Double) {
        offsetX = min(max(offsetX + dx, Self.offsetRange.lowerBound), Self.offsetRange.upperBound)
        offsetY = min(max(offsetY + dy, Self.offsetRange.lowerBound), Self.offsetRange.upperBound)
        saveToUserDefaults()
    }

    func zoomIn() {
        scale = min(scale + 0.1, Self.scaleRange.upperBound)
        saveToUserDefaults()
    }

    func zoomOut() {
        scale = max(scale - 0.1, Self.scaleRange.lowerBound)
        saveToUserDefaults()
    }

    func resetZoom() {
        scale = 1.0
        saveToUserDefaults()
    }

    func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.toastMessage = nil
        }
    }
}

enum CameraStatus: Equatable {
    case loading
    case notFound
    case connected
    case disconnected
}

struct CameraDevice: Identifiable {
    let id: String
    let name: String
}

enum WindowSizePreset: String, CaseIterable, Identifiable {
    case small
    case large

    var id: String { rawValue }

    var width: CGFloat {
        switch self {
        case .small: return 300
        case .large: return 600
        }
    }

    var height: CGFloat {
        switch self {
        case .small: return 300
        case .large: return 600
        }
    }

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .large: return "Large"
        }
    }
}

enum ScreenEdge: String, CaseIterable, Identifiable {
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomRight: return "Bottom Right"
        case .bottomLeft: return "Bottom Left"
        }
    }
}
