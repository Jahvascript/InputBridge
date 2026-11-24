import AppKit
import Foundation

/// Focus gate used to make sure a mapping session cannot drive an unrelated
/// foreground app. Name matching is retained as a fallback because Sony has
/// shipped Remote Play under more than one bundle identifier.
public enum RemotePlayFocus {
    private static let knownBundleIdentifiers: Set<String> = [
        "com.playstation.RemotePlay",
        "com.sony.RemotePlay",
        "com.sony.RemotePlay-Mac",
        "com.sony.PS4RemotePlay"
    ]

    public static var isRemotePlayFrontmost: Bool {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        if let identifier = application.bundleIdentifier,
           knownBundleIdentifiers.contains(identifier) {
            return true
        }

        let name = (application.localizedName ?? "").lowercased()
        return name == "remote play" ||
            name == "ps remote play" ||
            name.contains("playstation remote play")
    }

    public static var frontmostApplicationName: String {
        NSWorkspace.shared.frontmostApplication?.localizedName ?? "No application"
    }
}
