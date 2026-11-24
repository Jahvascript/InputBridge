import ApplicationServices
import Foundation

/// The two privacy gates macOS may apply to a global, listen-only event tap.
public struct InputPermissionStatus: Equatable, Sendable {
    public let inputMonitoring: Bool
    public let accessibility: Bool

    public init(inputMonitoring: Bool, accessibility: Bool) {
        self.inputMonitoring = inputMonitoring
        self.accessibility = accessibility
    }

    /// Input Monitoring is the permission actually required by InputBridge's
    /// listen-only tap. Accessibility is reported because managed Macs may
    /// enforce it as an additional gate.
    public var canCapture: Bool { inputMonitoring }

    public var summary: String {
        if inputMonitoring && accessibility {
            return "Input Monitoring and Accessibility are allowed."
        }
        if inputMonitoring {
            return "Input Monitoring is allowed. Accessibility is optional."
        }
        return "Input Monitoring is required before capture can start."
    }
}

public enum InputPermission {
    public static var current: InputPermissionStatus {
        InputPermissionStatus(
            inputMonitoring: CGPreflightListenEventAccess(),
            accessibility: AXIsProcessTrusted()
        )
    }

    /// Asks macOS to show the relevant privacy prompts. The Settings panes may
    /// require the user to relaunch InputBridge after granting access.
    @discardableResult
    public static func request() -> InputPermissionStatus {
        _ = CGRequestListenEventAccess()
        return current
    }
}
