import AppKit
import Foundation
let destination = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(srgbRed: 0.157, green: 0.157, blue: 0.157, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 56, y: 56, width: 912, height: 912), xRadius: 210, yRadius: 210).fill()
NSColor(srgbRed: 0.235, green: 0.220, blue: 0.212, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 218, y: 186, width: 588, height: 652), xRadius: 65, yRadius: 65).fill()
NSColor(srgbRed: 0.922, green: 0.859, blue: 0.698, alpha: 1).setStroke()
let lines = NSBezierPath()
lines.lineWidth = 25
lines.lineCapStyle = .round
for (y, width) in [(620.0, 324.0), (510.0, 252.0), (400.0, 300.0)] {
    lines.move(to: NSPoint(x: 350, y: y)); lines.line(to: NSPoint(x: 350 + width, y: y))
}
lines.stroke()
NSColor(srgbRed: 0.722, green: 0.733, blue: 0.149, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 652, y: 202, width: 128, height: 128)).fill()
image.unlockFocus()
let data = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: destination))
