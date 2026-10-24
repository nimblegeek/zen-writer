import SwiftUI
import ZenCore

struct WriterView: View {
    @EnvironmentObject private var archive: ArchiveModel
    @StateObject private var window = WriterWindow()
    @AppStorage("archiveSidebarVisible") private var sidebarVisible = true
    @State private var sidebarBeforeFocus = true
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    @AppStorage("writerTheme") private var themeName = WriterTheme.gruvboxDark.rawValue
    @AppStorage("writerFontSize") private var fontSize = 17.0
    @State private var preview = false
    @State private var focus = false
    @State private var showExport = false
    private var theme: WriterTheme { WriterTheme(rawValue: themeName) ?? .gruvboxDark }
    private var words: Int { Article(markdown: document.text).wordCount }

    var body: some View {
        HStack(spacing: 0) {
            if sidebarVisible { ArchiveSidebar(fileURL: fileURL, window: window, theme: theme) }
            VStack(spacing: 0) {
                if !focus {
                    HStack(spacing: 16) {
                        Button { sidebarVisible.toggle() } label: { Image(systemName: "sidebar.left") }
                            .help("Toggle archive (⌘B)").accessibilityLabel("Toggle archive")
                        Label("Zen Writer", systemImage: "leaf").font(.system(size: 12, weight: .medium)).foregroundStyle(Color(theme.muted))
                        Spacer()
                        Menu {
                            Picker("Theme", selection: $themeName) {
                                ForEach(WriterTheme.allCases) { Text($0.name).tag($0.rawValue) }
                            }
                        } label: { Image(systemName: "circle.lefthalf.filled") }
                        .menuStyle(.borderlessButton).fixedSize().help("Choose a theme").accessibilityLabel("Choose a theme")
                        Button { preview.toggle() } label: { Image(systemName: preview ? "pencil" : "eye") }
                            .help(preview ? "Edit Markdown (⇧⌘P)" : "Preview (⇧⌘P)").accessibilityLabel(preview ? "Edit Markdown" : "Preview")
                            .keyboardShortcut("p", modifiers: [.command, .shift])
                        Button { sidebarBeforeFocus = sidebarVisible; sidebarVisible = false; focus = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                            .help("Focus mode (⇧⌘F)").accessibilityLabel("Focus mode")
                            .keyboardShortcut("f", modifiers: [.command, .shift])
                        Rectangle().fill(Color(theme.muted).opacity(0.25)).frame(width: 1, height: 16)
                        Button { showExport = true } label: { Label("Export", systemImage: "square.and.arrow.up") }
                            .help("Export a Markdown article")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 24).frame(height: 52)
                    .background(Color(theme.surface))
                }
                ZStack(alignment: .topLeading) {
                    if preview {
                        MarkdownPreview(markdown: document.text, theme: theme, fontSize: fontSize)
                    } else {
                        MarkdownEditor(text: $document.text, theme: theme, fontSize: fontSize)
                            .frame(maxWidth: 800)
                            .frame(maxWidth: .infinity)
                        if document.text.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Make room for a thought.").font(.system(size: 24, weight: .medium, design: .serif))
                                Text("Write in Markdown. Save with ⌘S.").font(.system(size: 13))
                            }
                            .foregroundStyle(Color(theme.muted).opacity(0.65))
                            .padding(.horizontal, 36).padding(.top, 43)
                            .frame(maxWidth: 800, alignment: .leading).frame(maxWidth: .infinity)
                            .allowsHitTesting(false)
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                if focus {
                    HStack { Spacer(); Button("Leave focus", systemImage: "arrow.down.right.and.arrow.up.left") { focus = false; sidebarVisible = sidebarBeforeFocus }.keyboardShortcut("f", modifiers: [.command, .shift]).buttonStyle(.plain) }
                        .font(.system(size: 11)).foregroundStyle(Color(theme.muted)).padding(14)
                } else {
                    HStack {
                        Text("\(words) \(words == 1 ? "word" : "words")")
                        Text("·")
                        Text("\(max(1, Int(ceil(Double(words) / 200)))) min read")
                        Spacer()
                        Text(theme.name)
                        Text("·")
                        Text("Markdown")
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(theme.muted))
                    .padding(.horizontal, 24).frame(height: 36)
                }
            }
        }
        .foregroundStyle(Color(theme.foreground))
        .background(Color(theme.background))
        .tint(Color(theme.accent))
        .preferredColorScheme(theme.scheme)
        .frame(minWidth: sidebarVisible ? 856 : 620, minHeight: 400)
        .background(WindowReader { window.window = $0; $0.tabbingIdentifier = "ZenWriterDocuments" })
        .onChange(of: sidebarVisible) { _, visible in if visible { focus = false } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in archive.refresh() }
        .alert("Archive", isPresented: Binding(get: { archive.error != nil }, set: { if !$0 { archive.error = nil } })) {
            Button("OK") { archive.error = nil }
        } message: { Text(archive.error ?? "") }
        .sheet(isPresented: $showExport) {
            ArticleExportView(source: document.text, fileURL: fileURL, theme: theme) { document.text = $0 }
        }
    }
}
