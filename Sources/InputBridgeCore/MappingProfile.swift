import Foundation

/// A logical controller action that may be assigned to a key or mouse button.
public enum ControllerAction: String, Codable, CaseIterable, Hashable, Sendable {
    case leftStickUp
    case leftStickDown
    case leftStickLeft
    case leftStickRight
    case rightStickUp
    case rightStickDown
    case rightStickLeft
    case rightStickRight

    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight

    case square
    case cross
    case circle
    case triangle
    case leftShoulder
    case rightShoulder
    case leftTrigger
    case rightTrigger
    case share
    case options
    case leftStickButton
    case rightStickButton
    case playStation
    case touchpad
}

/// A binding from a macOS virtual key code (`NSEvent.keyCode`) to an action.
///
/// Keeping the core type as `UInt16` avoids an AppKit dependency while letting
/// the capture layer pass key codes through without translation.
public struct KeyboardBinding: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt16
    public var action: ControllerAction

    public init(keyCode: UInt16, action: ControllerAction) {
        self.keyCode = keyCode
        self.action = action
    }
}

/// A binding from an `NSEvent.buttonNumber` to a controller action.
public struct MouseButtonBinding: Codable, Equatable, Hashable, Sendable {
    public var buttonNumber: Int
    public var action: ControllerAction

    public init(buttonNumber: Int, action: ControllerAction) {
        self.buttonNumber = buttonNumber
        self.action = action
    }
}

public enum MouseTargetStick: String, Codable, CaseIterable, Sendable {
    case left
    case right
}

/// Controls how relative mouse movement is converted to an analog stick.
///
/// Sensitivity is measured in stick units per mouse point. `smoothing` is the
/// fraction of the previous output retained per 1/60 second; zero disables it.
/// `recenterSpeed` is the number of stick units per second that the unsmoothed
/// target moves back toward neutral when a tick receives no mouse movement.
public struct MouseMapping: Codable, Equatable, Sendable {
    public var targetStick: MouseTargetStick
    public var sensitivityX: Float
    public var sensitivityY: Float
    public var smoothing: Float
    public var recenterSpeed: Float
    public var invertY: Bool
    public var buttonBindings: [MouseButtonBinding]

    public init(
        targetStick: MouseTargetStick = .right,
        sensitivityX: Float = 0.025,
        sensitivityY: Float = 0.025,
        smoothing: Float = 0.25,
        recenterSpeed: Float = 8,
        invertY: Bool = false,
        buttonBindings: [MouseButtonBinding] = []
    ) {
        self.targetStick = targetStick
        self.sensitivityX = sensitivityX
        self.sensitivityY = sensitivityY
        self.smoothing = smoothing
        self.recenterSpeed = recenterSpeed
        self.invertY = invertY
        self.buttonBindings = buttonBindings
    }
}

/// A versioned, JSON-friendly set of input bindings.
public struct MappingProfile: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var name: String
    public var keyboardBindings: [KeyboardBinding]
    public var mouse: MouseMapping

    public init(
        schemaVersion: Int = MappingProfile.currentSchemaVersion,
        name: String,
        keyboardBindings: [KeyboardBinding],
        mouse: MouseMapping
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.keyboardBindings = keyboardBindings
        self.mouse = mouse
    }

    /// A practical keyboard-and-mouse layout using macOS virtual key codes.
    ///
    /// WASD drives the left stick, the arrow keys drive the d-pad, and the
    /// mouse drives the right stick. Left/right/middle mouse map to R2/L2/R3.
    public static let standardFPS = MappingProfile(
        name: "Keyboard & Mouse",
        keyboardBindings: [
            KeyboardBinding(keyCode: 13, action: .leftStickUp),       // W
            KeyboardBinding(keyCode: 1, action: .leftStickDown),     // S
            KeyboardBinding(keyCode: 0, action: .leftStickLeft),     // A
            KeyboardBinding(keyCode: 2, action: .leftStickRight),    // D
            KeyboardBinding(keyCode: 126, action: .dpadUp),          // Up arrow
            KeyboardBinding(keyCode: 125, action: .dpadDown),        // Down arrow
            KeyboardBinding(keyCode: 123, action: .dpadLeft),        // Left arrow
            KeyboardBinding(keyCode: 124, action: .dpadRight),       // Right arrow
            KeyboardBinding(keyCode: 49, action: .cross),            // Space
            KeyboardBinding(keyCode: 14, action: .square),           // E
            KeyboardBinding(keyCode: 3, action: .circle),            // F
            KeyboardBinding(keyCode: 17, action: .triangle),         // T
            KeyboardBinding(keyCode: 12, action: .leftShoulder),     // Q
            KeyboardBinding(keyCode: 15, action: .rightShoulder),    // R
            KeyboardBinding(keyCode: 56, action: .leftStickButton),  // Left Shift
            KeyboardBinding(keyCode: 36, action: .options),          // Return
            KeyboardBinding(keyCode: 48, action: .touchpad),         // Tab
            KeyboardBinding(keyCode: 53, action: .playStation)       // Escape
        ],
        mouse: MouseMapping(
            targetStick: .right,
            sensitivityX: 0.025,
            sensitivityY: 0.025,
            smoothing: 0.25,
            recenterSpeed: 8,
            invertY: false,
            buttonBindings: [
                MouseButtonBinding(buttonNumber: 0, action: .rightTrigger),
                MouseButtonBinding(buttonNumber: 1, action: .leftTrigger),
                MouseButtonBinding(buttonNumber: 2, action: .rightStickButton)
            ]
        )
    )

    public static let `default` = standardFPS
}
