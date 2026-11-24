import AppKit
import InputBridgeCore
import InputBridgeHID
import InputBridgeMac

final class InputBridgeViewController: NSViewController {
    private let coordinator = InputBridgeCoordinator()
    private let permissionLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "Ready")
    private let foregroundLabel = NSTextField(labelWithString: "")
    private let modePopup = NSPopUpButton()
    private let focusOnlyCheckbox = NSButton(checkboxWithTitle: "Only translate while PS Remote Play is frontmost", target: nil, action: nil)
    private let startButton = NSButton(title: "Start", target: nil, action: nil)
    private let preview = ControllerPreviewView()
    private let reportLabel = NSTextField(labelWithString: "01 80 80 80 80 08 00 00 00 00")
    private let logView = NSTextView()
    private var permissionTimer: Timer?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 660, height: 690))
        buildInterface()
        connectCoordinator()
        refreshPermission()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshPermission()
        }
    }

    override func viewWillDisappear() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        super.viewWillDisappear()
    }

    func stop() {
        coordinator.stop(reason: "Application closing")
    }

    private func buildInterface() {
        let title = NSTextField(labelWithString: "InputBridge")
        title.font = .systemFont(ofSize: 26, weight: .bold)
        let subtitle = NSTextField(labelWithString: "Keyboard + mouse → controller → PS Remote Play")
        subtitle.textColor = .secondaryLabelColor

        let header = NSStackView(views: [title, subtitle])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2

        permissionLabel.font = .systemFont(ofSize: 12)
        permissionLabel.lineBreakMode = .byWordWrapping
        permissionLabel.maximumNumberOfLines = 2
        let permissionButton = NSButton(title: "Request Permission", target: self, action: #selector(requestPermission))
        permissionButton.bezelStyle = .rounded
        let permissionRow = NSStackView(views: [permissionLabel, permissionButton])
        permissionRow.orientation = .horizontal
        permissionRow.alignment = .centerY
        permissionRow.spacing = 12
        permissionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        permissionButton.setContentHuggingPriority(.required, for: .horizontal)

        modePopup.addItems(withTitles: ControllerBackendMode.allCases.map(\.title))
        modePopup.target = self
        modePopup.action = #selector(modeChanged)
        modePopup.selectItem(at: 0)
        let modeRow = labeledRow("Output", control: modePopup)

        focusOnlyCheckbox.state = .on
        focusOnlyCheckbox.target = self
        focusOnlyCheckbox.action = #selector(focusSafetyChanged)

        startButton.target = self
        startButton.action = #selector(toggleSession)
        startButton.bezelStyle = .texturedRounded
        startButton.controlSize = .large
        startButton.keyEquivalent = "\r"

        statusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        foregroundLabel.font = .systemFont(ofSize: 11)
        foregroundLabel.textColor = .secondaryLabelColor

        let controlRow = NSStackView(views: [startButton, statusLabel])
        controlRow.orientation = .horizontal
        controlRow.alignment = .centerY
        controlRow.spacing = 14

        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.heightAnchor.constraint(equalToConstant: 170).isActive = true
        reportLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        reportLabel.textColor = .secondaryLabelColor

        logView.isEditable = false
        logView.isSelectable = true
        logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.backgroundColor = .textBackgroundColor
        logView.textContainerInset = NSSize(width: 8, height: 8)
        logView.isVerticallyResizable = true
        logView.isHorizontallyResizable = false
        logView.autoresizingMask = [.width]
        logView.textContainer?.widthTracksTextView = true
        let scroll = NSScrollView()
        scroll.documentView = logView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 128).isActive = true

        let note = NSTextField(wrappingLabelWithString: "Virtual DualShock 4 requires Apple’s managed virtual-HID entitlement. Simulation mode verifies capture and mapping without publishing a controller. Emergency stop: ⌃⌥⌘F12.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [
            header, separator(), permissionRow, modeRow, focusOnlyCheckbox,
            controlRow, foregroundLabel, separator(), preview, reportLabel,
            separator(), scroll, note
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        for arranged in stack.arrangedSubviews {
            arranged.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])

        appendLog("Choose Simulation first to verify your mapping safely.")
    }

    private func connectCoordinator() {
        coordinator.onRunningChanged = { [weak self] running in
            guard let self else { return }
            self.startButton.title = running ? "Stop" : "Start"
            self.modePopup.isEnabled = !running
            self.focusOnlyCheckbox.isEnabled = !running
        }
        coordinator.onStatus = { [weak self] text in
            self?.statusLabel.stringValue = text
        }
        coordinator.onState = { [weak self] state, report in
            self?.preview.state = state
            self?.reportLabel.stringValue = report.prefix(10).map { String(format: "%02X", $0) }.joined(separator: " ")
        }
        coordinator.onLog = { [weak self] text in
            self?.appendLog(text)
        }
    }

    @objc private func requestPermission() {
        _ = InputPermission.request()
        refreshPermission()
        appendLog("Permission requested. If you changed Privacy & Security settings, relaunch InputBridge.")
    }

    @objc private func modeChanged() {
        let mode = ControllerBackendMode.allCases[modePopup.indexOfSelectedItem]
        if mode == .virtualDS4 {
            statusLabel.stringValue = "Virtual mode requires a provisioned HID entitlement"
        } else {
            statusLabel.stringValue = "Ready"
        }
    }

    @objc private func focusSafetyChanged() {
        // The value is read when the session starts; keeping the control locked
        // during capture makes the safety boundary explicit.
    }

    @objc private func toggleSession() {
        if coordinator.isRunning {
            coordinator.stop()
            return
        }

        let mode = ControllerBackendMode.allCases[modePopup.indexOfSelectedItem]
        do {
            try coordinator.start(mode: mode, focusOnly: focusOnlyCheckbox.state == .on)
        } catch {
            statusLabel.stringValue = "Could not start"
            appendLog(error.localizedDescription)
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    private func refreshPermission() {
        let permission = InputPermission.current
        permissionLabel.stringValue = permission.summary
        permissionLabel.textColor = permission.canCapture ? .systemGreen : .systemOrange
        foregroundLabel.stringValue = "Frontmost app: \(RemotePlayFocus.frontmostApplicationName)"
    }

    private func appendLog(_ line: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let rendered = "[\(formatter.string(from: Date()))] \(line)\n"
        logView.textStorage?.append(NSAttributedString(string: rendered, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]))
        if let storage = logView.textStorage, storage.length > 30_000 {
            storage.deleteCharacters(in: NSRange(location: 0, length: storage.length - 20_000))
        }
        logView.scrollToEndOfDocument(nil)
    }

    private func labeledRow(_ label: String, control: NSView) -> NSStackView {
        let text = NSTextField(labelWithString: label)
        text.font = .systemFont(ofSize: 13, weight: .medium)
        text.translatesAutoresizingMaskIntoConstraints = false
        text.widthAnchor.constraint(equalToConstant: 90).isActive = true
        let row = NSStackView(views: [text, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}
