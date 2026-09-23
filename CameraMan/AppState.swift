import SwiftUI
import Combine

final class AppState: ObservableObject {
    // MARK: - Camera
    @Published var selectedDeviceId: String?
    @Published var videoDevices: [CameraDevice] = []
    @Published var cameraStatus: CameraStatus = .loading
    /// nil = not determined yet, true = user accepted, false = denied. Only show camera shape when true.
    @Published var cameraPermissionGranted: Bool? = nil

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

    // MARK: - Color correction (aplicado ao vídeo em tempo real)
    @Published var brightness: Double = 0
    @Published var contrast: Double = 1.0
    @Published var saturation: Double = 1.0

    // MARK: - Window
    @Published var windowSizePreset: WindowSizePreset = .md
    @Published var screenEdge: ScreenEdge = .topLeft
    /// Posição da janela por tamanho: cada preset (xs/sm/md/lg/full) lembra sua própria posição.
    @Published var screenEdgeForPreset: [String: ScreenEdge] = [:]
    /// Posição exata da janela por preset (quando o usuário arrasta). Nil = usar screen edge.
    @Published var originForPreset: [String: CGPoint] = [:]
    /// Slots para a tecla Space: alterna apenas entre estes dois tamanhos.
    @Published var spaceSlot1: WindowSizePreset = .sm
    @Published var spaceSlot2: WindowSizePreset = .lg
    @Published var selectedDisplayId: CGDirectDisplayID?
    @Published var isWindowVisible: Bool = true

    // MARK: - UI
    @Published var toastMessage: String?

