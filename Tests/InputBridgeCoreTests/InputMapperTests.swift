import XCTest
@testable import InputBridgeCore

final class InputMapperTests: XCTestCase {
    func testWASDAndOpposingKeysAreOrderIndependent() {
        let mapper = InputMapper(profile: .default)

        mapper.keyDown(13) // W
        XCTAssertEqual(mapper.state.leftStick, StickPosition(x: 0, y: 1))

        mapper.keyDown(1) // S cancels W
        XCTAssertEqual(mapper.state.leftStick, .neutral)

        mapper.keyUp(13) // S remains held
        XCTAssertEqual(mapper.state.leftStick, StickPosition(x: 0, y: -1))

        mapper.keyUp(1)
        mapper.keyDown(2) // D
        mapper.keyDown(0) // A cancels D regardless of press order
        XCTAssertEqual(mapper.state.leftStick, .neutral)
        mapper.keyUp(0)
        XCTAssertEqual(mapper.state.leftStick, StickPosition(x: 1, y: 0))
    }

    func testRepeatedKeyDownIsIdempotent() {
        let mapper = InputMapper(profile: .default)
        mapper.keyDown(49)
        mapper.keyDown(49)
        XCTAssertTrue(mapper.state.buttons.contains(.cross))

        mapper.keyUp(49)
        XCTAssertFalse(mapper.state.buttons.contains(.cross))
    }

    func testMultipleKeysBoundToSameActionRemainActiveUntilBothReleased() {
        let profile = makeProfile(keyboard: [
            KeyboardBinding(keyCode: 1, action: .cross),
            KeyboardBinding(keyCode: 2, action: .cross)
        ])
        let mapper = InputMapper(profile: profile)

        mapper.keyDown(1)
        mapper.keyDown(2)
        mapper.keyUp(1)
        XCTAssertTrue(mapper.state.buttons.contains(.cross))

        mapper.keyUp(2)
        XCTAssertFalse(mapper.state.buttons.contains(.cross))
    }

    func testDPadSupportsDiagonalsAndCancelsOpposites() {
        let mapper = InputMapper(profile: .default)
        mapper.keyDown(126) // Up
        mapper.keyDown(124) // Right
        XCTAssertEqual(mapper.state.dpad, .upRight)

        mapper.keyDown(125) // Down cancels Up, Right remains
        XCTAssertEqual(mapper.state.dpad, .right)

        mapper.keyDown(123) // Left cancels Right too
        XCTAssertEqual(mapper.state.dpad, .neutral)
    }

    func testDefaultMouseButtonsDriveDigitalAndAnalogTriggers() {
        let mapper = InputMapper(profile: .default)

        mapper.mouseButtonDown(0)
        XCTAssertEqual(mapper.state.rightTrigger, 1)
        XCTAssertTrue(mapper.state.buttons.contains(.rightTrigger))

        mapper.mouseButtonDown(1)
        XCTAssertEqual(mapper.state.leftTrigger, 1)
        XCTAssertTrue(mapper.state.buttons.contains(.leftTrigger))

        mapper.mouseButtonUp(0)
        XCTAssertEqual(mapper.state.rightTrigger, 0)
        XCTAssertFalse(mapper.state.buttons.contains(.rightTrigger))
        XCTAssertEqual(mapper.state.leftTrigger, 1)
    }

