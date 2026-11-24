import Foundation

private var failureCount = 0

private func check(
    _ condition: @autoclosure () -> Bool,
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line
) {
    if !condition() {
        failureCount += 1
        fputs("FAIL: \(message) (\(file):\(line))\n", stderr)
    }
}

// Codable profile and validation.
do {
    let encoded = try JSONEncoder().encode(MappingProfile.default)
    let decoded = try JSONDecoder().decode(MappingProfile.self, from: encoded)
    check(decoded == .default, "default mapping profile must round-trip through JSON")
    check(decoded.isValid, "default mapping profile must validate")
} catch {
    check(false, "profile Codable round trip threw \(error)")
}

var invalidProfile = MappingProfile.default
invalidProfile.mouse.smoothing = 1
check(
    ProfileValidator.validate(invalidProfile).contains { $0.code == .invalidSmoothing },
    "validator must reject smoothing of 1"
)

// Keyboard mapping, including deterministic opposing-key behavior.
let keyboardMapper = InputMapper(profile: .default)
keyboardMapper.keyDown(13) // W
check(keyboardMapper.state.leftStick == StickPosition(x: 0, y: 1), "W must push the left stick up")
keyboardMapper.keyDown(1) // S
check(keyboardMapper.state.leftStick == .neutral, "opposing W and S must cancel")
keyboardMapper.keyUp(13)
check(keyboardMapper.state.leftStick == StickPosition(x: 0, y: -1), "releasing W must leave held S active")

// Mouse mapping, smoothing-free movement, and explicit-tick recentering.
let mouseProfile = MappingProfile(
    name: "Smoke",
    keyboardBindings: [],
    mouse: MouseMapping(
        sensitivityX: 0.1,
        sensitivityY: 0.1,
        smoothing: 0,
        recenterSpeed: 1,
        buttonBindings: [MouseButtonBinding(buttonNumber: 0, action: .rightTrigger)]
    )
)
let mouseMapper = InputMapper(profile: mouseProfile)
mouseMapper.mouseMoved(deltaX: 5, deltaY: -4)
mouseMapper.tick(deltaTime: 0.1)
check(abs(mouseMapper.state.rightStick.x - 0.5) < 0.0001, "mouse X sensitivity must be applied")
check(abs(mouseMapper.state.rightStick.y - 0.4) < 0.0001, "screen-up mouse movement must produce positive stick Y")
mouseMapper.tick(deltaTime: 0.1)
check(abs(mouseMapper.state.rightStick.x - 0.4) < 0.0001, "mouse X must recenter on an idle tick")
check(abs(mouseMapper.state.rightStick.y - 0.3) < 0.0001, "mouse Y must recenter on an idle tick")
mouseMapper.mouseButtonDown(0)
check(mouseMapper.state.rightTrigger == 1, "left mouse must drive R2 in the smoke profile")
check(mouseMapper.state.buttons.contains(.rightTrigger), "R2 digital bit must accompany its analog trigger")
mouseMapper.reset()
check(mouseMapper.state == .neutral, "reset must immediately release all controls")

// Golden DS4-shaped USB report bytes.
let neutralReport = DS4USBReportEncoder.encode(state: .neutral)
check(neutralReport.count == 64, "DS4 USB input report must contain 64 bytes")
check(neutralReport[0] == 0x01, "DS4 USB input report ID must be 0x01")
check(Array(neutralReport[1...4]) == [128, 128, 128, 128], "neutral sticks must encode as 128")
check(neutralReport[5] == 0x08, "neutral d-pad hat must encode as 8")
check(neutralReport[10..<30].allSatisfy { $0 == 0 }, "unused pre-status bytes must be zero")
check(neutralReport[30] == 0x1B, "DS4 status must report a connected USB cable and full battery")
check(neutralReport[31...].allSatisfy { $0 == 0 }, "unused post-status bytes must be zero")

let fullState = ControllerState(
    leftStick: StickPosition(x: -1, y: 1),
    rightStick: StickPosition(x: 1, y: -1),
    leftTrigger: 0.5,
    rightTrigger: 1,
    buttons: Set(ControllerButton.allCases),
    dpad: .downLeft
)
let fullReport = DS4USBReportEncoder.encode(state: fullState)
check(Array(fullReport[1...4]) == [0, 0, 255, 255], "stick extremes must use DS4 axis polarity")
check(fullReport[5] == 0xF5, "face buttons and down-left hat must encode to 0xF5")
check(fullReport[6] == 0xFF, "secondary button byte must encode all eight buttons")
check(fullReport[7] == 0x03, "PS and touchpad bits must occupy byte 7")
check(fullReport[8] == 128 && fullReport[9] == 255, "analog triggers must scale to bytes")

if failureCount == 0 {
    print("InputBridgeCore smoke tests passed")
    exit(EXIT_SUCCESS)
} else {
    fputs("\(failureCount) InputBridgeCore smoke test(s) failed\n", stderr)
    exit(EXIT_FAILURE)
}
