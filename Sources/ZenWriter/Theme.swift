import AppKit
import SwiftUI

enum WriterTheme: String, CaseIterable, Identifiable {
    case gruvboxLight, gruvboxDark, tokyoNight
    var id: String { rawValue }
    var name: String {
        switch self {
        case .gruvboxLight: "Gruvbox Light"
        case .gruvboxDark: "Gruvbox Dark"
        case .tokyoNight: "Tokyo Night"
        }
    }
    var scheme: ColorScheme { self == .gruvboxLight ? .light : .dark }
    var background: NSColor { color(light: 0xfbf1c7, dark: 0x282828, tokyo: 0x1a1b26) }
    var surface: NSColor { color(light: 0xf2e5bc, dark: 0x32302f, tokyo: 0x16161e) }
    var foreground: NSColor { color(light: 0x3c3836, dark: 0xebdbb2, tokyo: 0xc0caf5) }
    var muted: NSColor { color(light: 0x7c6f64, dark: 0xa89984, tokyo: 0xa9b1d6) }
    var accent: NSColor { color(light: 0x427b58, dark: 0xb8bb26, tokyo: 0x7aa2f7) }
    var secondary: NSColor { color(light: 0x8f3f71, dark: 0xd3869b, tokyo: 0xbb9af7) }
    var selection: NSColor { color(light: 0xd5c4a1, dark: 0x504945, tokyo: 0x292e42) }
    private func color(light: UInt32, dark: UInt32, tokyo: UInt32) -> NSColor {
        let hex = self == .gruvboxLight ? light : self == .gruvboxDark ? dark : tokyo
        return NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}
