import AppKit

enum StatusIcon {
    static let pointSize: CGFloat = 18

    static func image(enabled: Bool) -> NSImage {
        let size = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let frame = NSRect(x: 2.25, y: 4, width: 13.5, height: 10)
            let window = NSBezierPath(roundedRect: frame, xRadius: 2.8, yRadius: 2.8)
            window.lineWidth = 1.45
            window.stroke()

            if enabled {
                let glow = NSBezierPath()
                glow.move(to: NSPoint(x: 9, y: 11.2))
                glow.line(to: NSPoint(x: 11.2, y: 9))
                glow.line(to: NSPoint(x: 9, y: 6.8))
                glow.line(to: NSPoint(x: 6.8, y: 9))
                glow.close()
                glow.fill()
            }
            return true
        }
        image.isTemplate = true
        image.size = size
        return image
    }
}
