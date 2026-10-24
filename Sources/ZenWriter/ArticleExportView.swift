import SwiftUI
import ZenCore
import UniformTypeIdentifiers

struct ArticleExportView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("articleExportDirectory") private var directoryPath = ""
    let theme: WriterTheme
    let updateDocument: (String) -> Void
    @State private var article: Article
    @State private var slug: String
    @State private var prepared: PreparedExport?
    @State private var savedURL: URL?
    @State private var message: String?
    @State private var error: String?
    @State private var confirmReplace = false

    init(source: String, fileURL: URL?, theme: WriterTheme, updateDocument: @escaping (String) -> Void) {
        self.theme = theme; self.updateDocument = updateDocument
        let parsed = Article(markdown: source).preparedForExport
        _article = State(initialValue: parsed)
        let filename = fileURL?.deletingPathExtension().lastPathComponent ?? ""
        _slug = State(initialValue: Article.validSlug(filename) ? filename : Article.slug(from: parsed.title))
    }
    private var publication: Publication? { try? Publication(article: article, slug: slug) }
    private var fingerprint: String { article.markdown + "\n" + slug + "\n" + directoryPath }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("From a thought to an article.").font(.system(size: 25, weight: .medium, design: .serif))
                    Text("Markdown export").font(.system(size: 12, design: .monospaced)).foregroundStyle(Color(theme.muted))
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Form {
                TextField("Title", text: $article.title)
                HStack {
                    TextField("Filename", text: $slug)
                    Button("From title") { slug = Article.slug(from: article.title) }
                }
                TextField("Date", text: $article.date, prompt: Text("YYYY-MM-DD"))
                TextField("Excerpt", text: $article.excerpt, axis: .vertical).lineLimit(2...3)
            }.textFieldStyle(.roundedBorder)
            Text("\(slug.isEmpty ? "your-article" : slug).md").font(.system(size: 11, design: .monospaced)).foregroundStyle(Color(theme.muted))
            MarkdownPreview(markdown: article.markdown, theme: theme, fontSize: 16)
                .frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(theme.muted).opacity(0.2)))
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick export folder · optional").font(.caption).bold()
                    Text(directoryPath.isEmpty ? "No folder selected" : directoryPath).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color(theme.muted)).lineLimit(1).truncationMode(.middle).help(directoryPath)
                }
                Spacer()
                if !directoryPath.isEmpty { Button("Clear") { directoryPath = "" } }
                Button("Choose…") { chooseDirectory() }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            if let message { Text(message).font(.caption).foregroundStyle(Color(theme.accent)) }
            HStack {
                Button("Export Markdown…") { export() }.disabled(publication == nil)
                Button("Apply metadata") { updateDocument(article.markdown); message = "Metadata applied. Use ⌘S to save your document." }.disabled(publication == nil)
                Spacer()
                if let savedURL { Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([savedURL]) } }
                Button("Save to folder") { prepareSave() }.buttonStyle(.borderedProminent).disabled(publication == nil || directoryPath.isEmpty)
            }
            Text("Export anywhere you like. Choose a blog’s articles folder for a shortcut, or keep your writing completely separate.")
                .font(.system(size: 11)).foregroundStyle(Color(theme.muted))
        }
        .padding(28).frame(width: 700)
        .background(Color(theme.surface)).foregroundStyle(Color(theme.foreground))
        .tint(Color(theme.accent)).preferredColorScheme(theme.scheme)
        .onChange(of: fingerprint) { _, _ in prepared = nil; error = nil; message = nil; savedURL = nil }
        .alert("Replace the existing article?", isPresented: $confirmReplace) {
            Button("Cancel", role: .cancel) { prepared = nil }
            Button("Replace article", role: .destructive) { if let prepared { save(prepared) } }
        } message: {
            Text("\(slug).md already exists in the selected folder. Replacing it updates that local file.")
        }
    }
    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.message = "Choose any folder for your exported articles."
        if !directoryPath.isEmpty { panel.directoryURL = URL(fileURLWithPath: directoryPath) }
        if panel.runModal() == .OK, let url = panel.url { directoryPath = url.path }
    }
    private func prepareSave() {
        error = nil; message = nil
        do {
            let publication = try Publication(article: article, slug: slug)
            let prepared = try ArticleExporter.prepare(publication, directory: URL(fileURLWithPath: directoryPath))
            self.prepared = prepared
            if prepared.isUpdate && !prepared.isUnchanged { confirmReplace = true }
            else { save(prepared) }
        } catch { self.error = error.localizedDescription }
    }
    private func save(_ prepared: PreparedExport) {
        do {
            savedURL = try ArticleExporter.save(prepared)
            updateDocument(prepared.publication.markdown)
            message = prepared.isUnchanged ? "This version is already saved in the selected folder." : "Saved \(slug).md in your export folder."
        } catch { self.error = error.localizedDescription }
        self.prepared = nil
    }
    private func export() {
        guard let publication else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.markdown]
        panel.nameFieldStringValue = publication.slug + ".md"
        panel.message = "Save a Markdown file with article metadata."
        if panel.runModal() == .OK, let url = panel.url {
            do { try publication.markdown.write(to: url, atomically: true, encoding: .utf8); message = "Exported \(url.lastPathComponent)." }
            catch { self.error = error.localizedDescription }
        }
    }
}
