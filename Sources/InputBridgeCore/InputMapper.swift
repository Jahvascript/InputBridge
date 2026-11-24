import Foundation

/// Deterministically reduces keyboard and mouse events to controller snapshots.
///
/// Keyboard/button changes are reflected immediately. Relative mouse movement
/// is accumulated until `tick(deltaTime:)`, allowing the capture layer to use a
/// stable output cadence independent of event delivery frequency.
public final class InputMapper {
    public private(set) var profile: MappingProfile
    public private(set) var state: ControllerState = .neutral

    private var pressedKeys: Set<UInt16> = []
    private var pressedMouseButtons: Set<Int> = []
    private var pendingMouseX: Float = 0
    private var pendingMouseY: Float = 0
    private var mouseTarget: StickPosition = .neutral
    private var mouseOutput: StickPosition = .neutral

    public init(profile: MappingProfile = .default) {
        self.profile = profile
        rebuildState()
    }

    /// Replaces the active profile after validating it and clears held input.
    public func updateProfile(_ profile: MappingProfile) throws {
        try ProfileValidator.validateOrThrow(profile)
        self.profile = profile
        reset()
    }

    /// Records a key press. Repeated key-down events are idempotent.
    @discardableResult
    public func keyDown(_ keyCode: UInt16) -> ControllerState {
        pressedKeys.insert(keyCode)
        rebuildState()
        return state
    }

    /// Convenience spelling for event adapters that prefer an argument label.
    @discardableResult
    public func keyDown(keyCode: UInt16) -> ControllerState {
        keyDown(keyCode)
    }

    @discardableResult
    public func keyUp(_ keyCode: UInt16) -> ControllerState {
        pressedKeys.remove(keyCode)
        rebuildState()
        return state
    }

    @discardableResult
    public func keyUp(keyCode: UInt16) -> ControllerState {
        keyUp(keyCode)
    }

    /// Adds a relative mouse delta. Positive Y means movement down the screen,
    /// matching `NSEvent.deltaY`; it becomes negative controller Y by default.
    public func mouseMoved(deltaX: Double, deltaY: Double) {
        pendingMouseX = Self.saturatingAdd(pendingMouseX, Float(deltaX))
        pendingMouseY = Self.saturatingAdd(pendingMouseY, Float(deltaY))
    }

    @discardableResult
    public func mouseButtonDown(_ buttonNumber: Int) -> ControllerState {
        pressedMouseButtons.insert(buttonNumber)
        rebuildState()
        return state
    }

    @discardableResult
    public func mouseButtonDown(buttonNumber: Int) -> ControllerState {
        mouseButtonDown(buttonNumber)
    }

    @discardableResult
    public func mouseButtonUp(_ buttonNumber: Int) -> ControllerState {
        pressedMouseButtons.remove(buttonNumber)
        rebuildState()
        return state
    }

    @discardableResult
    public func mouseButtonUp(buttonNumber: Int) -> ControllerState {
        mouseButtonUp(buttonNumber)
    }

    /// Advances mouse smoothing and recentering, returning the new snapshot.
    ///
    /// Calls with the same event sequence and time deltas always produce the
    /// same output. Negative and non-finite deltas are treated as zero.
    @discardableResult
    public func tick(deltaTime: TimeInterval) -> ControllerState {
        let seconds = Self.safeSeconds(deltaTime)
        let settings = profile.mouse
        let hasMovement = pendingMouseX != 0 || pendingMouseY != 0

        if hasMovement {
            let sensitivityX = Self.safeSensitivity(settings.sensitivityX)
            let sensitivityY = Self.safeSensitivity(settings.sensitivityY)
            var vertical = -pendingMouseY * sensitivityY
            if settings.invertY {
                vertical = -vertical
            }
            mouseTarget = StickPosition(
                x: pendingMouseX * sensitivityX,
                y: vertical
            )
        } else {
            let speed = Self.safeRecenterSpeed(settings.recenterSpeed)
            let amount = speed * seconds
            mouseTarget = StickPosition(
                x: Self.moveTowardZero(mouseTarget.x, by: amount),
                y: Self.moveTowardZero(mouseTarget.y, by: amount)
            )
        }

        pendingMouseX = 0
        pendingMouseY = 0

        let blend = Self.smoothingBlend(
            retainedPerSixtieth: settings.smoothing,
            deltaTime: seconds
        )
        mouseOutput = StickPosition(
            x: mouseOutput.x + (mouseTarget.x - mouseOutput.x) * blend,
            y: mouseOutput.y + (mouseTarget.y - mouseOutput.y) * blend
        )
        rebuildState()
        return state
    }

    /// Immediately neutralizes every held key, mouse button, and analog value.
    @discardableResult
    public func reset() -> ControllerState {
        pressedKeys.removeAll(keepingCapacity: true)
        pressedMouseButtons.removeAll(keepingCapacity: true)
        pendingMouseX = 0
        pendingMouseY = 0
        mouseTarget = .neutral
        mouseOutput = .neutral
        state = .neutral
        return state
    }

