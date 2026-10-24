import SwiftUI

@main
struct ZenWriterApp: App {
    init() {
        WriterFont.registerBundledFonts()
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    @StateObject private var workspace = WriterWorkspace()
    @StateObject private var archive = ArchiveModel()
    @AppStorage("archiveSidebarVisible") private var sidebarVisible = true
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            WriterView(document: file.$document, fileURL: file.fileURL).environmentObject(archive).environmentObject(workspace)
        }
        .defaultSize(width: 1120, height: 760)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Archive") {
                Button(sidebarVisible ? "Hide Archive" : "Show Archive") { sidebarVisible.toggle() }.keyboardShortcut("b", modifiers: .command)
                Button("Show Archive in Finder") { NSWorkspace.shared.open(archive.root) }
            }
        }
        Settings { WriterSettings() }
    }
}

struct WriterSettings: View {
    @AppStorage("writerTheme") private var themeName = WriterTheme.gruvboxDark.rawValue
    @AppStorage("writerFontSize") private var fontSize = 18.0
    @AppStorage("writerFontFamily") private var fontName = WriterFont.workSans.rawValue
    var body: some View {
        Form {
            Picker("Appearance", selection: $themeName) {
                ForEach(WriterTheme.allCases) { Text($0.name).tag($0.rawValue) }
            }
            Picker("Writing font", selection: $fontName) {
                ForEach(WriterFont.allCases) { Text($0.name).tag($0.rawValue) }
            }
            LabeledContent("Text size", value: "\(Int(fontSize)) pt")
            Slider(value: $fontSize, in: 14...28, step: 1)
            Text("Plain Markdown. Your files, wherever you keep them.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Zen Writer works entirely on your Mac. Article export is optional and saves ordinary Markdown files.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(28).frame(width: 420)
    }
}
