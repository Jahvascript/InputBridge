import XCTest
@testable import InputBridgeCore

final class MappingProfileTests: XCTestCase {
    func testDefaultProfileIsValidAndContainsExpectedFPSBindings() throws {
        let profile = MappingProfile.default

        XCTAssertTrue(profile.isValid, profile.validationIssues.map(\.message).joined(separator: "\n"))
        XCTAssertEqual(action(forKeyCode: 13, in: profile), .leftStickUp)
        XCTAssertEqual(action(forKeyCode: 0, in: profile), .leftStickLeft)
        XCTAssertEqual(action(forKeyCode: 1, in: profile), .leftStickDown)
        XCTAssertEqual(action(forKeyCode: 2, in: profile), .leftStickRight)
        XCTAssertEqual(action(forKeyCode: 49, in: profile), .cross)
        XCTAssertEqual(action(forKeyCode: 53, in: profile), .playStation)
        XCTAssertEqual(action(forMouseButton: 0, in: profile), .rightTrigger)
        XCTAssertEqual(action(forMouseButton: 1, in: profile), .leftTrigger)
        XCTAssertEqual(profile.mouse.targetStick, .right)
    }

    func testProfileRoundTripsThroughJSON() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(MappingProfile.default)
        let decoded = try JSONDecoder().decode(MappingProfile.self, from: data)

        XCTAssertEqual(decoded, .default)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("keyboardBindings"))
    }

    func testValidationReportsSchemaNameAndDuplicateBindings() {
        let profile = MappingProfile(
            schemaVersion: 99,
            name: "  \n",
            keyboardBindings: [
                KeyboardBinding(keyCode: 13, action: .leftStickUp),
                KeyboardBinding(keyCode: 13, action: .cross)
            ],
            mouse: MouseMapping(buttonBindings: [
                MouseButtonBinding(buttonNumber: 0, action: .cross),
                MouseButtonBinding(buttonNumber: 0, action: .circle),
                MouseButtonBinding(buttonNumber: -1, action: .square)
            ])
        )

        let issues = ProfileValidator.validate(profile)
        let codes = Set(issues.map(\.code))
        XCTAssertTrue(codes.contains(.unsupportedSchemaVersion))
        XCTAssertTrue(codes.contains(.emptyName))
        XCTAssertTrue(codes.contains(.duplicateKeyCode))
        XCTAssertTrue(codes.contains(.duplicateMouseButton))
        XCTAssertTrue(codes.contains(.invalidMouseButton))
        XCTAssertFalse(profile.isValid)
    }

    func testValidationReportsEveryInvalidMouseParameter() {
        var profile = MappingProfile.default
        profile.mouse.sensitivityX = -.leastNonzeroMagnitude
        profile.mouse.sensitivityY = .infinity
        profile.mouse.smoothing = 1
        profile.mouse.recenterSpeed = .nan

        let issues = ProfileValidator.validate(profile)
        XCTAssertEqual(issues.filter { $0.code == .invalidSensitivity }.count, 2)
        XCTAssertEqual(issues.filter { $0.code == .invalidSmoothing }.count, 1)
        XCTAssertEqual(issues.filter { $0.code == .invalidRecenterSpeed }.count, 1)
        XCTAssertEqual(
            Set(issues.map(\.path)),
            ["mouse.sensitivityX", "mouse.sensitivityY", "mouse.smoothing", "mouse.recenterSpeed"]
        )
    }

    func testValidationAllowsMultipleKeysForOneAction() {
        let profile = MappingProfile(
            name: "Alternate keys",
            keyboardBindings: [
                KeyboardBinding(keyCode: 36, action: .cross),
                KeyboardBinding(keyCode: 49, action: .cross)
            ],
            mouse: MouseMapping()
        )

        XCTAssertTrue(profile.isValid)
        XCTAssertNoThrow(try ProfileValidator.validateOrThrow(profile))
    }

    func testValidateOrThrowCarriesStructuredIssues() {
        var profile = MappingProfile.default
        profile.name = ""

        XCTAssertThrowsError(try ProfileValidator.validateOrThrow(profile)) { error in
            guard let validationError = error as? MappingProfileValidationError else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(validationError.issues.map(\.code), [.emptyName])
            XCTAssertTrue(validationError.localizedDescription.contains("name"))
        }
    }

    func testControllerStateNormalizesPublicValues() {
        var state = ControllerState(
            leftStick: StickPosition(x: 5, y: -.infinity),
            leftTrigger: -1,
            rightTrigger: 4
        )
        XCTAssertEqual(state.leftStick, StickPosition(x: 1, y: 0))
        XCTAssertEqual(state.leftTrigger, 0)
        XCTAssertEqual(state.rightTrigger, 1)

        state.leftStick.x = .nan
        state.leftTrigger = .infinity
        XCTAssertEqual(state.leftStick.x, 0)
        XCTAssertEqual(state.leftTrigger, 0)
    }

    private func action(forKeyCode keyCode: UInt16, in profile: MappingProfile) -> ControllerAction? {
        profile.keyboardBindings.first { $0.keyCode == keyCode }?.action
    }

    private func action(forMouseButton button: Int, in profile: MappingProfile) -> ControllerAction? {
        profile.mouse.buttonBindings.first { $0.buttonNumber == button }?.action
    }
}
