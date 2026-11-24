import XCTest
@testable import InputBridgeCore

final class DS4USBReportEncoderTests: XCTestCase {
    func testNeutralReportGoldenBytes() {
        let report = DS4USBReportEncoder.encode(state: .neutral)

        XCTAssertEqual(report.count, 64)
        XCTAssertEqual(report[0], 0x01)
        XCTAssertEqual(Array(report[1...4]), [128, 128, 128, 128])
        XCTAssertEqual(report[5], 0x08) // neutral hat, no face buttons
        XCTAssertEqual(report[6], 0)
        XCTAssertEqual(report[7], 0)
        XCTAssertEqual(report[8], 0)
        XCTAssertEqual(report[9], 0)
        XCTAssertTrue(report[10..<30].allSatisfy { $0 == 0 })
        XCTAssertEqual(report[30], 0x1B) // USB cable connected, battery full
        XCTAssertTrue(report[31...].allSatisfy { $0 == 0 })
    }

    func testAxisExtremesUseDS4YAxisConvention() {
        let state = ControllerState(
            leftStick: StickPosition(x: -1, y: 1),
            rightStick: StickPosition(x: 1, y: -1)
        )
        let report = DS4USBReportEncoder.encode(state: state)

        XCTAssertEqual(Array(report[1...4]), [0, 0, 255, 255])
    }

    func testAllButtonsAndTriggersUseDocumentedBitLayout() {
        let state = ControllerState(
            leftTrigger: 0.5,
            rightTrigger: 1,
            buttons: Set(ControllerButton.allCases),
            dpad: .downLeft
        )
        let report = DS4USBReportEncoder.encode(state: state)

        XCTAssertEqual(report[5], 0xF5)
        XCTAssertEqual(report[6], 0xFF)
        XCTAssertEqual(report[7], 0x03)
        XCTAssertEqual(report[8], 128)
        XCTAssertEqual(report[9], 255)
    }

    func testEveryDPadDirectionHasStandardHatValue() {
        let expected: [(DPadDirection, UInt8)] = [
            (.up, 0), (.upRight, 1), (.right, 2), (.downRight, 3),
            (.down, 4), (.downLeft, 5), (.left, 6), (.upLeft, 7),
            (.neutral, 8)
        ]

        for (direction, hat) in expected {
            let report = DS4USBReportEncoder.encode(
                state: ControllerState(dpad: direction)
            )
            XCTAssertEqual(report[5] & 0x0F, hat, "Unexpected hat value for \(direction)")
        }
    }

    func testAnalogTriggerAlsoSetsDigitalTriggerBit() {
        let report = DS4USBReportEncoder.encode(
            state: ControllerState(leftTrigger: 0.01, rightTrigger: 0.25)
        )

        XCTAssertEqual(report[6] & 0b0000_1100, 0b0000_1100)
        XCTAssertEqual(report[8], 3)
        XCTAssertEqual(report[9], 64)
    }

    func testFaceButtonsDoNotDisturbDPadNibble() {
        let state = ControllerState(buttons: [.cross, .triangle], dpad: .right)
        let report = DS4USBReportEncoder.encode(state: state)

        XCTAssertEqual(report[5], 0b1010_0010)
    }

    func testEncodingIsDeterministic() {
        let state = ControllerState(
            leftStick: StickPosition(x: 0.25, y: -0.75),
            rightStick: StickPosition(x: -0.5, y: 0.125),
            leftTrigger: 0.4,
            buttons: [.square, .options, .touchpad],
            dpad: .upLeft
        )

        XCTAssertEqual(
            DS4USBReportEncoder.encode(state: state),
            DS4USBReportEncoder.encode(state: state)
        )
    }
}
