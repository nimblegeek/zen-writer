import SwiftUI
import ZenCore

struct WriterView: View {
    @EnvironmentObject private var archive: ArchiveModel
    @EnvironmentObject private var workspace: WriterWorkspace
    @StateObject private var window = WriterWindow()
    @AppStorage("archiveSidebarVisible") private var sidebarVisible = true
    @State private var sidebarBeforeFocus = true
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    @AppStorage("writerTheme") private var themeName = WriterTheme.gruvboxDark.rawValue
    @AppStorage("writerFontSize") private var fontSize = 18.0
    @AppStorage("writerFontFamily") private var fontName = WriterFont.workSans.rawValue
    @State private var preview = false
    @State private var focus = false
    @State private var showExport = false
    @State private var showAppearance = false
    @State private var showActions = false
    private var theme: WriterTheme { WriterTheme(rawValue: themeName) ?? .gruvboxDark }
    private var writingFont: WriterFont { WriterFont(rawValue: fontName) ?? .workSans }
    private var words: Int { Article(markdown: document.text).wordCount }

    var body: some View {
        VStack(spacing: 0) {
            header
            if workspace.windows.count > 1 && !focus { DocumentStrip(current: window, theme: theme) }
            Rectangle().fill(Color(theme.muted).opacity(0.1)).frame(height: 1)
            HStack(spacing: 0) {
                if sidebarVisible {
                    ArchiveSidebar(fileURL: fileURL, window: window, theme: theme)
                    Rectangle().fill(Color(theme.muted).opacity(0.08)).frame(width: 1)
                }
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        if preview {
                            MarkdownPreview(markdown: document.text, theme: theme, fontSize: fontSize, writingFont: writingFont)
                        } else {
                            MarkdownEditor(text: $document.text, theme: theme, fontSize: fontSize, writingFont: writingFont)
                                .frame(maxWidth: 800).frame(maxWidth: .infinity)
                            if document.text.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Make room for a thought.").font(writingFont.swiftUI(size: 24, semibold: true))
                                    Text("Write in Markdown. Save with ⌘S.").font(WriterFont.workSans.swiftUI(size: 13))
                                }
                                .foregroundStyle(Color(theme.muted).opacity(0.65))
                                .padding(.horizontal, 36).padding(.top, 43)
                                .frame(maxWidth: 800, alignment: .leading).frame(maxWidth: .infinity)
                                .allowsHitTesting(false)
                            }
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    if !focus {
                        HStack(spacing: 9) {
                            Text("\(words) \(words == 1 ? "word" : "words")")
                            Text("·").opacity(0.5)
                            Text("\(max(1, Int(ceil(Double(words) / 200)))) min read")
                            Spacer()
                            Button { showAppearance = true } label: { Text(writingFont.actualName) }
                                .buttonStyle(.plain).help("Choose your writing font")
                            Text("·").opacity(0.5)
                            Text("Markdown")
                        }
                        .font(WriterFont.workSans.swiftUI(size: 11)).foregroundStyle(Color(theme.muted).opacity(0.75))
                        .padding(.horizontal, 30).frame(height: 38)
                    }
                }
            }
        }
        .foregroundStyle(Color(theme.foreground)).background(Color(theme.background))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(theme.muted).opacity(0.12), lineWidth: 1).allowsHitTesting(false))
        .tint(Color(theme.accent)).preferredColorScheme(theme.scheme)
        .frame(minWidth: sidebarVisible ? 856 : 680, minHeight: 400)
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowReader { window.attach($0, theme: theme, workspace: workspace) })
        .onChange(of: document.text) { _, _ in DispatchQueue.main.async { window.refreshEditedState() } }
        .onChange(of: sidebarVisible) { _, visible in if visible { focus = false } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in archive.refresh() }
        .alert("Archive", isPresented: Binding(get: { archive.error != nil }, set: { if !$0 { archive.error = nil } })) {
            Button("OK") { archive.error = nil }
        } message: { Text(archive.error ?? "") }
        .sheet(isPresented: $showExport) {
            ArticleExportView(source: document.text, fileURL: fileURL, theme: theme) { document.text = $0 }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            WindowControls(window: window, theme: theme)
            Rectangle().fill(Color(theme.muted).opacity(0.16)).frame(width: 1, height: 17)
            HStack(spacing: 7) {
                Image(systemName: "leaf").font(.system(size: 13, weight: .light)).foregroundStyle(Color(theme.accent))
                Text("Zen Writer").font(WriterFont.workSans.swiftUI(size: 13, semibold: true))
            }.allowsHitTesting(false)
            Spacer(minLength: 12)
            HStack(spacing: 7) {
                Text(window.title).lineLimit(1).font(WriterFont.workSans.swiftUI(size: 12))
                if window.edited { Circle().fill(Color(theme.accent)).frame(width: 5, height: 5).accessibilityLabel("Unsaved changes") }
            }.foregroundStyle(Color(theme.muted)).allowsHitTesting(false)
            Spacer(minLength: 12)
            if focus {
                Button { toggleFocus() } label: { Text("Leave focus").padding(.horizontal, 10).frame(height: 30) }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
            } else {
                HStack(spacing: 5) {
                    Button { sidebarVisible.toggle() } label: { Image(systemName: "sidebar.left").frame(width: 32, height: 32) }
                        .help("Toggle archive (⌘B)").accessibilityLabel("Toggle archive")
                    Button { showAppearance.toggle() } label: { Text("Aa").font(WriterFont.workSans.swiftUI(size: 16)).frame(width: 36, height: 32) }
                        .help("Fonts & appearance").accessibilityLabel("Fonts and appearance")
                        .popover(isPresented: $showAppearance, arrowEdge: .bottom) {
                            AppearancePanel(fontName: $fontName, fontSize: $fontSize, themeName: $themeName, theme: theme)
                        }
                    Button { preview.toggle() } label: { Image(systemName: preview ? "pencil" : "eye").frame(width: 32, height: 32) }
                        .help(preview ? "Edit Markdown (⇧⌘P)" : "Preview (⇧⌘P)")
                        .accessibilityLabel(preview ? "Edit Markdown" : "Preview").keyboardShortcut("p", modifiers: [.command, .shift])
                    Button { toggleFocus() } label: { Image(systemName: "viewfinder").frame(width: 32, height: 32) }
                        .help("Focus mode (⇧⌘F)").accessibilityLabel("Focus mode").keyboardShortcut("f", modifiers: [.command, .shift])
                    Button { showActions.toggle() } label: { Image(systemName: "ellipsis").frame(width: 32, height: 32) }
                        .accessibilityLabel("Document menu").help("Document menu")
                        .popover(isPresented: $showActions, arrowEdge: .bottom) { documentActions }
                }
                Rectangle().fill(Color(theme.muted).opacity(0.16)).frame(width: 1, height: 17)
                Button { showExport = true } label: {
                    HStack(spacing: 7) { Image(systemName: "square.and.arrow.up"); Text("Export") }
                        .padding(.horizontal, 10).frame(height: 32)
                }.accessibilityLabel("Export").help("Export a Markdown article")
            }
        }
        .buttonStyle(QuietButtonStyle(theme: theme))
        .font(WriterFont.workSans.swiftUI(size: 12))
        .padding(.horizontal, 15).frame(height: focus ? 44 : 56)
        .background(WindowDragArea()).background(Color(theme.surface))
    }
    private var documentActions: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("YOUR DOCUMENT").font(.system(size: 10, design: .monospaced)).tracking(1.7).foregroundStyle(Color(theme.muted)).padding(12)
            action("New text", symbol: "square.and.pencil", shortcut: "⌘N") { NSDocumentController.shared.newDocument(nil) }
            action("Open Markdown…", symbol: "folder", shortcut: "⌘O") { NSDocumentController.shared.openDocument(nil) }
            action("Save", symbol: "arrow.down.to.line", shortcut: "⌘S") { NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil) }
            Rectangle().fill(Color(theme.muted).opacity(0.13)).frame(height: 1).padding(.vertical, 6)
            action("Export article…", symbol: "square.and.arrow.up", shortcut: "") { showExport = true }
            action("Show in Finder", symbol: "doc", shortcut: "") { if let fileURL { NSWorkspace.shared.activateFileViewerSelecting([fileURL]) } }.disabled(fileURL == nil)
        }.padding(8).frame(width: 245).background(Color(theme.surface))
            .foregroundStyle(Color(theme.foreground)).preferredColorScheme(theme.scheme)
    }
    private func action(_ title: String, symbol: String, shortcut: String, run: @escaping () -> Void) -> some View {
        Button {
            showActions = false
            DispatchQueue.main.async { run() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 16)
                Text(title)
                Spacer()
                Text(shortcut).foregroundStyle(Color(theme.muted)).font(.system(size: 10))
            }.padding(10).contentShape(Rectangle())
        }.font(WriterFont.workSans.swiftUI(size: 12)).buttonStyle(QuietButtonStyle(theme: theme))
    }
    private func toggleFocus() {
        if focus { focus = false; sidebarVisible = sidebarBeforeFocus }
        else { sidebarBeforeFocus = sidebarVisible; sidebarVisible = false; focus = true }
    }
}
