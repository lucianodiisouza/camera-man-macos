import SwiftUI

/// User-created shape: either from the organic randomizer or (legacy) freeform points.
struct CustomShape: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var points: [CGPoint]  // normalized 0...1 (bounding box)
    var smoothness: Double // 0...1, used for path smoothing (high = more Bezier-like)

    /// Generates points for a smooth organic blob (Bezier-friendly, no sharp spikes).
    /// Uses radial variation with smooth harmonics so the result is always rounded, with curvy corners.
    static func randomOrganicPoints(numPoints: Int = 14) -> [CGPoint] {
        let n = max(10, min(22, numPoints))
        let angleStep = (2 * Double.pi) / Double(n)
        var radii: [Double] = []
        // Base radius + smooth harmonics (no sharp angles — no high-frequency spikes)
        let r0 = 0.42 + Double.random(in: -0.04...0.04)
        let h2a = Double.random(in: -0.06...0.06)
        let h2b = Double.random(in: -0.06...0.06)
        let h3a = Double.random(in: -0.04...0.04)
        let h3b = Double.random(in: -0.04...0.04)
        let h4a = Double.random(in: -0.02...0.02)
        let h4b = Double.random(in: -0.02...0.02)
        for i in 0..<n {
            let angle = angleStep * Double(i) + Double.random(in: -0.015...0.015)
            let r = r0
                + h2a * cos(2 * angle) + h2b * sin(2 * angle)
                + h3a * cos(3 * angle) + h3b * sin(3 * angle)
                + h4a * cos(4 * angle) + h4b * sin(4 * angle)
            radii.append(max(0.15, r))
        }
        var points = (0..<n).map { i in
            let angle = angleStep * Double(i)
            return CGPoint(
                x: 0.5 + radii[i] * cos(angle),
                y: 0.5 + radii[i] * sin(angle)
            )
        }
        // Normalize to bounding box 0...1 (path convention: y=0 top, y=1 bottom)
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 1
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 1
        let w = max(maxX - minX, 1e-6)
        let h = max(maxY - minY, 1e-6)
        points = points.map { p in
            CGPoint(x: (p.x - minX) / w, y: (p.y - minY) / h)
        }
        return points
    }

    init(id: UUID = UUID(), name: String, points: [CGPoint], smoothness: Double = 0.5) {
        self.id = id
        self.name = name
        self.points = points
        self.smoothness = smoothness
    }

    /// Encodes points as [x,y,x,y,...] for Codable (CGPoint is not Codable by default).
    enum CodingKeys: String, CodingKey {
        case id, name, pointsX, pointsY, smoothness
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        let xs = try c.decode([CGFloat].self, forKey: .pointsX)
        let ys = try c.decode([CGFloat].self, forKey: .pointsY)
        points = zip(xs, ys).map { CGPoint(x: $0, y: $1) }
        smoothness = try c.decodeIfPresent(Double.self, forKey: .smoothness) ?? 0.5
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(points.map(\.x), forKey: .pointsX)
        try c.encode(points.map(\.y), forKey: .pointsY)
        try c.encode(smoothness, forKey: .smoothness)
    }

    /// Builds a closed, optionally smoothed path in the given rect (points are 0...1).
    func path(in rect: CGRect) -> Path {
        guard points.count >= 2 else { return Path() }
        var path = Path()
        let scaleX = rect.width
        let scaleY = rect.height
        let origin = rect.origin

        func pt(_ p: CGPoint) -> CGPoint {
            CGPoint(x: origin.x + p.x * scaleX, y: origin.y + (1 - p.y) * scaleY)
        }

        func addClosedPathWithRoundedCorners(to path: inout Path, points: [CGPoint], pt: (CGPoint) -> CGPoint) {
            let n = points.count
            guard n >= 2 else { return }
            // Corner radius in normalized 0...1 space (suave, proporcional ao tamanho do shape)
            let rNorm: CGFloat = 0.045
            func len(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
                hypot(b.x - a.x, b.y - a.y)
            }
            func dir(_ from: CGPoint, _ to: CGPoint) -> (CGFloat, CGFloat) {
                let d = len(from, to)
                guard d > 1e-6 else { return (0, 0) }
                return ((to.x - from.x) / d, (to.y - from.y) / d)
            }
            func approach(to p: CGPoint, from prev: CGPoint, radius: CGFloat) -> CGPoint {
                let (dx, dy) = dir(prev, p)
                let d = min(radius, len(prev, p) / 2)
                return CGPoint(x: p.x - dx * d, y: p.y - dy * d)
            }
            func exit(from p: CGPoint, toward next: CGPoint, radius: CGFloat) -> CGPoint {
                let (dx, dy) = dir(p, next)
                let d = min(radius, len(p, next) / 2)
                return CGPoint(x: p.x + dx * d, y: p.y + dy * d)
            }
            let cur = points[0]
            let next = points[1]
            path.move(to: pt(exit(from: cur, toward: next, radius: rNorm)))
            for i in 1..<n {
                let prev = points[i - 1]
                let cur = points[i]
                let next = points[(i + 1) % n]
                let a = approach(to: cur, from: prev, radius: rNorm)
                let b = exit(from: cur, toward: next, radius: rNorm)
                path.addLine(to: pt(a))
                path.addQuadCurve(to: pt(b), control: pt(cur))
            }
            let a0 = approach(to: points[0], from: points[n - 1], radius: rNorm)
            let b0 = exit(from: points[0], toward: points[1], radius: rNorm)
            path.addLine(to: pt(a0))
            path.addQuadCurve(to: pt(b0), control: pt(points[0]))
            path.closeSubpath()
        }

        if smoothness > 0.01, points.count >= 3, let last = points.last {
            // Catmull-Rom style smooth curve through points (closed). Higher tension = rounder corners.
            let closed = [last] + points + [points[0], points[1], points[2]]
            path.move(to: pt(points[0]))
            let tension: CGFloat = 0.45 + CGFloat(1 - smoothness) * 0.4  // rounder corners (was 0.25..0.75)
            for j in 1...points.count {
                let p0 = closed[j - 1]
                let p1 = closed[j]
                let p2 = closed[j + 1]
                let p3 = closed[j + 2]
                let cp1 = CGPoint(
                    x: p1.x + (p2.x - p0.x) / 6 * tension,
                    y: p1.y + (p2.y - p0.y) / 6 * tension
                )
                let cp2 = CGPoint(
                    x: p2.x - (p3.x - p1.x) / 6 * tension,
                    y: p2.y - (p3.y - p1.y) / 6 * tension
                )
                path.addCurve(to: pt(p2), control1: pt(cp1), control2: pt(cp2))
            }
        } else {
            // Rounded corners: at each vertex add a small arc so no sharp "recorte" look.
            addClosedPathWithRoundedCorners(to: &path, points: points, pt: pt)
        }
        return path
    }
}

/// SwiftUI Shape that draws a CustomShape in the given rect.
struct CustomShapeView: Shape {
    let customShape: CustomShape

    func path(in rect: CGRect) -> Path {
        customShape.path(in: rect)
    }
}
