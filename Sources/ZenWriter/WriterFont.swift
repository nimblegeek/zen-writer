import AppKit
import CoreText
import SwiftUI

enum WriterFont: String, CaseIterable, Identifiable {
    case workSans, jetBrainsMono, circular
    var id: String { rawValue }
    static func registerBundledFonts() {
        var directory = Bundle.main.resourceURL?.appendingPathComponent("Fonts")
        #if DEBUG
        if directory.map({ FileManager.default.fileExists(atPath: $0.path) }) != true {
            directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Fonts")
        }
        #endif
        guard let directory, let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "ttf" { CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil) }
    }
    private static var circularFamily: String? {
        NSFontManager.shared.availableFontFamilies.first { $0.localizedCaseInsensitiveContains("circular") }
    }
    var name: String {
        switch self {
        case .workSans: "Work Sans"
        case .jetBrainsMono: "JetBrains Mono"
        case .circular: Self.circularFamily ?? "Circular style"
        }
    }
    var actualName: String { self == .circular ? Self.circularFamily ?? "Avenir Next" : name }
    var detail: String {
        switch self {
        case .workSans: "Clear, unhurried writing"
        case .jetBrainsMono: "Technical notes & code"
        case .circular: Self.circularFamily == nil ? "Avenir Next · built-in alternative" : "Your installed Circular font"
        }
    }
    func native(size: CGFloat, semibold: Bool = false) -> NSFont {
        switch self {
        case .workSans:
            return NSFont(name: semibold ? "WorkSans-SemiBold" : "WorkSans-Regular", size: size) ?? .systemFont(ofSize: size, weight: semibold ? .semibold : .regular)
        case .jetBrainsMono:
            return NSFont(name: semibold ? "JetBrainsMono-SemiBold" : "JetBrainsMono-Regular", size: size) ?? .monospacedSystemFont(ofSize: size, weight: semibold ? .semibold : .regular)
        case .circular:
            if let family = Self.circularFamily, let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: semibold ? 9 : 5, size: size) { return font }
            return NSFont(name: semibold ? "AvenirNext-DemiBold" : "AvenirNext-Regular", size: size) ?? .systemFont(ofSize: size)
        }
    }
    func swiftUI(size: Double, semibold: Bool = false) -> Font { Font(native(size: size, semibold: semibold)) }
}
