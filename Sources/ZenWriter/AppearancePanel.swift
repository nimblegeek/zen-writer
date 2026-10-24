import SwiftUI

struct AppearancePanel: View {
    @Binding var fontName: String
    @Binding var fontSize: Double
    @Binding var themeName: String
    let theme: WriterTheme
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("MAKE IT YOURS").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(2).foregroundStyle(Color(theme.muted))
            VStack(spacing: 5) {
                ForEach(WriterFont.allCases) { font in
                    Button { fontName = font.rawValue } label: {
                        HStack(spacing: 14) {
                            Text(font == .jetBrainsMono ? "{}" : "Aa").font(font.swiftUI(size: 25)).frame(width: 40)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(font.name).font(font.swiftUI(size: 14, semibold: true))
                                Text(font.detail).font(WriterFont.workSans.swiftUI(size: 10)).foregroundStyle(Color(theme.muted))
                            }
                            Spacer(minLength: 0)
                            if fontName == font.rawValue { Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(theme.accent)) }
                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(fontName == font.rawValue ? Color(theme.selection) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).accessibilityLabel(font.name)
                }
            }
            HStack {
                Text("Text size").font(WriterFont.workSans.swiftUI(size: 12))
                Spacer()
                Text("\(Int(fontSize)) pt").font(WriterFont.jetBrainsMono.swiftUI(size: 11)).foregroundStyle(Color(theme.muted))
            }
            Slider(value: $fontSize, in: 14...28, step: 1).accessibilityLabel("Text size")
            Rectangle().fill(Color(theme.muted).opacity(0.15)).frame(height: 1)
            Text("APPEARANCE").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(2).foregroundStyle(Color(theme.muted))
            HStack(spacing: 8) {
                ForEach(WriterTheme.allCases) { option in
                    Button { themeName = option.rawValue } label: {
                        VStack(spacing: 7) {
                            HStack(spacing: 4) {
                                Circle().fill(Color(option.accent)).frame(width: 8, height: 8)
                                Capsule().fill(Color(option.foreground).opacity(0.75)).frame(width: 30, height: 3)
                            }.frame(maxWidth: .infinity).frame(height: 34).background(Color(option.background), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(themeName == option.rawValue ? theme.accent : theme.muted).opacity(themeName == option.rawValue ? 0.9 : 0.15)))
                            Text(option.name.replacingOccurrences(of: "Gruvbox ", with: "")).font(WriterFont.workSans.swiftUI(size: 10))
                        }
                    }.buttonStyle(.plain).accessibilityLabel(option.name)
                }
            }
        }.padding(20).frame(width: 310).foregroundStyle(Color(theme.foreground))
            .background(Color(theme.surface)).tint(Color(theme.accent)).preferredColorScheme(theme.scheme)
    }
}
