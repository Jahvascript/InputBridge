import Foundation
import InputBridgeCore

public enum ControllerBackendMode: String, CaseIterable, Sendable {
    case simulation
    case virtualDS4

    public var title: String {
        switch self {
        case .simulation: return "Simulation"
        case .virtualDS4: return "Virtual DualShock 4"
        }
    }
}

public enum ControllerBackendError: LocalizedError {
    case notStarted
    case alreadyStarted
    case virtualDeviceCreationFailed
    case reportRejected(IOReturn)

    public var errorDescription: String? {
        switch self {
        case .notStarted:
            return "The controller output has not been started."
        case .alreadyStarted:
            return "The controller output is already running."
        case .virtualDeviceCreationFailed:
            return "macOS refused to create the virtual controller. A signed build with the com.apple.developer.hid.virtual.device entitlement is required; ad-hoc signing cannot grant that Apple-managed entitlement. Use Simulation mode when the entitlement is unavailable."
        case .reportRejected(let value):
            return String(format: "macOS rejected the virtual-controller report (IOKit 0x%08X).", UInt32(bitPattern: value))
        }
    }
}

public protocol ControllerBackend: AnyObject {
    var displayName: String { get }
    var isRunning: Bool { get }
    var onLog: ((String) -> Void)? { get set }

    func start() throws
    func submit(_ state: ControllerState) throws
    func stop()
}

public enum ControllerBackendFactory {
    public static func make(_ mode: ControllerBackendMode) -> ControllerBackend {
        switch mode {
        case .simulation:
            return SimulationControllerBackend()
        case .virtualDS4:
            return VirtualDS4ControllerBackend()
        }
    }
}
