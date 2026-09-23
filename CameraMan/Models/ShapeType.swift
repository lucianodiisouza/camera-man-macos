import SwiftUI

enum ShapeType: String, CaseIterable, Identifiable, Codable {
    case circle
    case organic
    case square
    case verticalRectangle  // 9:16
    case horizontalRectangle // 16:9

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .circle: return "Circle"
        case .organic: return "Organic"
        case .square: return "Square"
        case .verticalRectangle: return "Vertical Rectangle (9:16)"
        case .horizontalRectangle: return "Horizontal Rectangle (16:9)"
        }
    }

    /// Fits under a preview card in the settings window.
    var shortName: String {
        switch self {
        case .circle: return "Circle"
        case .organic: return "Organic"
        case .square: return "Square"
        case .verticalRectangle: return "Vertical 9:16"
        case .horizontalRectangle: return "Horizontal 16:9"
        }
    }

    var symbol: String {
        switch self {
        case .circle: return "circle"
        case .organic: return "seal"
        case .square: return "square"
        case .verticalRectangle: return "rectangle.portrait"
        case .horizontalRectangle: return "rectangle"
        }
    }

    func shape(cornerRadius: CGFloat = 20) -> ShapeTypeShape {
        ShapeTypeShape(shapeType: self, cornerRadius: cornerRadius)
    }
}

struct ShapeTypeShape: Shape {
    var shapeType: ShapeType
    var cornerRadius: CGFloat = 20
    var blob: OrganicBlob = .default
    /// Seconds into the breathing motion; 0 holds the organic outline still.
    var time: Double = 0

    func path(in rect: CGRect) -> Path {
        switch shapeType {
        case .organic:
            return blob.path(in: rect, time: time)
        case .circle:
            let side = min(rect.width, rect.height)
            let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
            return Circle().path(in: CGRect(origin: origin, size: CGSize(width: side, height: side)))
        case .square:
            let side = min(rect.width, rect.height)
            let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
            let r = CGRect(origin: origin, size: CGSize(width: side, height: side))
            return roundedRectPath(in: r, cornerRadius: cornerRadius)
        case .verticalRectangle:
            let r = aspectRatioRect(in: rect, widthRatio: 9, heightRatio: 16)
            return roundedRectPath(in: r, cornerRadius: cornerRadius)
        case .horizontalRectangle:
            let r = aspectRatioRect(in: rect, widthRatio: 16, heightRatio: 9)
            return roundedRectPath(in: r, cornerRadius: cornerRadius)
        }
    }

    /// Rounded rectangle path; radius is clamped to half the smallest side so corners stay valid.
    private func roundedRectPath(in rect: CGRect, cornerRadius: CGFloat) -> Path {
        let maxRadius = min(rect.width, rect.height) / 2
        let radius = min(max(cornerRadius, 0), maxRadius)
        return RoundedRectangle(cornerRadius: radius).path(in: rect)
    }

    /// Returns a centered rect with the given aspect ratio (width:height) that fits inside `rect`.
    private func aspectRatioRect(in rect: CGRect, widthRatio: CGFloat, heightRatio: CGFloat) -> CGRect {
        let targetAspect = widthRatio / heightRatio
        let currentAspect = rect.width / rect.height
        var fitSize: CGSize
        if currentAspect > targetAspect {
            // rect is wider than target → limit by height
            fitSize = CGSize(width: rect.height * targetAspect, height: rect.height)
        } else {
            // rect is taller than target → limit by width
            fitSize = CGSize(width: rect.width, height: rect.width / targetAspect)
        }
        let origin = CGPoint(x: rect.midX - fitSize.width / 2, y: rect.midY - fitSize.height / 2)
        return CGRect(origin: origin, size: fitSize)
    }
}
