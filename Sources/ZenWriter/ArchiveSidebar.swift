import SwiftUI
import ZenCore

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
    @State private var showOptions = false
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
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    Button { selection = archive.root } label: {
                        Label("All writing", systemImage: "tray")
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 9)
                            .background(selection == archive.root ? Color(theme.selection) : .clear, in: RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain)
                        .contextMenu { Button("New text") { operation = .text(archive.root) }; Button("New folder") { operation = .folder(archive.root) } }
                    ArchiveRows(items: archive.items, selection: $selection, theme: theme) { operation = $0 }
                }.padding(.horizontal, 12).padding(.vertical, 8)
            }
            .font(WriterFont.workSans.swiftUI(size: 13)).foregroundStyle(Color(theme.foreground))
            .overlay {
                if archive.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text").font(.system(size: 25, weight: .light))
                        Text("A home for your words.").font(WriterFont.workSans.swiftUI(size: 14))
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
                Button { showOptions.toggle() } label: { Image(systemName: "ellipsis").frame(width: 28, height: 28) }
                    .buttonStyle(QuietButtonStyle(theme: theme)).accessibilityLabel("Archive options")
                    .popover(isPresented: $showOptions, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            option("Import Markdown…", symbol: "doc.badge.plus") { archive.importFiles(parent: parent) }
                            option("Show archive in Finder", symbol: "folder") { NSWorkspace.shared.open(archive.root) }
                            option("Choose archive folder…", symbol: "folder.badge.gearshape") { archive.chooseFolder() }
                            Rectangle().fill(Color(theme.muted).opacity(0.15)).frame(height: 1).padding(.vertical, 5)
                            option("Refresh archive", symbol: "arrow.clockwise") { archive.refresh() }
                        }.padding(8).frame(width: 245).background(Color(theme.surface)).foregroundStyle(Color(theme.foreground)).preferredColorScheme(theme.scheme)
                    }
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
    private func option(_ title: String, symbol: String, run: @escaping () -> Void) -> some View {
        Button {
            showOptions = false
            DispatchQueue.main.async { run() }
        } label: {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity, alignment: .leading).padding(10)
        }.font(WriterFont.workSans.swiftUI(size: 12)).buttonStyle(QuietButtonStyle(theme: theme))
    }

}

private struct ArchiveRows: View {
    @EnvironmentObject private var archive: ArchiveModel
    let items: [ArchiveItem]
    @Binding var selection: URL?
    let theme: WriterTheme
    let operate: (ArchiveOperation) -> Void
    var body: some View {
        ForEach(items) { item in
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    if item.isFolder {
                        Button {
                            if archive.expandedFolders.contains(item.url) { archive.expandedFolders.remove(item.url) }
                            else { archive.expandedFolders.insert(item.url) }
                        } label: {
                            Image(systemName: archive.expandedFolders.contains(item.url) ? "chevron.down" : "chevron.right")
                                .font(.system(size: 8, weight: .semibold)).frame(width: 16, height: 30)
                        }.buttonStyle(.plain).accessibilityLabel("\(archive.expandedFolders.contains(item.url) ? "Collapse" : "Expand") \(item.name)")
                    } else { Spacer().frame(width: 16) }
                    Button { selection = item.url } label: {
                        Label(item.name, systemImage: item.isFolder ? "folder" : "doc.text")
                            .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 9)
                    }.buttonStyle(.plain).help(item.url.lastPathComponent)
                }.padding(.horizontal, 7)
                    .background(selection == item.url ? Color(theme.selection) : .clear, in: RoundedRectangle(cornerRadius: 7))
                    .contextMenu { actions(item) }
                if let children = item.children, archive.expandedFolders.contains(item.url) {
                    ArchiveRows(items: children, selection: $selection, theme: theme, operate: operate).padding(.leading, 14)
                }
            }
        }
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
