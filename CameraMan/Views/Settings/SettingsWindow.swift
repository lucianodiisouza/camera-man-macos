import AppKit
import SwiftUI

/// Pages of the settings window.
enum SettingsPageID: String, CaseIterable, Identifiable {
    case camera, shape, framing, image, border, window, general, shortcuts, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera: return "Camera"
        case .shape: return "Shape"
        case .framing: return "Framing"
        case .image: return "Image"
        case .border: return "Border & Shadow"
        case .window: return "Window"
        case .general: return "General"
        case .shortcuts: return "Shortcuts"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .camera: return "video.fill"
        case .shape: return "square.on.circle"
        case .framing: return "crop"
        case .image: return "camera.filters"
        case .border: return "paintbrush.pointed.fill"
        case .window: return "macwindow"
        case .general: return "gearshape.fill"
        case .shortcuts: return "keyboard.fill"
        case .about: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .camera: return Color(hex: "#EF4444")
        case .shape: return Color(hex: "#8B5CF6")
        case .framing: return Color(hex: "#0EA5E9")
        case .image: return Color(hex: "#F59E0B")
        case .border: return Color(hex: "#E0457B")
        case .window: return Color(hex: "#10B981")
        case .general: return Color(hex: "#6B7280")
        case .shortcuts: return Color(hex: "#6366F1")
        case .about: return Color(hex: "#475569")
        }
    }

    /// The row and group titles on this page the sidebar search can find. They must match the titles on the page so
    /// a result can scroll to its row.
    var searchableSettings: [String] {
        switch self {
        case .camera: return ["Video source", "Video effects"]
        case .shape: return ShapeType.allCases.map(\.shortName) + ["Soft edge", "Corner radius", "Shuffle", "Breathing"]
        case .framing: return ["Horizontal position", "Vertical position", "Zoom", "Mirror horizontally", "Flip vertically"]
        case .image: return ["Brightness", "Contrast", "Saturation"]
        case .border: return ["Show border", "Width", "Gradient", "Color", "Start color", "End color", "Show shadow", "Radius", "Shadow color"]
        case .window: return ["Size", "Screen corner", "Space bar: first size", "Space bar: second size"]
        case .general: return ["Open at login", "Hide Dock icon", "Language", "Restore defaults"]
        case .shortcuts: return ["Global shortcuts", "Show / hide camera", "From any app", "Camera window", "Menu bar"]
        case .about: return []
        }
    }

    static let sections: [[SettingsPageID]] = [
        [.camera, .shape, .framing, .image, .border],
        [.window, .general, .shortcuts, .about],
    ]
}

/// A search hit: a page, or one setting on it.
struct SettingsSearchEntry: Identifiable {
    let title: String
    let page: SettingsPageID
    var isPage: Bool { title == page.title }
    var id: String { "\(page.rawValue):\(title)" }

    static func results(for query: String) -> [SettingsSearchEntry] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return [] }
        return SettingsPageID.allCases.flatMap { page in
            ([page.title] + page.searchableSettings)
                // Matches what is on screen, and the English name too.
                .filter { $0.localized.localizedCaseInsensitiveContains(needle) || $0.localizedCaseInsensitiveContains(needle) }
                .map { SettingsSearchEntry(title: $0, page: page) }
        }
    }
}

@MainActor
@Observable
final class SettingsNavigation {
    var page: SettingsPageID = .camera
    /// The setting a search result pointed at: its page scrolls to it and lights it up for a moment, then this goes
    /// back to nil.
    var highlightedSetting: String?

    func open(_ entry: SettingsSearchEntry) {
        page = entry.page
        highlightedSetting = entry.isPage ? nil : entry.title
    }
}

/// Owns the single settings window, so the app menu and the status bar menu open the same one.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let appState: AppState
    private let navigation = SettingsNavigation()
    private(set) var window: NSWindow?

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func show(_ page: SettingsPageID? = nil) {
        if let page { navigation.page = page }
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 820, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.title = String(localized: "CameraMan Settings")
            // A full-size content view so the sidebar runs up to the top of the window with the traffic lights sitting
            // on it, the way System Settings has it.
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 720, height: 480)
            window.contentViewController = NSHostingController(
                rootView: SettingsWindowView()
                    .environmentObject(appState)
                    .environment(navigation))
            window.setContentSize(NSSize(width: 820, height: 600))
            window.center()
            window.setFrameAutosaveName("CameraManSettings")
            window.delegate = self
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

/// The sidebar on the left, running the full height of the window, and the selected page on the right.
struct SettingsWindowView: View {
    @Environment(SettingsNavigation.self) private var navigation

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar()
                .frame(width: 220)
                .ignoresSafeArea(.container, edges: .top)
            Group {
                switch navigation.page {
                case .camera: CameraSettingsPage()
                case .shape: ShapeSettingsPage()
                case .framing: FramingSettingsPage()
                case .image: ImageSettingsPage()
                case .border: BorderSettingsPage()
                case .window: WindowSettingsPage()
                case .general: GeneralSettingsPage()
                case .shortcuts: ShortcutsSettingsPage()
                case .about: AboutSettingsPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }
}

/// System Settings' sidebar: search on top, the pages under it, the window's wallpaper showing faintly through.
private struct SettingsSidebar: View {
    @Environment(SettingsNavigation.self) private var navigation
    @State private var query = ""
    @FocusState private var isSearching: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
                // Clears the traffic lights, which sit on the sidebar.
                .padding(.top, 44)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        pages
                    } else {
                        results
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .scrollIndicators(.never)
            footer
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background { SidebarMaterial() }
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 1)
        }
        // ⌘F from anywhere in the window, as in System Settings.
        .background {
            Button("") { isSearching = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .focused($isSearching)
                .onExitCommand { query = "" }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(
            Capsule().fill(Color.primary.opacity(0.06))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
        )
    }

    @ViewBuilder
    private var pages: some View {
        ForEach(Array(SettingsPageID.sections.enumerated()), id: \.offset) { index, section in
            if index > 0 {
                // Groups apart by a gap, not a heading, like System Settings.
                Spacer().frame(height: 14)
            }
            ForEach(section) { page in
                SidebarRow(page: page, isSelected: navigation.page == page) {
                    navigation.page = page
                }
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        let found = SettingsSearchEntry.results(for: query)
        if found.isEmpty {
            Text("No Results")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        }
        // Grouped under the page they are on, in the sidebar's own order.
        ForEach(SettingsPageID.allCases) { page in
            let onPage = found.filter { $0.page == page }
            if !onPage.isEmpty {
                SidebarRow(page: page, isSelected: false) {
                    navigation.open(SettingsSearchEntry(title: page.title, page: page))
                }
                ForEach(onPage.filter { !$0.isPage }) { entry in
                    Button {
                        navigation.open(entry)
                    } label: {
                        Text(entry.title.localized)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 42)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer().frame(height: 6)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(SettingsPalette.selection)
            Text("Video never leaves your Mac.")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One page in the sidebar: colored icon and name, filled with the accent color while it is the one open.
private struct SidebarRow: View {
    let page: SettingsPageID
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SettingsIcon(symbol: page.symbol, color: page.color, size: 24)
                Text(page.title.localized)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The sidebar's glass: the desktop behind the window shows through, softened.
private struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
