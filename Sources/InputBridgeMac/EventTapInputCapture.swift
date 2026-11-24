import ApplicationServices
import Foundation

public enum CapturedInputEvent: Sendable {
    case keyDown(keyCode: UInt16, isRepeat: Bool)
    case keyUp(keyCode: UInt16)
    case mouseMoved(deltaX: Double, deltaY: Double)
    case mouseButtonDown(button: Int)
    case mouseButtonUp(button: Int)
    /// Consumers must immediately produce a neutral controller report.
    case reset
}

public enum InputCaptureError: LocalizedError, Equatable {
    case permissionDenied
    case eventTapCreationFailed

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Input Monitoring permission is not enabled for InputBridge."
        case .eventTapCreationFailed:
            return "macOS refused to create the keyboard and mouse event tap. Check Privacy & Security > Input Monitoring, then relaunch InputBridge."
        }
    }
}

/// A listen-only session event tap. It observes input without suppressing or
/// rewriting the user's physical keyboard and mouse events.
public final class EventTapInputCapture {
    public typealias EventHandler = (CapturedInputEvent) -> Void
    public typealias StopHandler = (String) -> Void

    public var onEvent: EventHandler?
    public var onEmergencyStop: StopHandler?
    public private(set) var isRunning = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressedKeys = Set<UInt16>()
    private var pressedMouseButtons = Set<Int>()

    public init() {}

    deinit {
        stop()
    }

    public func start() throws {
        guard !isRunning else { return }
        guard InputPermission.current.canCapture else {
            throw InputCaptureError.permissionDenied
        }

        let mask = Self.eventMask
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let capture = Unmanaged<EventTapInputCapture>
                .fromOpaque(context)
                .takeUnretainedValue()
            return capture.receive(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw InputCaptureError.eventTapCreationFailed
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
    }

    public func stop() {
        guard isRunning || eventTap != nil else { return }
        neutralizeTrackedInputs()

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        isRunning = false
    }

    private func receive(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            neutralizeTrackedInputs()
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .keyDown:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            // Hard-wired escape hatch: Control + Option + Command + F12. It is
            // intentionally handled before user mappings and cannot be rebound.
            if keyCode == 111,
               event.flags.contains(.maskCommand),
               event.flags.contains(.maskAlternate),
               event.flags.contains(.maskControl) {
                neutralizeTrackedInputs()
                DispatchQueue.main.async { [weak self] in
                    self?.onEmergencyStop?("Emergency stop: Control-Option-Command-F12")
                }
                return Unmanaged.passUnretained(event)
            }

            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if !isRepeat { pressedKeys.insert(keyCode) }
            onEvent?(.keyDown(keyCode: keyCode, isRepeat: isRepeat))

        case .keyUp:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            pressedKeys.remove(keyCode)
            onEvent?(.keyUp(keyCode: keyCode))

        case .flagsChanged:
            handleModifierChange(event)

        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            let dx = Double(event.getIntegerValueField(.mouseEventDeltaX))
            let dy = Double(event.getIntegerValueField(.mouseEventDeltaY))
            if dx != 0 || dy != 0 {
                onEvent?(.mouseMoved(deltaX: dx, deltaY: dy))
            }

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            pressedMouseButtons.insert(button)
            onEvent?(.mouseButtonDown(button: button))

        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            pressedMouseButtons.remove(button)
            onEvent?(.mouseButtonUp(button: button))

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleModifierChange(_ event: CGEvent) {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard Self.isModifierKey(keyCode) else { return }
        // Event flags combine the left and right variants. Querying physical
        // key state avoids leaving (for example) left Shift held in the mapper
        // when right Shift is still down as left Shift is released.
        let isDown = CGEventSource.keyState(
            .combinedSessionState,
            key: CGKeyCode(keyCode)
        )

        if isDown && !pressedKeys.contains(keyCode) {
            pressedKeys.insert(keyCode)
            onEvent?(.keyDown(keyCode: keyCode, isRepeat: false))
        } else if !isDown && pressedKeys.contains(keyCode) {
            pressedKeys.remove(keyCode)
            onEvent?(.keyUp(keyCode: keyCode))
        }
    }

    private func neutralizeTrackedInputs() {
        guard !pressedKeys.isEmpty || !pressedMouseButtons.isEmpty else {
            onEvent?(.reset)
            return
        }

        pressedKeys.removeAll()
        pressedMouseButtons.removeAll()
        onEvent?(.reset)
    }

    private static func isModifierKey(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case 54, 55, 56, 60, 57, 58, 61, 59, 62, 63: return true
        default: return false
        }
    }

    private static let eventMask: CGEventMask = {
        let types: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp
        ]
        return types.reduce(CGEventMask(0)) { mask, type in
            mask | (CGEventMask(1) << type.rawValue)
        }
    }()
}