    func testMouseMovementUsesSensitivityAndRecentersOnTicks() {
        let profile = makeProfile(mouse: MouseMapping(
            sensitivityX: 0.1,
            sensitivityY: 0.1,
            smoothing: 0,
            recenterSpeed: 1
        ))
        let mapper = InputMapper(profile: profile)

        mapper.mouseMoved(deltaX: 5, deltaY: -4)
        mapper.tick(deltaTime: 0.1)
        XCTAssertEqual(mapper.state.rightStick.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(mapper.state.rightStick.y, 0.4, accuracy: 0.0001)

        mapper.tick(deltaTime: 0.1)
        XCTAssertEqual(mapper.state.rightStick.x, 0.4, accuracy: 0.0001)
        XCTAssertEqual(mapper.state.rightStick.y, 0.3, accuracy: 0.0001)

        mapper.tick(deltaTime: 1)
        XCTAssertEqual(mapper.state.rightStick, .neutral)
    }

    func testMouseDeltasAccumulateBetweenTicksAndClamp() {
        let profile = makeProfile(mouse: MouseMapping(
            sensitivityX: 0.25,
            sensitivityY: 0.25,
            smoothing: 0,
            recenterSpeed: 0
        ))
        let mapper = InputMapper(profile: profile)
        mapper.mouseMoved(deltaX: 3, deltaY: 1)
        mapper.mouseMoved(deltaX: 3, deltaY: 1)
        mapper.tick(deltaTime: 1.0 / 60.0)

        XCTAssertEqual(mapper.state.rightStick, StickPosition(x: 1, y: -0.5))
    }

    func testMouseYCanBeInverted() {
        let profile = makeProfile(mouse: MouseMapping(
            sensitivityX: 0.1,
            sensitivityY: 0.1,
            smoothing: 0,
            recenterSpeed: 1,
            invertY: true
        ))
        let mapper = InputMapper(profile: profile)
        mapper.mouseMoved(deltaX: 0, deltaY: 4)
        mapper.tick(deltaTime: 1.0 / 60.0)

        XCTAssertEqual(mapper.state.rightStick.y, 0.4, accuracy: 0.0001)
    }

    func testSmoothingIsBasedOnElapsedTime() {
        let profile = makeProfile(mouse: MouseMapping(
            sensitivityX: 0.1,
            sensitivityY: 0.1,
            smoothing: 0.5,
            recenterSpeed: 0
        ))
        let oneTick = InputMapper(profile: profile)
        oneTick.mouseMoved(deltaX: 10, deltaY: 0)
        oneTick.tick(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(oneTick.state.rightStick.x, 0.5, accuracy: 0.0001)
        oneTick.tick(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(oneTick.state.rightStick.x, 0.75, accuracy: 0.0001)

        let combinedTick = InputMapper(profile: profile)
        combinedTick.mouseMoved(deltaX: 10, deltaY: 0)
        combinedTick.tick(deltaTime: 2.0 / 60.0)
        XCTAssertEqual(combinedTick.state.rightStick.x, 0.75, accuracy: 0.0001)
    }

    func testMouseCanTargetLeftStickAndCombinesWithKeyboard() {
        let profile = makeProfile(
            keyboard: [KeyboardBinding(keyCode: 1, action: .leftStickRight)],
            mouse: MouseMapping(
                targetStick: .left,
                sensitivityX: 0.1,
                sensitivityY: 0.1,
                smoothing: 0,
                recenterSpeed: 1
            )
        )
        let mapper = InputMapper(profile: profile)
        mapper.keyDown(1)
        mapper.mouseMoved(deltaX: -5, deltaY: -3)
        mapper.tick(deltaTime: 1.0 / 60.0)

        XCTAssertEqual(mapper.state.leftStick, StickPosition(x: 0.5, y: 0.3))
        XCTAssertEqual(mapper.state.rightStick, .neutral)
    }

    func testResetNeutralizesAllInputImmediately() {
        let mapper = InputMapper(profile: .default)
        mapper.keyDown(13)
        mapper.mouseButtonDown(0)
        mapper.mouseMoved(deltaX: 100, deltaY: -100)
        mapper.tick(deltaTime: 1.0 / 60.0)
        XCTAssertNotEqual(mapper.state, .neutral)

        XCTAssertEqual(mapper.reset(), .neutral)
        XCTAssertEqual(mapper.state, .neutral)

        // No latent mouse target or pressed key may reappear on the next tick.
        mapper.tick(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(mapper.state, .neutral)
    }

    func testInvalidTimeAndMouseDeltasDoNotProduceNonFiniteState() {
        let mapper = InputMapper(profile: .default)
        mapper.mouseMoved(deltaX: .nan, deltaY: .infinity)
        mapper.tick(deltaTime: .nan)

        XCTAssertEqual(mapper.state, .neutral)
    }

    func testUpdateProfileRejectsInvalidProfileWithoutChangingCurrentProfile() {
        let mapper = InputMapper(profile: .default)
        var invalid = MappingProfile.default
        invalid.mouse.smoothing = 2

        XCTAssertThrowsError(try mapper.updateProfile(invalid))
        XCTAssertEqual(mapper.profile, .default)
    }

    private func makeProfile(
        keyboard: [KeyboardBinding] = [],
        mouse: MouseMapping = MouseMapping()
    ) -> MappingProfile {
        MappingProfile(name: "Test", keyboardBindings: keyboard, mouse: mouse)
    }
}