    // MARK: - Constants
    static let scaleRange: ClosedRange<Double> = 1.0...2.0
    static let offsetRange: ClosedRange<Double> = -50...50
    static let borderWidthRange: ClosedRange<CGFloat> = 0...20
    static let borderShadowRadiusRange: ClosedRange<CGFloat> = 0...24
    static let shapeCornerRadiusRange: ClosedRange<CGFloat> = 0...150
    static let brightnessRange: ClosedRange<Double> = -0.5...0.5
    static let contrastRange: ClosedRange<Double> = 0.5...2.0
    static let saturationRange: ClosedRange<Double> = 0...2.0

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
        let brightness = "brightness"
        let contrast = "contrast"
        let saturation = "saturation"
        let windowSizePreset = "windowSizePreset"
        let screenEdge = "screenEdge"
        func screenEdgeKey(_ preset: String) -> String { "screenEdge_\(preset)" }
        func hasOriginKey(_ preset: String) -> String { "hasOrigin_\(preset)" }
        func originXKey(_ preset: String) -> String { "originX_\(preset)" }
        func originYKey(_ preset: String) -> String { "originY_\(preset)" }
        // Legacy keys for migration from small/large
        let screenEdgeForSmall = "screenEdgeForSmall"
        let screenEdgeForLarge = "screenEdgeForLarge"
        let hasOriginForSmall = "hasOriginForSmall"
        let originSmallX = "originSmallX"
        let originSmallY = "originSmallY"
        let hasOriginForLarge = "hasOriginForLarge"
        let originLargeX = "originLargeX"
        let originLargeY = "originLargeY"
        let spaceSlot1 = "spaceSlot1"
        let spaceSlot2 = "spaceSlot2"
        let cameraPermissionGranted = "cameraPermissionGranted"
    }

    init() {
        loadFromUserDefaults()
    }

    func loadFromUserDefaults() {
        if let id = defaults.string(forKey: defaultsKeys.selectedDeviceId) { selectedDeviceId = id }
        if defaults.object(forKey: defaultsKeys.cameraPermissionGranted) as? Bool == true {
            cameraPermissionGranted = true
        }
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
        brightness = defaults.object(forKey: defaultsKeys.brightness) as? Double ?? 0
        contrast = defaults.object(forKey: defaultsKeys.contrast) as? Double ?? 1.0
        saturation = defaults.object(forKey: defaultsKeys.saturation) as? Double ?? 1.0
        if let raw = defaults.string(forKey: defaultsKeys.windowSizePreset) {
            if let preset = WindowSizePreset(rawValue: raw) {
                windowSizePreset = preset
            } else if raw == "small" {
                windowSizePreset = .sm
            } else if raw == "large" {
                windowSizePreset = .lg
            }
        }
        let fallbackEdge: ScreenEdge = (defaults.string(forKey: defaultsKeys.screenEdge).flatMap { ScreenEdge(rawValue: $0) }) ?? .topLeft
        for preset in WindowSizePreset.allCases {
            let key = preset.rawValue
            let edgeRaw = defaults.string(forKey: defaultsKeys.screenEdgeKey(key))
                ?? (preset == .sm ? defaults.string(forKey: defaultsKeys.screenEdgeForSmall) : nil)
                ?? (preset == .lg ? defaults.string(forKey: defaultsKeys.screenEdgeForLarge) : nil)
            screenEdgeForPreset[key] = (edgeRaw.flatMap { ScreenEdge(rawValue: $0) }) ?? fallbackEdge
            let hasOrigin: Bool
            let ox: Double, oy: Double
            if key == "sm" {
                hasOrigin = defaults.bool(forKey: defaultsKeys.hasOriginForSmall)
                ox = defaults.double(forKey: defaultsKeys.originSmallX)
                oy = defaults.double(forKey: defaultsKeys.originSmallY)
            } else if key == "lg" {
                hasOrigin = defaults.bool(forKey: defaultsKeys.hasOriginForLarge)
                ox = defaults.double(forKey: defaultsKeys.originLargeX)
                oy = defaults.double(forKey: defaultsKeys.originLargeY)
            } else {
                hasOrigin = defaults.bool(forKey: defaultsKeys.hasOriginKey(key))
                ox = defaults.double(forKey: defaultsKeys.originXKey(key))
                oy = defaults.double(forKey: defaultsKeys.originYKey(key))
            }
            if hasOrigin { originForPreset[key] = CGPoint(x: ox, y: oy) }
        }
        if let raw = defaults.string(forKey: defaultsKeys.spaceSlot1),
           let p = WindowSizePreset(rawValue: raw) { spaceSlot1 = p }
        if let raw = defaults.string(forKey: defaultsKeys.spaceSlot2),
           let p = WindowSizePreset(rawValue: raw) { spaceSlot2 = p }
        screenEdge = screenEdge(for: windowSizePreset)
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
        defaults.set(brightness, forKey: defaultsKeys.brightness)
        defaults.set(contrast, forKey: defaultsKeys.contrast)
        defaults.set(saturation, forKey: defaultsKeys.saturation)
        defaults.set(windowSizePreset.rawValue, forKey: defaultsKeys.windowSizePreset)
        defaults.set(screenEdge.rawValue, forKey: defaultsKeys.screenEdge)
        for preset in WindowSizePreset.allCases {
            let key = preset.rawValue
            defaults.set((screenEdgeForPreset[key] ?? .topLeft).rawValue, forKey: defaultsKeys.screenEdgeKey(key))
            if let o = originForPreset[key] {
                defaults.set(true, forKey: defaultsKeys.hasOriginKey(key))
                defaults.set(Double(o.x), forKey: defaultsKeys.originXKey(key))
                defaults.set(Double(o.y), forKey: defaultsKeys.originYKey(key))
            } else {
                defaults.set(false, forKey: defaultsKeys.hasOriginKey(key))
            }
        }
        defaults.set(spaceSlot1.rawValue, forKey: defaultsKeys.spaceSlot1)
        defaults.set(spaceSlot2.rawValue, forKey: defaultsKeys.spaceSlot2)
        if cameraPermissionGranted == true {
            defaults.set(true, forKey: defaultsKeys.cameraPermissionGranted)
        }
    }

    /// Call when the user has accepted camera permission (persists so we remember on next launch).
    func didGrantCameraPermission() {
        cameraPermissionGranted = true
        defaults.set(true, forKey: defaultsKeys.cameraPermissionGranted)
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
        brightness = 0
        contrast = 1.0
        saturation = 1.0
        windowSizePreset = .md
        screenEdge = .topLeft
        screenEdgeForPreset = [:]
        originForPreset = [:]
        spaceSlot1 = .sm
        spaceSlot2 = .lg
        saveToUserDefaults()
    }

    /// Preset para o qual alternar ao apertar Space (o outro slot).
    func spaceToggleTargetPreset() -> WindowSizePreset {
        windowSizePreset == spaceSlot1 ? spaceSlot2 : spaceSlot1
    }

    /// Posição salva para o preset dado (usado ao alternar de tamanho).
    func screenEdge(for preset: WindowSizePreset) -> ScreenEdge {
        screenEdgeForPreset[preset.rawValue] ?? .topLeft
    }

    /// Altera o tamanho da janela e restaura a posição salva para esse tamanho.
    func setWindowSizePreset(_ preset: WindowSizePreset) {
        windowSizePreset = preset
        screenEdge = screenEdge(for: preset)
        saveToUserDefaults()
    }

    /// Define a posição na tela para o tamanho atual (e persiste para esse tamanho).
    /// Remove a posição exata salva para esse preset, para que passe a usar o canto.
    func setScreenEdge(_ edge: ScreenEdge) {
        screenEdge = edge
        screenEdgeForPreset[windowSizePreset.rawValue] = edge
        originForPreset.removeValue(forKey: windowSizePreset.rawValue)
        saveToUserDefaults()
    }

    /// Retorna a posição exata salva para o preset, ou nil se deve usar o canto (screen edge).
    func origin(for preset: WindowSizePreset) -> CGPoint? {
        originForPreset[preset.rawValue]
    }

    /// Salva a posição atual da janela como referência do tamanho atual (chamado ao arrastar a janela).
    func setOriginForCurrentPreset(_ point: CGPoint) {
        originForPreset[windowSizePreset.rawValue] = point
        saveToUserDefaults()
    }

    /// Origem a usar ao aplicar o preset: posição salva (clampada ao ecrã) ou canto conforme edge.
    func originToApply(for preset: WindowSizePreset, visibleFrame: CGRect, windowSize: CGSize) -> CGPoint {
        if let custom = origin(for: preset) {
            let maxX = visibleFrame.maxX - windowSize.width
            let maxY = visibleFrame.maxY - windowSize.height
            let x = min(max(custom.x, visibleFrame.minX), maxX)
            let y = min(max(custom.y, visibleFrame.minY), maxY)
            return CGPoint(x: x, y: y)
        }
        let edge = screenEdge(for: preset)
        switch edge {
        case .topLeft:
            return CGPoint(x: visibleFrame.minX, y: visibleFrame.maxY - windowSize.height)
        case .topRight:
            return CGPoint(x: visibleFrame.maxX - windowSize.width, y: visibleFrame.maxY - windowSize.height)
        case .bottomRight:
            return CGPoint(x: visibleFrame.maxX - windowSize.width, y: visibleFrame.minY)
        case .bottomLeft:
            return CGPoint(x: visibleFrame.minX, y: visibleFrame.minY)
        }
    }

    /// Sincroniza `screenEdge` com a posição salva do preset atual (ex.: após trocar de tamanho pelo Picker).
    func syncScreenEdgeToPreset() {
        screenEdge = screenEdge(for: windowSizePreset)
    }

    func cycleShape() {
        let shapes = ShapeType.allCases
        let idx = shapes.firstIndex(of: shapeType) ?? 0
        shapeType = shapes[(idx + 1) % shapes.count]
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
    case xs
    case sm
    case md
    case lg
    case full

    var id: String { rawValue }

    /// Tamanho fixo para xs/sm/md/lg; para full usa o visibleFrame quando disponível.
    func size(visibleFrame: CGRect?) -> CGSize {
        switch self {
        case .xs: return CGSize(width: 200, height: 200)
        case .sm: return CGSize(width: 300, height: 300)
        case .md: return CGSize(width: 400, height: 400)
        case .lg: return CGSize(width: 560, height: 560)
        case .full:
            if let f = visibleFrame, f.width > 0, f.height > 0 {
                return f.size
            }
            return CGSize(width: 960, height: 720)
        }
    }

    var width: CGFloat { size(visibleFrame: nil).width }
    var height: CGFloat { size(visibleFrame: nil).height }

    var displayName: String {
        switch self {
        case .xs: return "Extra Small"
        case .sm: return "Small"
        case .md: return "Medium"
        case .lg: return "Large"
        case .full: return "Full"
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
