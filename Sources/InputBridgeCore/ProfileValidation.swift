import Foundation

public enum MappingValidationCode: String, Codable, Sendable {
    case unsupportedSchemaVersion
    case emptyName
    case duplicateKeyCode
    case invalidMouseButton
    case duplicateMouseButton
    case invalidSensitivity
    case invalidSmoothing
    case invalidRecenterSpeed
}

public struct MappingValidationIssue: Codable, Equatable, Sendable {
    public var code: MappingValidationCode
    public var path: String
    public var message: String

    public init(code: MappingValidationCode, path: String, message: String) {
        self.code = code
        self.path = path
        self.message = message
    }
}

public struct MappingProfileValidationError: Error, Equatable, LocalizedError, Sendable {
    public let issues: [MappingValidationIssue]

    public init(issues: [MappingValidationIssue]) {
        self.issues = issues
    }

    public var errorDescription: String? {
        issues.map(\.message).joined(separator: " ")
    }
}

/// Validates profiles before they are activated or persisted.
public enum ProfileValidator {
    public static func validate(_ profile: MappingProfile) -> [MappingValidationIssue] {
        var issues: [MappingValidationIssue] = []

        if profile.schemaVersion != MappingProfile.currentSchemaVersion {
            issues.append(MappingValidationIssue(
                code: .unsupportedSchemaVersion,
                path: "schemaVersion",
                message: "Schema version \(profile.schemaVersion) is unsupported; expected \(MappingProfile.currentSchemaVersion)."
            ))
        }

        if profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(MappingValidationIssue(
                code: .emptyName,
                path: "name",
                message: "Profile name must not be empty."
            ))
        }

        var seenKeyCodes: Set<UInt16> = []
        for (index, binding) in profile.keyboardBindings.enumerated() {
            if !seenKeyCodes.insert(binding.keyCode).inserted {
                issues.append(MappingValidationIssue(
                    code: .duplicateKeyCode,
                    path: "keyboardBindings[\(index)].keyCode",
                    message: "Key code \(binding.keyCode) is bound more than once."
                ))
            }
        }

        var seenMouseButtons: Set<Int> = []
        for (index, binding) in profile.mouse.buttonBindings.enumerated() {
            if binding.buttonNumber < 0 {
                issues.append(MappingValidationIssue(
                    code: .invalidMouseButton,
                    path: "mouse.buttonBindings[\(index)].buttonNumber",
                    message: "Mouse button numbers must be zero or greater."
                ))
            }
            if !seenMouseButtons.insert(binding.buttonNumber).inserted {
                issues.append(MappingValidationIssue(
                    code: .duplicateMouseButton,
                    path: "mouse.buttonBindings[\(index)].buttonNumber",
                    message: "Mouse button \(binding.buttonNumber) is bound more than once."
                ))
            }
        }

        if !isFiniteAndInRange(profile.mouse.sensitivityX, 0...1) {
            issues.append(MappingValidationIssue(
                code: .invalidSensitivity,
                path: "mouse.sensitivityX",
                message: "Horizontal mouse sensitivity must be finite and between 0 and 1."
            ))
        }
        if !isFiniteAndInRange(profile.mouse.sensitivityY, 0...1) {
            issues.append(MappingValidationIssue(
                code: .invalidSensitivity,
                path: "mouse.sensitivityY",
                message: "Vertical mouse sensitivity must be finite and between 0 and 1."
            ))
        }
        if !profile.mouse.smoothing.isFinite || profile.mouse.smoothing < 0 || profile.mouse.smoothing >= 1 {
            issues.append(MappingValidationIssue(
                code: .invalidSmoothing,
                path: "mouse.smoothing",
                message: "Mouse smoothing must be finite, at least 0, and less than 1."
            ))
        }
        if !isFiniteAndInRange(profile.mouse.recenterSpeed, 0...100) {
            issues.append(MappingValidationIssue(
                code: .invalidRecenterSpeed,
                path: "mouse.recenterSpeed",
                message: "Mouse recenter speed must be finite and between 0 and 100."
            ))
        }

        return issues
    }

    public static func validateOrThrow(_ profile: MappingProfile) throws {
        let issues = validate(profile)
        guard issues.isEmpty else {
            throw MappingProfileValidationError(issues: issues)
        }
    }

    private static func isFiniteAndInRange(_ value: Float, _ range: ClosedRange<Float>) -> Bool {
        value.isFinite && range.contains(value)
    }
}

public extension MappingProfile {
    var validationIssues: [MappingValidationIssue] {
        ProfileValidator.validate(self)
    }

    var isValid: Bool {
        validationIssues.isEmpty
    }
}