    private func rebuildState() {
        var actions: Set<ControllerAction> = []

        for binding in profile.keyboardBindings where pressedKeys.contains(binding.keyCode) {
            actions.insert(binding.action)
        }
        for binding in profile.mouse.buttonBindings where pressedMouseButtons.contains(binding.buttonNumber) {
            actions.insert(binding.action)
        }

        var leftStick = StickPosition(
            x: Self.direction(negative: .leftStickLeft, positive: .leftStickRight, in: actions),
            y: Self.direction(negative: .leftStickDown, positive: .leftStickUp, in: actions)
        )
        var rightStick = StickPosition(
            x: Self.direction(negative: .rightStickLeft, positive: .rightStickRight, in: actions),
            y: Self.direction(negative: .rightStickDown, positive: .rightStickUp, in: actions)
        )

        switch profile.mouse.targetStick {
        case .left:
            leftStick = StickPosition(
                x: leftStick.x + mouseOutput.x,
                y: leftStick.y + mouseOutput.y
            )
        case .right:
            rightStick = StickPosition(
                x: rightStick.x + mouseOutput.x,
                y: rightStick.y + mouseOutput.y
            )
        }

        let leftTrigger: Float = actions.contains(.leftTrigger) ? 1 : 0
        let rightTrigger: Float = actions.contains(.rightTrigger) ? 1 : 0

        var buttons: Set<ControllerButton> = []
        Self.copyButton(.square, from: .square, actions: actions, into: &buttons)
        Self.copyButton(.cross, from: .cross, actions: actions, into: &buttons)
        Self.copyButton(.circle, from: .circle, actions: actions, into: &buttons)
        Self.copyButton(.triangle, from: .triangle, actions: actions, into: &buttons)
        Self.copyButton(.leftShoulder, from: .leftShoulder, actions: actions, into: &buttons)
        Self.copyButton(.rightShoulder, from: .rightShoulder, actions: actions, into: &buttons)
        Self.copyButton(.leftTrigger, from: .leftTrigger, actions: actions, into: &buttons)
        Self.copyButton(.rightTrigger, from: .rightTrigger, actions: actions, into: &buttons)
        Self.copyButton(.share, from: .share, actions: actions, into: &buttons)
        Self.copyButton(.options, from: .options, actions: actions, into: &buttons)
        Self.copyButton(.leftStick, from: .leftStickButton, actions: actions, into: &buttons)
        Self.copyButton(.rightStick, from: .rightStickButton, actions: actions, into: &buttons)
        Self.copyButton(.playStation, from: .playStation, actions: actions, into: &buttons)
        Self.copyButton(.touchpad, from: .touchpad, actions: actions, into: &buttons)

        let dpadX = Self.direction(negative: .dpadLeft, positive: .dpadRight, in: actions)
        let dpadY = Self.direction(negative: .dpadDown, positive: .dpadUp, in: actions)

        state = ControllerState(
            leftStick: leftStick,
            rightStick: rightStick,
            leftTrigger: leftTrigger,
            rightTrigger: rightTrigger,
            buttons: buttons,
            dpad: Self.dpadDirection(x: dpadX, y: dpadY)
        )
    }

    private static func direction(
        negative: ControllerAction,
        positive: ControllerAction,
        in actions: Set<ControllerAction>
    ) -> Float {
        let negativeValue: Float = actions.contains(negative) ? 1 : 0
        let positiveValue: Float = actions.contains(positive) ? 1 : 0
        return positiveValue - negativeValue
    }

    private static func copyButton(
        _ button: ControllerButton,
        from action: ControllerAction,
        actions: Set<ControllerAction>,
        into buttons: inout Set<ControllerButton>
    ) {
        if actions.contains(action) {
            buttons.insert(button)
        }
    }

    private static func dpadDirection(x: Float, y: Float) -> DPadDirection {
        switch (x, y) {
        case (0, 1): return .up
        case (1, 1): return .upRight
        case (1, 0): return .right
        case (1, -1): return .downRight
        case (0, -1): return .down
        case (-1, -1): return .downLeft
        case (-1, 0): return .left
        case (-1, 1): return .upLeft
        default: return .neutral
        }
    }

    private static func moveTowardZero(_ value: Float, by amount: Float) -> Float {
        guard amount > 0 else { return value }
        if value > 0 { return max(0, value - amount) }
        if value < 0 { return min(0, value + amount) }
        return 0
    }

    private static func smoothingBlend(retainedPerSixtieth smoothing: Float, deltaTime: Float) -> Float {
        let safeSmoothing: Float
        if smoothing.isFinite {
            safeSmoothing = min(max(smoothing, 0), 0.999_999)
        } else {
            safeSmoothing = 0
        }
        if safeSmoothing == 0 { return 1 }
        guard deltaTime > 0 else { return 0 }
        let retained = pow(safeSmoothing, deltaTime * 60)
        return 1 - retained
    }

    private static func safeSeconds(_ value: TimeInterval) -> Float {
        guard value.isFinite, value > 0 else { return 0 }
        return Float(min(value, TimeInterval(Float.greatestFiniteMagnitude)))
    }

    private static func safeSensitivity(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    private static func safeRecenterSpeed(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 100)
    }

    private static func saturatingAdd(_ lhs: Float, _ rhs: Float) -> Float {
        guard rhs.isFinite else { return lhs }
        let result = lhs + rhs
        if result.isFinite { return result }
        return result.sign == .minus ? -Float.greatestFiniteMagnitude : Float.greatestFiniteMagnitude
    }
}
