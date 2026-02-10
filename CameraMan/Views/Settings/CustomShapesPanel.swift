import SwiftUI

struct CustomShapesPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var showDrawingSheet = false
    @State private var draftPoints: [CGPoint] = []
    @State private var draftName = "My shape"
    @State private var draftSmoothness = 0.75
    /// Draft for the random shape flow (preview + name + regenerate).
    @State private var randomDraft: CustomShape?

    var body: some View {
        let shapes: [CustomShape] = appState.customShapes
        return List {
            Section {
                ForEach(Array(shapes.enumerated()), id: \.element.id) { _, shape in
                    HStack {
                        preview(shape)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shape.name)
                                .font(.headline)
                            Text("\(shape.points.count) points")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if appState.selectedCustomShapeId == shape.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                        Button("Use") {
                            appState.selectCustomShape(shape.id)
                        }
                        .buttonStyle(.bordered)
                        Button(role: .destructive, action: { appState.removeCustomShape(shape.id) }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
                if appState.customShapes.isEmpty {
                    Text("No custom shapes yet. Tap \"New random shape\" to generate one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            } header: {
                Label("My shapes", systemImage: "hand.draw")
            } footer: {
                Text("Use organic shapes as the camera frame. Select \"Custom\" in General → Shape and pick one here.")
            }

            Section {
                Button {
                    randomDraft = CustomShape(
                        name: "Organic \(appState.customShapes.count + 1)",
                        points: CustomShape.randomOrganicPoints(),
                        smoothness: 0.75
                    )
                } label: {
                    Label("New random shape", systemImage: "sparkles")
                }
                Button {
                    draftPoints = []
                    draftName = "My shape"
                    draftSmoothness = 0.75
                    showDrawingSheet = true
                } label: {
                    Label("Draw by hand…", systemImage: "pencil.tip.crop.circle")
                }
            }
        }
        .listStyle(.inset)
        .sheet(item: $randomDraft) { draft in
            RandomShapeSheet(
                draft: Binding(
                    get: { randomDraft ?? draft },
                    set: { randomDraft = $0 }
                ),
                onRegenerate: {
                    guard let current = randomDraft else { return }
                    randomDraft = CustomShape(
                        id: current.id,
                        name: current.name,
                        points: CustomShape.randomOrganicPoints(),
                        smoothness: current.smoothness
                    )
                },
                onAdd: {
                    if let s = randomDraft { appState.addCustomShape(s) }
                    randomDraft = nil
                },
                onCancel: { randomDraft = nil }
            )
        }
        .sheet(isPresented: $showDrawingSheet) {
            ShapeDrawingCanvas(
                points: $draftPoints,
                shapeName: $draftName,
                smoothness: $draftSmoothness,
                onDone: {
                    addDraftShape()
                    showDrawingSheet = false
                },
                onCancel: { showDrawingSheet = false }
            )
            .frame(minWidth: 440, minHeight: 400)
        }
    }

    private func preview(_ shape: CustomShape) -> some View {
        CustomShapeView(customShape: shape)
            .stroke(Color.primary.opacity(0.6), lineWidth: 1.5)
            .frame(width: 44, height: 44)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func addDraftShape() {
        guard draftPoints.count >= 3 else { return }
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My shape" : draftName
        let shape = CustomShape(name: name, points: draftPoints, smoothness: draftSmoothness)
        appState.addCustomShape(shape)
    }
}

// MARK: - Random organic shape sheet (preview + name + regenerate)
private struct RandomShapeSheet: View {
    @Binding var draft: CustomShape
    var onRegenerate: () -> Void
    var onAdd: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("New organic shape")
                .font(.headline)
            Text("Smooth Bezier-style blob. Regenerate until you like it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            CustomShapeView(customShape: draft)
                .stroke(Color.accentColor, lineWidth: 2.5)
                .frame(width: 200, height: 200)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 12) {
                Button("Regenerate") { onRegenerate() }
                    .buttonStyle(.bordered)
                TextField("Name", text: Binding(
                    get: { draft.name },
                    set: { new in
                        var s = draft
                        s.name = new
                        draft = s
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
            }
            HStack(spacing: 12) {
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Add shape", action: onAdd)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(minWidth: 380, minHeight: 420)
    }
}

#Preview {
    CustomShapesPanel()
        .environmentObject(AppState())
}
