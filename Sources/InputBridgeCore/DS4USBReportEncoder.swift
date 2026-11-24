import Foundation

/// Encodes `ControllerState` as the 64-byte USB input-report shape used by a
/// wired DualShock 4 (report ID `0x01`).
///
/// The actively consumed control bytes use the standard DS4 layout:
///
/// - 0: report ID
/// - 1...4: left X/Y, right X/Y
/// - 5: d-pad hat and face buttons
/// - 6: shoulders, digital triggers, Share/Options, stick buttons
/// - 7: PS and touchpad buttons (the packet counter bits remain zero)
/// - 8...9: analog L2/R2
/// - 30: status 0 (`0x1B`: USB cable connected and battery full)
///
/// Motion, touch, and vendor-reserved fields are zero-filled. The fixed status
/// byte mirrors Linux's DS4 `CABLE_STATE` plus `BATTERY_FULL` flags so hosts do
/// not treat this USB-shaped controller as disconnected or depleted. This is a
/// deterministic control report; Remote Play acceptance still requires a
/// properly entitled virtual-HID build and signed-device validation.
public enum DS4USBReportEncoder {
    public static let reportLength = 64
    public static let reportID: UInt8 = 0x01

    public static func encode(state: ControllerState) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: reportLength)
        report[0] = reportID
        report[1] = encodeAxis(state.leftStick.x)
        report[2] = encodeAxis(-state.leftStick.y)
        report[3] = encodeAxis(state.rightStick.x)
        report[4] = encodeAxis(-state.rightStick.y)

        var primary = hatValue(for: state.dpad)
        if state.buttons.contains(.square) { primary |= 1 << 4 }
        if state.buttons.contains(.cross) { primary |= 1 << 5 }
        if state.buttons.contains(.circle) { primary |= 1 << 6 }
        if state.buttons.contains(.triangle) { primary |= 1 << 7 }
        report[5] = primary

        var secondary: UInt8 = 0
        if state.buttons.contains(.leftShoulder) { secondary |= 1 << 0 }
        if state.buttons.contains(.rightShoulder) { secondary |= 1 << 1 }
        if state.buttons.contains(.leftTrigger) || state.leftTrigger > 0 { secondary |= 1 << 2 }
        if state.buttons.contains(.rightTrigger) || state.rightTrigger > 0 { secondary |= 1 << 3 }
        if state.buttons.contains(.share) { secondary |= 1 << 4 }
        if state.buttons.contains(.options) { secondary |= 1 << 5 }
        if state.buttons.contains(.leftStick) { secondary |= 1 << 6 }
        if state.buttons.contains(.rightStick) { secondary |= 1 << 7 }
        report[6] = secondary

        var tertiary: UInt8 = 0
        if state.buttons.contains(.playStation) { tertiary |= 1 << 0 }
        if state.buttons.contains(.touchpad) { tertiary |= 1 << 1 }
        report[7] = tertiary
        report[8] = encodeTrigger(state.leftTrigger)
        report[9] = encodeTrigger(state.rightTrigger)
        report[30] = 0x1B
        return report
    }

    private static func encodeAxis(_ value: Float) -> UInt8 {
        let normalized = finiteClamp(value, lower: -1, upper: 1)
        return UInt8(((normalized + 1) * 127.5).rounded())
    }

    private static func encodeTrigger(_ value: Float) -> UInt8 {
        let normalized = finiteClamp(value, lower: 0, upper: 1)
        return UInt8((normalized * 255).rounded())
    }

    private static func finiteClamp(_ value: Float, lower: Float, upper: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, lower), upper)
    }

    private static func hatValue(for direction: DPadDirection) -> UInt8 {
        switch direction {
        case .up: return 0
        case .upRight: return 1
        case .right: return 2
        case .downRight: return 3
        case .down: return 4
        case .downLeft: return 5
        case .left: return 6
        case .upLeft: return 7
        case .neutral: return 8
        }
    }
}
