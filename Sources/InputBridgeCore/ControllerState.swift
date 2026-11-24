import Foundation

/// A normalized analog-stick position.
///
/// Both axes use `-1...1`. Positive X points right and positive Y points up.
/// Non-finite values become zero and out-of-range values are clamped so every
/// `StickPosition` is safe to hand to a report encoder.
public struct StickPosition: Codable, Equatable, Sendable {
    public var x: Float {
        didSet { x = Self.normalized(x) }
    }

    public var y: Float {
        didSet { y = Self.normalized(y) }
    }

    public init(x: Float = 0, y: Float = 0) {
        self.x = Self.normalized(x)
        self.y = Self.normalized(y)
    }

    public static let neutral = StickPosition()

    private enum CodingKeys: String, CodingKey {
        case x
        case y
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            x: try container.decode(Float.self, forKey: .x),
            y: try container.decode(Float.self, forKey: .y)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }

    private static func normalized(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, -1), 1)
    }
}

/// The discrete buttons exposed by the virtual controller.
///
/// Trigger buttons are represented here as well as by analog trigger values,
/// matching the way a DualShock 4 report contains both representations.
public enum ControllerButton: String, Codable, CaseIterable, Hashable, Sendable {
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
    case leftStick
    case rightStick
    case playStation
    case touchpad
}

/// The eight-way directional pad plus its resting state.
public enum DPadDirection: String, Codable, CaseIterable, Sendable {
    case neutral
    case up
    case upRight
    case right
    case downRight
    case down
    case downLeft
    case left
    case upLeft
}

/// A complete, transport-independent snapshot of a game controller.
public struct ControllerState: Codable, Equatable, Sendable {
    public var leftStick: StickPosition
    public var rightStick: StickPosition

    public var leftTrigger: Float {
        didSet { leftTrigger = Self.normalizedTrigger(leftTrigger) }
    }

    public var rightTrigger: Float {
        didSet { rightTrigger = Self.normalizedTrigger(rightTrigger) }
    }

    public var buttons: Set<ControllerButton>
    public var dpad: DPadDirection

    public init(
        leftStick: StickPosition = .neutral,
        rightStick: StickPosition = .neutral,
        leftTrigger: Float = 0,
        rightTrigger: Float = 0,
        buttons: Set<ControllerButton> = [],
        dpad: DPadDirection = .neutral
    ) {
        self.leftStick = leftStick
        self.rightStick = rightStick
        self.leftTrigger = Self.normalizedTrigger(leftTrigger)
        self.rightTrigger = Self.normalizedTrigger(rightTrigger)
        self.buttons = buttons
        self.dpad = dpad
    }

    public static let neutral = ControllerState()

    private enum CodingKeys: String, CodingKey {
        case leftStick
        case rightStick
        case leftTrigger
        case rightTrigger
        case buttons
        case dpad
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            leftStick: try container.decode(StickPosition.self, forKey: .leftStick),
            rightStick: try container.decode(StickPosition.self, forKey: .rightStick),
            leftTrigger: try container.decode(Float.self, forKey: .leftTrigger),
            rightTrigger: try container.decode(Float.self, forKey: .rightTrigger),
            buttons: try container.decode(Set<ControllerButton>.self, forKey: .buttons),
            dpad: try container.decode(DPadDirection.self, forKey: .dpad)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(leftStick, forKey: .leftStick)
        try container.encode(rightStick, forKey: .rightStick)
        try container.encode(leftTrigger, forKey: .leftTrigger)
        try container.encode(rightTrigger, forKey: .rightTrigger)
        try container.encode(buttons, forKey: .buttons)
        try container.encode(dpad, forKey: .dpad)
    }

    private static func normalizedTrigger(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}
