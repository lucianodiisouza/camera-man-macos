import SwiftUI

struct ShortcutRow: View {
    let action: String
    let keys: String

    var body: some View {
        HStack {
            Text(action)
                .foregroundStyle(.primary)
            Spacer()
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ShortcutsPanel: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ShortcutRow(action: "Settings", keys: "⌘ ,")
                    ShortcutRow(action: "Keyboard Shortcuts", keys: "—")
                    ShortcutRow(action: "Restore defaults", keys: "—")
                    ShortcutRow(action: "Quit Camera-Man", keys: "⌘ Q")
                } header: {
                    Label("Menu bar", systemImage: "menubar.rectangle")
                }

                Section {
                    ShortcutRow(action: "Move view left", keys: "←")
                    ShortcutRow(action: "Move view right", keys: "→")
                    ShortcutRow(action: "Move view up", keys: "↑")
                    ShortcutRow(action: "Move view down", keys: "↓")
                    ShortcutRow(action: "Zoom in", keys: "+")
                    ShortcutRow(action: "Zoom out", keys: "−")
                    ShortcutRow(action: "Reset zoom", keys: "R")
                    ShortcutRow(action: "Flip horizontal", keys: "/")
                    ShortcutRow(action: "Flip vertical", keys: "V")
                    ShortcutRow(action: "Next shape", keys: "O")
                    ShortcutRow(action: "Next camera", keys: "⌫")
                    ShortcutRow(action: "Toggle window size (Slot 1 ↔ Slot 2)", keys: "Space")
                } header: {
                    Label("Camera window", systemImage: "viewfinder")
                } footer: {
                    Text("Use these when the camera window is focused.")
                }
            }
            .listStyle(.inset)
            .navigationTitle("Keyboard Shortcuts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 380, minHeight: 420)
    }
}

#Preview {
    ShortcutsPanel()
        .environmentObject(AppState())
}
