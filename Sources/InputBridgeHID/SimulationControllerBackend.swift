import Foundation
import InputBridgeCore

/// Runs the entire mapping/report path without publishing a HID device. This
/// is useful for tuning mappings and is always available on unsigned builds.
public final class SimulationControllerBackend: ControllerBackend {
    public let displayName = "Simulation"
    public private(set) var isRunning = false
    public var onLog: ((String) -> Void)?
    public var onReport: (([UInt8]) -> Void)?

    private var lastReport: [UInt8]?
    private var lastLogTime: TimeInterval = 0

    public init() {}

    public func start() throws {
        guard !isRunning else { throw ControllerBackendError.alreadyStarted }
        isRunning = true
        lastReport = nil
        lastLogTime = 0
        onLog?("Simulation controller started; no virtual HID device is being published.")
    }

    public func submit(_ state: ControllerState) throws {
        guard isRunning else { throw ControllerBackendError.notStarted }
        let report = DS4USBReportEncoder.encode(state: state)
        onReport?(report)

        let now = ProcessInfo.processInfo.systemUptime
        if report != lastReport, now - lastLogTime >= 0.1 {
            let prefix = report.prefix(10).map { String(format: "%02X", $0) }.joined(separator: " ")
            onLog?("DS4 input: \(prefix)")
            lastLogTime = now
        }
        lastReport = report
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        lastReport = nil
        lastLogTime = 0
        onLog?("Simulation controller stopped.")
    }
}
