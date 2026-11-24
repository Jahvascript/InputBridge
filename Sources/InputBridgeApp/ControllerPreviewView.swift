import AppKit
import InputBridgeCore

final class ControllerPreviewView: NSView {
    var state: ControllerState = .neutral {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 520, height: 170) }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let body = bounds.insetBy(dx: 36, dy: 18)
        NSColor.controlBackgroundColor.setFill()
        NSBezierPath(roundedRect: body, xRadius: 54, yRadius: 54).fill()

        drawStick(center: NSPoint(x: body.minX + 135, y: body.midY - 10), position: state.leftStick)
        drawStick(center: NSPoint(x: body.midX + 20, y: body.midY - 25), position: state.rightStick)
        drawDPad(center: NSPoint(x: body.minX + 65, y: body.midY + 28))
        drawFaceButtons(center: NSPoint(x: body.maxX - 72, y: body.midY + 25))
        drawTrigger(value: state.leftTrigger, rect: NSRect(x: body.minX + 48, y: body.maxY - 10, width: 92, height: 7))
        drawTrigger(value: state.rightTrigger, rect: NSRect(x: body.maxX - 140, y: body.maxY - 10, width: 92, height: 7))
    }

    private func drawStick(center: NSPoint, position: StickPosition) {
        let well = NSRect(x: center.x - 28, y: center.y - 28, width: 56, height: 56)
        NSColor.separatorColor.setFill()
        NSBezierPath(ovalIn: well).fill()

        let knobCenter = NSPoint(
            x: center.x + CGFloat(position.x) * 17,
            y: center.y + CGFloat(position.y) * 17
        )
        let knob = NSRect(x: knobCenter.x - 15, y: knobCenter.y - 15, width: 30, height: 30)
        (position == .neutral ? NSColor.secondaryLabelColor : NSColor.systemBlue).setFill()
        NSBezierPath(ovalIn: knob).fill()
    }

    private func drawDPad(center: NSPoint) {
        let directions: [(DPadDirection, NSRect)] = [
            (.up, NSRect(x: center.x - 9, y: center.y + 9, width: 18, height: 23)),
            (.down, NSRect(x: center.x - 9, y: center.y - 32, width: 18, height: 23)),
            (.left, NSRect(x: center.x - 32, y: center.y - 9, width: 23, height: 18)),
            (.right, NSRect(x: center.x + 9, y: center.y - 9, width: 23, height: 18))
        ]

        for (direction, rect) in directions {
            (dpadContains(direction) ? NSColor.systemBlue : NSColor.secondaryLabelColor).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3).fill()
        }
    }

    private func dpadContains(_ direction: DPadDirection) -> Bool {
        switch (state.dpad, direction) {
        case (.up, .up), (.upRight, .up), (.upLeft, .up),
             (.down, .down), (.downRight, .down), (.downLeft, .down),
             (.left, .left), (.upLeft, .left), (.downLeft, .left),
             (.right, .right), (.upRight, .right), (.downRight, .right):
            return true
        default:
            return false
        }
    }

    private func drawFaceButtons(center: NSPoint) {
        let buttons: [(ControllerButton, NSPoint, NSColor)] = [
            (.triangle, NSPoint(x: center.x, y: center.y + 27), .systemGreen),
            (.cross, NSPoint(x: center.x, y: center.y - 27), .systemBlue),
            (.square, NSPoint(x: center.x - 27, y: center.y), .systemPurple),
            (.circle, NSPoint(x: center.x + 27, y: center.y), .systemRed)
        ]
        for (button, point, color) in buttons {
            (state.buttons.contains(button) ? color : NSColor.secondaryLabelColor).setFill()
            NSBezierPath(ovalIn: NSRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)).fill()
        }
    }

    private func drawTrigger(value: Float, rect: NSRect) {
        NSColor.separatorColor.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3).fill()
        let active = NSRect(x: rect.minX, y: rect.minY, width: rect.width * CGFloat(value), height: rect.height)
        NSColor.systemBlue.setFill()
        NSBezierPath(roundedRect: active, xRadius: 3, yRadius: 3).fill()
    }
}
