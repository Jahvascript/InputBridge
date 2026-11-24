import Darwin
import Foundation
import InputBridgeCore
import IOKit.hid

/// Publishes a DS4 v2-shaped IOHIDUserDevice. Creation is intentionally kept
/// behind an explicit backend choice because the required virtual HID
/// entitlement is Apple-managed and unavailable to ordinary ad-hoc builds.
public final class VirtualDS4ControllerBackend: ControllerBackend {
    public let displayName = "Virtual DualShock 4 (USB)"
    public private(set) var isRunning = false
    public var onLog: ((String) -> Void)?
    public var onReport: (([UInt8]) -> Void)?
    public var onFeedback: ((DS4Feedback) -> Void)?

    private let queue = DispatchQueue(label: "io.inputbridge.virtual-ds4")
    private var device: IOHIDUserDevice?
    private var reportCounter: UInt8 = 0

    public init() {}

    deinit {
        stop()
    }

    public func start() throws {
        guard !isRunning else { throw ControllerBackendError.alreadyStarted }

        let properties: [String: Any] = [
            kIOHIDReportDescriptorKey as String: Data(DualShock4Descriptor.report),
            kIOHIDVendorIDKey as String: DualShock4Descriptor.vendorID,
            kIOHIDProductIDKey as String: DualShock4Descriptor.productID,
            kIOHIDVersionNumberKey as String: 0x0100,
            kIOHIDCountryCodeKey as String: 0,
            kIOHIDManufacturerKey as String: "Sony Interactive Entertainment",
            kIOHIDProductKey as String: "Wireless Controller",
            kIOHIDSerialNumberKey as String: "0001DEADBEEF",
            kIOHIDTransportKey as String: "USB",
            kIOHIDLocationIDKey as String: 0x1B000000,
            kIOHIDPrimaryUsagePageKey as String: 0x01,
            kIOHIDPrimaryUsageKey as String: 0x05
        ]

        // Option bit 0 means "create on activate" on macOS 10.15+; this
        // ensures feature handlers are installed before enumeration starts.
        let createOnActivate = IOOptionBits(1 << 0)
        guard let created = IOHIDUserDeviceCreateWithProperties(
            kCFAllocatorDefault,
            properties as CFDictionary,
            createOnActivate
        ) else {
            throw ControllerBackendError.virtualDeviceCreationFailed
        }

        IOHIDUserDeviceRegisterGetReportBlock(created) { [weak self] type, reportID, report, reportLength in
            guard type == kIOHIDReportTypeFeature,
                  let bytes = DualShock4Descriptor.featureReport(id: reportID) else {
                return kIOReturnUnsupported
            }

            let capacity = Int(reportLength.pointee)
            guard capacity >= bytes.count else {
                reportLength.pointee = CFIndex(bytes.count)
                return kIOReturnNoSpace
            }

            bytes.withUnsafeBytes { source in
                if let baseAddress = source.baseAddress {
                    report.update(from: baseAddress.assumingMemoryBound(to: UInt8.self), count: bytes.count)
                }
            }
            reportLength.pointee = CFIndex(bytes.count)
            self?.onLog?(String(format: "Answered DS4 feature report 0x%02X (%d bytes).", reportID, bytes.count))
            return kIOReturnSuccess
        }

        IOHIDUserDeviceRegisterSetReportBlock(created) { [weak self] type, reportID, report, reportLength in
            guard type == kIOHIDReportTypeOutput else {
                return kIOReturnUnsupported
            }

            let bytes = Array(UnsafeBufferPointer(start: report, count: Int(reportLength)))
            let feedback = DS4Feedback(reportID: reportID, bytes: bytes)
            self?.onFeedback?(feedback)
            self?.onLog?(feedback.summary)
            return kIOReturnSuccess
        }

        // IOHIDUserDevice requires the object to outlive asynchronous cancel.
        // The explicit retain is balanced only in the cancellation handler.
        let cancellationLifetime = Unmanaged.passRetained(created)
        IOHIDUserDeviceSetDispatchQueue(created, queue)
        IOHIDUserDeviceSetCancelHandler(created) { [weak self] in
            self?.onLog?("Virtual DualShock 4 removed from macOS.")
            cancellationLifetime.release()
        }

        device = created
        reportCounter = 0
        isRunning = true
        IOHIDUserDeviceActivate(created)
        onLog?("Virtual DualShock 4 activated as 054C:09CC.")
    }

    public func submit(_ state: ControllerState) throws {
        guard isRunning, let device else { throw ControllerBackendError.notStarted }

        var report = DS4USBReportEncoder.encode(state: state)
        if report.first != 0x01 {
            report.insert(0x01, at: 0)
        }
        if report.count < DualShock4Descriptor.inputReportLength {
            report.append(contentsOf: repeatElement(0, count: DualShock4Descriptor.inputReportLength - report.count))
        } else if report.count > DualShock4Descriptor.inputReportLength {
            report.removeSubrange(DualShock4Descriptor.inputReportLength...)
        }

        // DS4 byte 7 carries a rolling six-bit report counter above PS/touch.
        report[7] = (report[7] & 0x03) | ((reportCounter & 0x3F) << 2)
        reportCounter &+= 1

        let result = report.withUnsafeBufferPointer { buffer -> IOReturn in
            guard let address = buffer.baseAddress else { return kIOReturnBadArgument }
            return IOHIDUserDeviceHandleReportWithTimeStamp(
                device,
                mach_absolute_time(),
                address,
                CFIndex(buffer.count)
            )
        }

        guard result == kIOReturnSuccess else {
            throw ControllerBackendError.reportRejected(result)
        }
        onReport?(report)
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        reportCounter = 0
        if let device {
            IOHIDUserDeviceCancel(device)
        }
        self.device = nil
    }
}

public struct DS4Feedback: Equatable, Sendable {
    public let reportID: UInt32
    public let weakMotor: UInt8
    public let strongMotor: UInt8
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    init(reportID: UInt32, bytes: [UInt8]) {
        self.reportID = reportID
        // Output report 0x05 usually arrives with its ID as byte zero. Be
        // tolerant of callers that supply the payload separately.
        let offset = bytes.first == UInt8(truncatingIfNeeded: reportID) ? 1 : 0
        weakMotor = bytes[safe: offset + 3] ?? 0
        strongMotor = bytes[safe: offset + 4] ?? 0
        red = bytes[safe: offset + 5] ?? 0
        green = bytes[safe: offset + 6] ?? 0
        blue = bytes[safe: offset + 7] ?? 0
    }

    public var summary: String {
        String(
            format: "DS4 feedback: motors %d/%d, lightbar #%02X%02X%02X",
            weakMotor, strongMotor, red, green, blue
        )
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
