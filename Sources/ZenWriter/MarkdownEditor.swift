import AppKit
import SwiftUI

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    let theme: WriterTheme
    let fontSize: Double
    let writingFont: WriterFont

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        let editor = NSTextView()
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticLinkDetectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = true
        editor.allowsUndo = true
        editor.usesFindBar = true
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.lineFragmentPadding = 0
        editor.textContainerInset = NSSize(width: 36, height: 40)
        editor.delegate = context.coordinator
        editor.setAccessibilityLabel("Markdown editor")
        editor.string = text
        scroll.documentView = editor
        context.coordinator.editor = editor
        applyStyle(editor, scroll: scroll)
        DispatchQueue.main.async { editor.window?.makeFirstResponder(editor) }
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? NSTextView else { return }
        if editor.string != text {
            let selection = editor.selectedRange()
            editor.string = text
            editor.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
        }
        applyStyle(editor, scroll: scroll)
    }
    private func applyStyle(_ editor: NSTextView, scroll: NSScrollView) {
        scroll.backgroundColor = theme.background
        editor.backgroundColor = theme.background
        editor.textColor = theme.foreground
        editor.insertionPointColor = theme.accent
        editor.selectedTextAttributes = [.backgroundColor: theme.selection, .foregroundColor: theme.foreground]
        let font = writingFont.native(size: fontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = fontSize * 0.42
        editor.font = font
        editor.defaultParagraphStyle = paragraph
        editor.typingAttributes = [.font: font, .foregroundColor: theme.foreground, .paragraphStyle: paragraph]
        let storage = editor.textStorage
        storage?.beginEditing()
        storage?.addAttributes([.font: font, .foregroundColor: theme.foreground, .paragraphStyle: paragraph], range: NSRange(location: 0, length: storage?.length ?? 0))
        // Styling is display-only: the saved file always remains plain UTF-8 Markdown.
        for (pattern, color) in [("(?m)^#{1,6} .+$", theme.accent), ("(?m)^>.*$", theme.muted), ("`[^`\\n]+`", theme.secondary)] {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                for match in regex.matches(in: editor.string, range: NSRange(location: 0, length: (editor.string as NSString).length)) {
                    storage?.addAttribute(.foregroundColor, value: color, range: match.range)
                }
            }
        }
        storage?.endEditing()
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        weak var editor: NSTextView?
        init(_ parent: MarkdownEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor else { return }
            parent.text = editor.string
        }
    }
}
