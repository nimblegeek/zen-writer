import SwiftUI
import ZenCore

struct MarkdownPreview: View {
    let markdown: String
    let theme: WriterTheme
    let fontSize: Double
    var writingFont: WriterFont = .workSans
    private var blocks: [Block] { Block.parse(Article(markdown: markdown).body) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                let article = Article(markdown: markdown)
                if markdown.hasPrefix("---\n"), !article.title.isEmpty {
                    Text(article.title).font(writingFont.swiftUI(size: 30, semibold: true))
                    Text(article.date).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color(theme.muted))
                }
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .heading(let text, let level):
                        Text(inline(text)).font(writingFont.swiftUI(size: max(19, 34 - Double(level) * 3), semibold: true)).foregroundStyle(Color(theme.accent)).padding(.top, 10)
                    case .paragraph(let text):
                        Text(inline(text)).lineSpacing(7)
                    case .quote(let text):
                        HStack(alignment: .top, spacing: 16) {
                            Rectangle().fill(Color(theme.accent)).frame(width: 2)
                            Text(inline(text)).italic().foregroundStyle(Color(theme.muted)).lineSpacing(7)
                        }.fixedSize(horizontal: false, vertical: true)
                    case .code(let text):
                        ScrollView(.horizontal) { Text(text).font(WriterFont.menlo.swiftUI(size: fontSize - 2)).textSelection(.enabled).padding(18) }
                            .background(Color(theme.surface), in: RoundedRectangle(cornerRadius: WriterCorners.card, style: .continuous))
                    case .list(let text, let bullet):
                        HStack(alignment: .top, spacing: 12) { Text(bullet).foregroundStyle(Color(theme.accent)); Text(inline(text)).lineSpacing(5) }
                    case .rule:
                        Rectangle().fill(Color(theme.muted).opacity(0.25)).frame(height: 1).padding(.vertical, 10)
                    }
                }
                if blocks.isEmpty { Text("Your words, with room to breathe.").foregroundStyle(Color(theme.muted)) }
            }
            .font(writingFont.swiftUI(size: fontSize))
            .foregroundStyle(Color(theme.foreground))
            .textSelection(.enabled)
            .frame(maxWidth: 660, alignment: .leading)
            .padding(40)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .tint(Color(theme.accent))
        .background(Color(theme.background))
        .accessibilityLabel("Article preview")
    }
    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

private enum Block {
    case heading(String, Int), paragraph(String), quote(String), code(String), list(String, String), rule
    static func parse(_ text: String) -> [Block] {
        var result: [Block] = []
        var paragraph: [String] = []
        var code: [String]? = nil
        func flush() { if !paragraph.isEmpty { result.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] } }
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("```") { flush(); if let lines = code { result.append(.code(lines.joined(separator: "\n"))); code = nil } else { code = [] }; continue }
            if code != nil { code?.append(line); continue }
            if line.trimmingCharacters(in: .whitespaces).isEmpty { flush(); continue }
            let hashes = line.prefix(while: { $0 == "#" }).count
            if (1...6).contains(hashes), line.dropFirst(hashes).hasPrefix(" ") { flush(); result.append(.heading(String(line.dropFirst(hashes + 1)), hashes)); continue }
            if line.hasPrefix("> ") { flush(); result.append(.quote(String(line.dropFirst(2)))); continue }
            if ["---", "***", "___"].contains(line) { flush(); result.append(.rule); continue }
            if line.hasPrefix("- ") || line.hasPrefix("* ") { flush(); result.append(.list(String(line.dropFirst(2)), "•")); continue }
            if let match = line.range(of: "^\\d+\\. ", options: .regularExpression) {
                flush(); result.append(.list(String(line[match.upperBound...]), String(line[match]).trimmingCharacters(in: .whitespaces))); continue
            }
            paragraph.append(line)
        }
        flush()
        if let code { result.append(.code(code.joined(separator: "\n"))) }
        return result
    }
}
