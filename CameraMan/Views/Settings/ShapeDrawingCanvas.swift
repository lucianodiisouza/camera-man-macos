import SwiftUI

/// Canvas where the user draws a closed shape with the mouse. Output points are normalized to 0...1.
struct ShapeDrawingCanvas: View {
    @Binding var points: [CGPoint]
    @Binding var shapeName: String
    @Binding var smoothness: Double
    var onDone: () -> Void
    var onCancel: () -> Void

    @State private var drawingPoints: [CGPoint] = []
    @State private var currentDrag: CGPoint?
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Shape name", text: $shapeName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .focused($nameFocused)
                Slider(value: $smoothness, in: 0...1) {
                    Text("Smooth")
                }
                .frame(maxWidth: 120)
                Text("Smooth")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                Button("Done") { finishDrawing() }
                    .buttonStyle(.borderedProminent)
                    .disabled(drawingPoints.count < 3)
            }
            .padding()

            Text("Draw a closed shape: drag to draw, then tap Done. Use at least 3 points.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                        }
                    canvasContent(size: size)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            let p = value.location
                            if currentDrag == nil {
                                drawingPoints.append(p)
                            }
                            currentDrag = p
                        }
                        .onEnded { value in
                            let p = value.location
                            drawingPoints.append(p)
                            currentDrag = nil
                        }
                )
                .onTapGesture(count: 2) {
                    // Double-tap to close and use as preview (add first point at end for closed path)
                    if drawingPoints.count >= 3 {
                        finishDrawing()
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 420, minHeight: 380)
    }

    private func canvasContent(size: CGSize) -> some View {
        let scale: CGFloat = min(size.width, size.height) * 0.9
        let origin = CGPoint(x: (size.width - scale) / 2, y: (size.height - scale) / 2)
        return ZStack {
            // Draw existing segments
            if drawingPoints.count >= 2 {
                Path { path in
                    path.move(to: pointInCanvas(drawingPoints[0], size: size, origin: origin, scale: scale))
                    for i in 1..<drawingPoints.count {
                        path.addLine(to: pointInCanvas(drawingPoints[i], size: size, origin: origin, scale: scale))
                    }
                    if let cur = currentDrag {
                        path.addLine(to: pointInCanvas(cur, size: size, origin: origin, scale: scale))
                    }
                }
                .stroke(Color.accentColor, lineWidth: 2)
            }
            // Dots at each point
            ForEach(Array(drawingPoints.enumerated()), id: \.offset) { _, p in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .position(pointInCanvas(p, size: size, origin: origin, scale: scale))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// Map from canvas coords (0..size) to drawing area (centered, scaled)
    private func pointInCanvas(_ p: CGPoint, size: CGSize, origin: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: origin.x + p.x / size.width * scale,
            y: origin.y + (1 - p.y / size.height) * scale
        )
    }

    /// Normalize drawn points to 0...1 (bounding box), assign to binding, then call onDone.
    private func finishDrawing() {
        var pts = drawingPoints
        if let cur = currentDrag { pts.append(cur) }
        guard pts.count >= 3 else { return }
        // Bounding box of drawn points (in view coordinates)
        let minX = pts.map(\.x).min() ?? 0
        let maxX = pts.map(\.x).max() ?? 1
        let minY = pts.map(\.y).min() ?? 0
        let maxY = pts.map(\.y).max() ?? 1
        let w = max(maxX - minX, 1e-6)
        let h = max(maxY - minY, 1e-6)
        // Normalize to 0...1. Our path(in:) uses (1 - p.y) for Y so normalized y=0 = top, y=1 = bottom.
        let normalized = pts.map { p in
            CGPoint(x: (p.x - minX) / w, y: (p.y - minY) / h)
        }
        points = normalized
        onDone()
    }
}
