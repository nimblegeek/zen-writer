import AppKit
import SwiftUI
import ZenCore

@MainActor
final class ArchiveModel: ObservableObject {
    @Published var expandedFolders: Set<URL> = []
    @Published private(set) var items: [ArchiveItem] = []
    @Published private(set) var root: URL
    @Published var error: String?
    private var store: ArchiveStore?
    static var defaultRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Zen Writer/Archive", isDirectory: true)
    }
    init() {
        root = UserDefaults.standard.string(forKey: "archiveDirectory").map { URL(fileURLWithPath: $0) } ?? Self.defaultRoot
        loadStore()
    }
    private func loadStore() {
        do { store = try ArchiveStore(root: root); root = store!.root; refresh() }
        catch { self.error = error.localizedDescription }
    }
    func refresh() {
        do { if let store { items = try store.contents() } }
        catch { self.error = error.localizedDescription }
    }
    var folders: [URL] {
        func descend(_ items: [ArchiveItem]) -> [URL] { items.flatMap { item in item.children.map { [item.url] + descend($0) } ?? [] } }
        return [root] + descend(items)
    }
    var fileCount: Int {
        func count(_ items: [ArchiveItem]) -> Int { items.reduce(0) { $0 + ($1.children.map(count) ?? 1) } }
        return count(items)
    }
    func reveal(_ url: URL?) {
        guard let url, url.path.hasPrefix(root.path + "/") else { return }
        var parent = url.deletingLastPathComponent().standardizedFileURL
        while parent.path != root.path && parent.path.hasPrefix(root.path + "/") {
            expandedFolders.insert(parent)
            parent = parent.deletingLastPathComponent().standardizedFileURL
        }
    }
    func relativeName(_ url: URL) -> String { url == root ? "Archive" : String(url.path.dropFirst(root.path.count + 1)) }
    func item(at url: URL?) -> ArchiveItem? {
        func find(_ items: [ArchiveItem]) -> ArchiveItem? {
            for item in items { if item.url == url { return item }; if let children = item.children, let match = find(children) { return match } }
            return nil
        }
        return find(items)
    }
    func parent(for selection: URL?) -> URL {
        guard let item = item(at: selection) else { return root }
        return item.isFolder ? item.url : item.url.deletingLastPathComponent()
    }
    func create(name: String, parent: URL, folder: Bool) throws -> URL {
        guard let store else { throw ArticleError.invalid("The archive could not be opened.") }
        let url = try store.create(name: name, parent: parent, isFolder: folder)
        refresh()
        return url
    }
    func relocate(_ item: ArchiveItem, name: String, parent: URL) async throws {
        guard let store else { throw ArticleError.invalid("The archive could not be opened.") }
        let destination = try store.destination(name: name, parent: parent, isFolder: item.isFolder)
        try store.validateMove(from: item.url, to: destination)
        let documents = NSDocumentController.shared.documents
        if item.isFolder, documents.contains(where: { $0.fileURL?.standardizedFileURL.path.hasPrefix(item.url.path + "/") == true }) {
            throw ArticleError.invalid("Close the open texts in this folder before moving or renaming it. macOS will keep your saved changes.")
        }
        if let document = documents.first(where: { $0.fileURL?.standardizedFileURL == item.url.standardizedFileURL }) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                document.move(to: destination) { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
        } else { try store.move(from: item.url, to: destination) }
        refresh()
    }
    func open(_ url: URL, from window: NSWindow?) {
        do {
            guard let store else { throw ArticleError.invalid("The archive could not be opened.") }
            try store.validate(url, allowRoot: false)
        }
        catch { self.error = error.localizedDescription; return }
        NSDocumentController.shared.openDocument(withContentsOf: url, display: false) { [weak self, weak window] document, _, error in
            Task { @MainActor in
                if let error { self?.error = error.localizedDescription; return }
                guard let document else { return }
                if document.windowControllers.isEmpty { document.makeWindowControllers() }
                if let target = document.windowControllers.first?.window {
                    target.tabbingMode = .disallowed
                    if let window, target != window, !window.styleMask.contains(.fullScreen), !target.styleMask.contains(.fullScreen) {
                        target.setFrame(window.frame, display: false)
                    }
                    target.makeKeyAndOrderFront(nil)
                } else { document.showWindows() }
            }
        }
    }
    func importFiles(parent: URL) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.markdown]
        panel.allowsMultipleSelection = true
        panel.message = "Copy Markdown files into your archive. Originals stay where they are."
        guard panel.runModal() == .OK, let store else { return }
        var failed: [String] = []
        for url in panel.urls {
            do { try store.importMarkdown(from: url, parent: parent) }
            catch { failed.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        refresh()
        if !failed.isEmpty { error = failed.joined(separator: "\n") }
    }
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.message = "Choose a local folder for your writing archive. Existing files will stay in place."
        panel.directoryURL = root
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let next = try ArchiveStore(root: url)
                let nextItems = try next.contents()
                store = next; root = next.root; items = nextItems
                UserDefaults.standard.set(root.path, forKey: "archiveDirectory")
            } catch { self.error = error.localizedDescription }
        }
    }
}

struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void
    func makeNSView(context: Context) -> WindowView { let view = WindowView(); view.onWindow = onWindow; return view }
    func updateNSView(_ view: WindowView, context: Context) {
        view.onWindow = onWindow
        if let window = view.window { DispatchQueue.main.async { view.onWindow?(window) } }
    }
    final class WindowView: NSView {
        var onWindow: ((NSWindow) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { DispatchQueue.main.async { self.onWindow?(window) } }
        }
    }
}
