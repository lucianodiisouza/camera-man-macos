import SwiftUI

/// A soft, organic outline: a circle whose radius wobbles gently with the angle.
///
/// The outline is the function `r(θ) = 1 + Σ amplitude·cos(k·θ + phase)` for a few low harmonics k, drawn by sampling
/// it densely. Low harmonics can only make gentle, round bumps, and sampling the function itself (rather than
/// threading a curve through a handful of points) leaves no corners anywhere, at any size.
struct OrganicBlob: Codable, Equatable {
    /// One wave around the outline: `k` bumps, how deep they are, and where they sit.
    struct Wave: Codable, Equatable {
        var k: Int
        var amplitude: Double
        var phase: Double
    }

    var waves: [Wave]

    /// Radius at angle θ. `time` shifts each wave at its own pace, which makes the outline breathe.
    func radius(at theta: Double, time: Double = 0) -> Double {
        waves.reduce(1) { r, w in
            r + w.amplitude * cos(Double(w.k) * theta + w.phase + time * Self.breathingSpeed(for: w.k))
        }
    }

    /// Slow, and different per wave, so the motion never visibly repeats.
    private static func breathingSpeed(for k: Int) -> Double {
        switch k {
        case 2: return 0.45
        case 3: return -0.32
        default: return 0.21
        }
    }

    /// The outline fitted inside `rect`, centred, keeping its proportions.
    func path(in rect: CGRect, time: Double = 0) -> Path {
        let samples = 240
        let radii = (0..<samples).map { radius(at: 2 * .pi * Double($0) / Double(samples), time: time) }
        let scale = min(rect.width, rect.height) / 2 / (radii.max() ?? 1)
        var path = Path()
        for (i, r) in radii.enumerated() {
            let theta = 2 * .pi * Double(i) / Double(samples)
            let point = CGPoint(x: rect.midX + r * scale * cos(theta), y: rect.midY + r * scale * sin(theta))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Presets

    /// Hand-tuned so they stay close to round: a face and shoulders always fit, nothing gets pinched.
    static let presets: [(name: String, blob: OrganicBlob)] = [
        ("Pebble", OrganicBlob(waves: [.init(k: 2, amplitude: 0.055, phase: 0.3), .init(k: 3, amplitude: 0.025, phase: 2.1)])),
        ("Cloud", OrganicBlob(waves: [.init(k: 3, amplitude: 0.04, phase: 1.6), .init(k: 5, amplitude: 0.018, phase: 0.4)])),
        ("Bean", OrganicBlob(waves: [.init(k: 2, amplitude: 0.075, phase: 2.6), .init(k: 3, amplitude: 0.035, phase: 0.9)])),
        ("Drop", OrganicBlob(waves: [.init(k: 1, amplitude: 0.06, phase: -1.57), .init(k: 2, amplitude: 0.035, phase: 0), .init(k: 3, amplitude: 0.015, phase: 1.2)])),
        ("Wave", OrganicBlob(waves: [.init(k: 2, amplitude: 0.035, phase: 1.0), .init(k: 4, amplitude: 0.022, phase: 0.2), .init(k: 5, amplitude: 0.01, phase: 2.4)])),
    ]

    static let `default` = presets[0].blob

    /// A new blob in the same gentle range as the presets.
    static func random() -> OrganicBlob {
        OrganicBlob(waves: [
            .init(k: 2, amplitude: .random(in: 0.025...0.07), phase: .random(in: 0...(2 * .pi))),
            .init(k: 3, amplitude: .random(in: 0.012...0.035), phase: .random(in: 0...(2 * .pi))),
            .init(k: 4, amplitude: .random(in: 0...0.015), phase: .random(in: 0...(2 * .pi))),
        ])
    }
}
