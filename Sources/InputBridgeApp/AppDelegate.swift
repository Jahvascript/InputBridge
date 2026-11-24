import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private let viewController = InputBridgeViewController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 690),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "InputBridge"
        window.contentViewController = viewController
        window.center()
        window.setFrameAutosaveName("InputBridgeMainWindow")
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewController.stop()
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About InputBridge", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit InputBridge", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }
}
