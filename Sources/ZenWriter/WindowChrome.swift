import AppKit
import SwiftUI

@MainActor
final class WriterWorkspace: ObservableObject {
    @Published private(set) var windows: [WriterWindow] = []
    func register(_ entry: WriterWindow) {
        if !windows.contains(where: { $0 === entry }) { windows.append(entry) }
    }
    func unregister(_ entry: WriterWindow) { windows.removeAll { $0 === entry } }
    func activate(_ entry: WriterWindow, from source: NSWindow?) {
        guard let target = entry.window else { return }
        if let source, source != target, !source.styleMask.contains(.fullScreen), !target.styleMask.contains(.fullScreen) {
            target.setFrame(source.frame, display: false)
        }
        target.deminiaturize(nil)
        target.makeKeyAndOrderFront(nil)
    }
}

@MainActor
final class WriterWindow: ObservableObject, Identifiable {
    let id = UUID()
    weak var window: NSWindow?
    @Published private(set) var title = "Untitled"
    @Published private(set) var edited = false
    private var observations: [NSKeyValueObservation] = []
    private weak var document: NSDocument?
    private var documentObservation: NSKeyValueObservation?
    private var closeObserver: NSObjectProtocol?
    func attach(_ window: NSWindow, theme: WriterTheme, workspace: WriterWorkspace) {
        if self.window !== window {
            self.window = window
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.styleMask.insert(.fullSizeContentView)
            window.tabbingMode = .disallowed
            window.toolbar = nil
            window.isMovableByWindowBackground = false
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] { window.standardWindowButton(button)?.isHidden = true }
            title = window.title
            edited = window.isDocumentEdited
            observations = [
                window.observe(\.title, options: [.new]) { [weak self] window, _ in
                    Task { @MainActor in self?.title = window.title }
                },
                window.observe(\.isDocumentEdited, options: [.new]) { [weak self] window, _ in
                    Task { @MainActor in self?.edited = window.isDocumentEdited }
                }
            ]
            closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self, weak workspace] _ in
                Task { @MainActor in if let self { workspace?.unregister(self) } }
            }
            workspace.register(self)
        }
        refreshEditedState()
        window.backgroundColor = theme.background
        window.appearance = NSAppearance(named: theme.scheme == .dark ? .darkAqua : .aqua)
    }
    func refreshEditedState() {
        guard let window else { return }
        let document = NSDocumentController.shared.documents.first { $0.windowControllers.contains { $0.window === window } }
        if self.document !== document, let document {
            self.document = document
            documentObservation = document.observe(\.isDocumentEdited, options: [.new]) { [weak self] document, _ in
                Task { @MainActor in self?.edited = document.isDocumentEdited }
            }
        }
        let changed = document?.isDocumentEdited ?? window.isDocumentEdited
        if edited != changed { edited = changed }
    }
    deinit { if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) } }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) {}
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 { window?.performZoom(nil) }
            else { window?.performDrag(with: event) }
        }
    }
}

struct WindowControls: View {
    @ObservedObject var window: WriterWindow
    let theme: WriterTheme
    var body: some View {
        HStack(spacing: 3) {
            control("xmark", label: "Close window") { window.window?.performClose(nil) }
            control("minus", label: "Minimize window") { window.window?.performMiniaturize(nil) }
            control("square.on.square", label: "Maximize or restore window") { window.window?.performZoom(nil) }
        }
    }
    private func control(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 10, weight: .medium)).frame(width: 25, height: 28) }
            .buttonStyle(QuietButtonStyle(theme: theme)).help(label).accessibilityLabel(label)
    }
}

struct QuietButtonStyle: ButtonStyle {
    let theme: WriterTheme
    func makeBody(configuration: Configuration) -> some View {
        QuietButtonContent(configuration: configuration, theme: theme)
    }
    private struct QuietButtonContent: View {
        let configuration: Configuration
        let theme: WriterTheme
        @State private var hover = false
        var body: some View {
            configuration.label
                .foregroundStyle(Color(hover ? theme.foreground : theme.muted))
                .background(Color(theme.selection).opacity(configuration.isPressed ? 1 : hover ? 0.65 : 0), in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle()).onHover { hover = $0 }
        }
    }
}

struct DocumentStrip: View {
    @EnvironmentObject private var workspace: WriterWorkspace
    let current: WriterWindow
    let theme: WriterTheme
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(workspace.windows) { entry in
                    DocumentTab(entry: entry, selected: entry === current, theme: theme) { workspace.activate(entry, from: current.window) }
                }
            }.padding(.horizontal, 14).padding(.vertical, 5)
        }.frame(height: 38).background(Color(theme.surface))
    }
}

private struct DocumentTab: View {
    @ObservedObject var entry: WriterWindow
    let selected: Bool
    let theme: WriterTheme
    let action: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            Button(action: action) {
                HStack(spacing: 7) {
                    if entry.edited { Circle().fill(Color(theme.accent)).frame(width: 5, height: 5) }
                    Text(entry.title).lineLimit(1)
                }.padding(.leading, 10).padding(.vertical, 7)
            }.buttonStyle(.plain)
            Button { entry.window?.performClose(nil) } label: { Image(systemName: "xmark").font(.system(size: 8)).frame(width: 24, height: 24) }
                .buttonStyle(QuietButtonStyle(theme: theme)).accessibilityLabel("Close \(entry.title)")
        }
        .font(WriterFont.workSans.swiftUI(size: 12))
        .foregroundStyle(Color(selected ? theme.foreground : theme.muted))
        .background(selected ? Color(theme.background) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .contain)
    }
}
