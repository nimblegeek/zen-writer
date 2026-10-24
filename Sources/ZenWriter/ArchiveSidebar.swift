import SwiftUI
import ZenCore

final class WriterWindow: ObservableObject { weak var window: NSWindow? }

private enum ArchiveOperation: Identifiable {
    case text(URL), folder(URL), rename(ArchiveItem), move(ArchiveItem)
    var id: String {
        switch self {
        case .text(let url): "text:" + url.path
        case .folder(let url): "folder:" + url.path
        case .rename(let item): "rename:" + item.url.path
        case .move(let item): "move:" + item.url.path
        }
    }
    var title: String {
        switch self {
        case .text: "New text"
        case .folder: "New folder"
        case .rename: "Rename"
        case .move: "Move to folder"
        }
    }
}

struct ArchiveSidebar: View {
    @EnvironmentObject private var archive: ArchiveModel
    let fileURL: URL?
    let window: WriterWindow
    let theme: WriterTheme
    @State private var selection: URL?
    @State private var operation: ArchiveOperation?
    private var parent: URL { archive.parent(for: selection) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("ARCHIVE").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.5)
                Spacer()
                Button { operation = .folder(parent) } label: { Image(systemName: "folder.badge.plus") }
                    .help("New folder").accessibilityLabel("New folder")
                Button { operation = .text(parent) } label: { Image(systemName: "square.and.pencil") }
                    .help("New text").accessibilityLabel("New text")
            }
            .buttonStyle(.plain).foregroundStyle(Color(theme.muted)).padding(.horizontal, 18).frame(height: 52)
            List(selection: $selection) {
                Label("All writing", systemImage: "tray").tag(archive.root)
                    .contextMenu { Button("New text") { operation = .text(archive.root) }; Button("New folder") { operation = .folder(archive.root) } }
                ArchiveRows(items: archive.items) { operation = $0 }
            }
            .listStyle(.sidebar).scrollContentBackground(.hidden)
            .font(.system(size: 13)).foregroundStyle(Color(theme.foreground))
            .overlay {
                if archive.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text").font(.system(size: 25, weight: .light))
                        Text("A home for your words.").font(.system(size: 14, design: .serif))
                        Button("Create your first text") { operation = .text(archive.root) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Color(theme.accent))
                    }.foregroundStyle(Color(theme.muted)).padding(16)
                }
            }
            Divider().overlay(Color(theme.muted).opacity(0.12))
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Local files").font(.system(size: 11, weight: .medium))
                    Text("\(archive.fileCount) \(archive.fileCount == 1 ? "text" : "texts")").font(.system(size: 10)).foregroundStyle(Color(theme.muted))
                }
                Spacer()
                Menu {
                    Button("Import Markdown…") { archive.importFiles(parent: parent) }
                    Button("Show archive in Finder") { NSWorkspace.shared.open(archive.root) }
                    Button("Choose archive folder…") { archive.chooseFolder() }
                    Divider()
                    Button("Refresh archive") { archive.refresh() }
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Archive options")
            }.padding(16).foregroundStyle(Color(theme.muted))
        }
        .frame(width: 236).background(Color(theme.surface))
        .onAppear { archive.reveal(fileURL); selection = fileURL?.standardizedFileURL ?? archive.root }
        .onChange(of: fileURL) { _, value in archive.reveal(value); selection = value?.standardizedFileURL ?? archive.root }
        .onChange(of: archive.root) { _, _ in selection = archive.root }
        .onChange(of: selection) { _, value in
            if let item = archive.item(at: value), !item.isFolder { archive.open(item.url, from: window.window) }
        }
        .sheet(item: $operation) { operation in ArchiveEditSheet(operation: operation, window: window, theme: theme) }
    }
}

private struct ArchiveRows: View {
    @EnvironmentObject private var archive: ArchiveModel
    let items: [ArchiveItem]
    let operate: (ArchiveOperation) -> Void
    var body: some View {
        ForEach(items) { item in
            if let children = item.children {
                DisclosureGroup(isExpanded: Binding(
                    get: { archive.expandedFolders.contains(item.url) },
                    set: { if $0 { archive.expandedFolders.insert(item.url) } else { archive.expandedFolders.remove(item.url) } }
                )) {
                    ArchiveRows(items: children, operate: operate)
                } label: { label(item) }
                .tag(item.url)
                .contextMenu { actions(item) }
            } else {
                label(item).tag(item.url).contextMenu { actions(item) }
            }
        }
    }
    private func label(_ item: ArchiveItem) -> some View {
        Label(item.name, systemImage: item.isFolder ? "folder" : "doc.text")
            .lineLimit(1).help(item.url.lastPathComponent)
    }
    @ViewBuilder private func actions(_ item: ArchiveItem) -> some View {
        if item.isFolder {
            Button("New text here") { operate(.text(item.url)) }
            Button("New folder here") { operate(.folder(item.url)) }
            Divider()
        }
        Button("Rename…") { operate(.rename(item)) }
        Button("Move to folder…") { operate(.move(item)) }
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
    }
}

private struct ArchiveEditSheet: View {
    @EnvironmentObject private var archive: ArchiveModel
    @Environment(\.dismiss) private var dismiss
    let operation: ArchiveOperation
    let window: WriterWindow
    let theme: WriterTheme
    @State private var name: String
    @State private var destination: URL
    @State private var error: String?
    @State private var busy = false
    @FocusState private var nameFocused: Bool
    private var isMove: Bool { if case .move = operation { return true }; return false }
    init(operation: ArchiveOperation, window: WriterWindow, theme: WriterTheme) {
        self.operation = operation; self.window = window; self.theme = theme
        switch operation {
        case .text(let parent), .folder(let parent): _name = State(initialValue: ""); _destination = State(initialValue: parent)
        case .rename(let item), .move(let item): _name = State(initialValue: item.url.lastPathComponent); _destination = State(initialValue: item.url.deletingLastPathComponent())
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(operation.title).font(.system(size: 23, weight: .medium, design: .serif))
            if isMove {
                Text(name).foregroundStyle(Color(theme.muted))
                Picker("Folder", selection: $destination) {
                    ForEach(archive.folders.filter { folder in
                        if case .move(let item) = operation { return folder != item.url && !folder.path.hasPrefix(item.url.path + "/") }
                        return true
                    }, id: \.self) { folder in Text(archive.relativeName(folder)).tag(folder) }
                }
            } else {
                TextField("Name", text: $name).textFieldStyle(.roundedBorder).focused($nameFocused)
                Text("In \(archive.relativeName(destination))").font(.caption).foregroundStyle(Color(theme.muted))
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(busy)
                Spacer()
                if busy { ProgressView().controlSize(.small) }
                Button(isMove ? "Move" : "Save") { submit() }.buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
            }
        }.padding(28).frame(width: 380)
            .background(Color(theme.surface)).foregroundStyle(Color(theme.foreground)).tint(Color(theme.accent)).preferredColorScheme(theme.scheme)
            .onAppear { nameFocused = true }.interactiveDismissDisabled(busy)
    }
    private func submit() {
        busy = true; error = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                switch operation {
                case .text:
                    let url = try archive.create(name: name, parent: destination, folder: false)
                    dismiss(); archive.open(url, from: window.window)
                case .folder:
                    _ = try archive.create(name: name, parent: destination, folder: true); dismiss()
                case .rename(let item), .move(let item):
                    try await archive.relocate(item, name: name, parent: destination); dismiss()
                }
            } catch { self.error = error.localizedDescription }
        }
    }
}
