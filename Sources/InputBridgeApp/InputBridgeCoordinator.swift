import Foundation
import InputBridgeCore
import InputBridgeHID
import InputBridgeMac

final class InputBridgeCoordinator {
    var onRunningChanged: ((Bool) -> Void)?
    var onStatus: ((String) -> Void)?
    var onState: ((ControllerState, [UInt8]) -> Void)?
    var onLog: ((String) -> Void)?

    private(set) var isRunning = false
    private let capture = EventTapInputCapture()
    private var mapper: InputMapper
    private let profileLoadMessage: String
    private var backend: ControllerBackend?
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var focusOnly = true
    private var wasFocusAllowed = false

    init() {
        let loaded = Self.loadBundledProfile()
        mapper = InputMapper(profile: loaded.profile)
        profileLoadMessage = loaded.message
        capture.onEvent = { [weak self] event in
            self?.receive(event)
        }
        capture.onEmergencyStop = { [weak self] reason in
            self?.stop(reason: reason)
        }
    }

    deinit {
        stop(reason: "Application closing")
    }

    func start(mode: ControllerBackendMode, focusOnly: Bool) throws {
        guard !isRunning else { return }

        let output = ControllerBackendFactory.make(mode)
        output.onLog = { [weak self] line in
            DispatchQueue.main.async {
                self?.onLog?(line)
            }
        }

        do {
            try output.start()
            backend = output
            try capture.start()
        } catch {
            output.stop()
            backend = nil
            throw error
        }

        self.focusOnly = focusOnly
        wasFocusAllowed = !focusOnly || RemotePlayFocus.isRemotePlayFrontmost
        mapper.reset()
        isRunning = true
        lastTick = ProcessInfo.processInfo.systemUptime
        startTimer()
        publish(mapper.state)
        onRunningChanged?(true)
        updateStatus()
        onLog?(profileLoadMessage)
        onLog?("Capture started. Control-Option-Command-F12 is always the emergency stop.")
    }

    func stop(reason: String = "Stopped") {
        guard isRunning || backend != nil else { return }
        isRunning = false
        timer?.invalidate()
        timer = nil

        let neutral = mapper.reset()
        try? backend?.submit(neutral)
        publish(neutral)
        capture.stop()
        backend?.stop()
        backend = nil

        onRunningChanged?(false)
        onStatus?(reason)
        onLog?(reason)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func tick() {
        guard isRunning else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let delta = min(max(now - lastTick, 0), 0.1)
        lastTick = now

        let focusAllowed = !focusOnly || RemotePlayFocus.isRemotePlayFrontmost
        if focusAllowed != wasFocusAllowed {
            wasFocusAllowed = focusAllowed
            if !focusAllowed {
                let neutral = mapper.reset()
                submit(neutral)
                onLog?("Input neutralized because PS Remote Play lost focus.")
            }
            updateStatus()
        }

        guard focusAllowed else { return }
        submit(mapper.tick(deltaTime: delta))
    }

    private func receive(_ event: CapturedInputEvent) {
        guard isRunning else { return }
        let focusAllowed = !focusOnly || RemotePlayFocus.isRemotePlayFrontmost
        guard focusAllowed || event.isReset else { return }

        switch event {
        case .keyDown(let keyCode, let isRepeat):
            if !isRepeat { mapper.keyDown(keyCode) }
        case .keyUp(let keyCode):
            mapper.keyUp(keyCode)
        case .mouseMoved(let deltaX, let deltaY):
            mapper.mouseMoved(deltaX: deltaX, deltaY: deltaY)
        case .mouseButtonDown(let button):
            mapper.mouseButtonDown(button)
        case .mouseButtonUp(let button):
            mapper.mouseButtonUp(button)
        case .reset:
            submit(mapper.reset())
        }
    }

    private func submit(_ state: ControllerState) {
        guard isRunning, let backend else { return }
        do {
            try backend.submit(state)
            publish(state)
        } catch {
            let message = error.localizedDescription
            onLog?(message)
            stop(reason: "Controller output failed: \(message)")
        }
    }

    private func publish(_ state: ControllerState) {
        onState?(state, DS4USBReportEncoder.encode(state: state))
    }

    private func updateStatus() {
        if focusOnly && !RemotePlayFocus.isRemotePlayFrontmost {
            onStatus?("Paused safely — switch to PS Remote Play")
        } else {
            onStatus?("Translating input to \(backend?.displayName ?? "controller")")
        }
    }

    private static func loadBundledProfile() -> (profile: MappingProfile, message: String) {
        guard let url = Bundle.main.url(forResource: "default-mapping", withExtension: "json") else {
            return (.default, "Bundled mapping was not found; using the built-in default profile.")
        }

        do {
            let data = try Data(contentsOf: url)
            let profile = try JSONDecoder().decode(MappingProfile.self, from: data)
            try ProfileValidator.validateOrThrow(profile)
            return (profile, "Loaded mapping profile: \(profile.name)")
        } catch {
            return (.default, "Bundled mapping is invalid (\(error.localizedDescription)); using the built-in default profile.")
        }
    }
}

private extension CapturedInputEvent {
    var isReset: Bool {
        if case .reset = self { return true }
        return false
    }
}
