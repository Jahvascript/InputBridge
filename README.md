# InputBridge for macOS

InputBridge turns keyboard and mouse input into a game-controller state for PS
Remote Play. It includes a safe simulation mode, a live controller preview, and
an experimental virtual DualShock 4 USB backend.

## Important compatibility note

The complete input pipeline is implemented, but macOS does not allow an
ordinary unsigned app to publish a system-wide virtual HID controller. Apple
requires the restricted `com.apple.developer.hid.virtual.device` entitlement.
Without an Apple-approved provisioning profile containing that entitlement,
InputBridge runs in **Simulation** mode and shows the exact controller state and
reports it would send.

Sony officially documents DualShock 4, DualSense, and DualSense Edge support in
PS Remote Play; it does not publish a virtual-controller API. The Virtual DS4
backend therefore needs final validation on a Mac signed with the entitlement.
See [Signing and entitlement setup](docs/SIGNING.md) and the
[validation plan](docs/TEST-PLAN.md).

## Default controls

| Keyboard or mouse | Controller input |
| --- | --- |
| W A S D | Left stick |
| Mouse movement | Right stick |
| Left mouse | R2 |
| Right mouse | L2 |
| Middle mouse | R3 |
| Space | Cross |
| E | Square |
| F | Circle |
| Q | L1 |
| R | R1 |
| Left Shift | L3 |
| Arrow keys | D-pad |
| Return | Options |
| Tab | Touchpad click |
| Escape | PS button |

Press **Control-Option-Command-F12** at any time to stop capture and send a
neutral report. By default, capture is also suspended whenever PS Remote Play
is not the frontmost app.

## Build and run

Requirements: macOS 12 or later and Xcode 14 or later. Xcode Command Line Tools
are enough for Simulation mode.

```sh
./scripts/build-app.sh
open dist/InputBridge.app
```

On first use, macOS will ask for Input Monitoring access. Enable InputBridge in
**System Settings > Privacy & Security > Input Monitoring**, relaunch it,
choose Simulation, and press **Start Capture**. Some managed Mac configurations
may additionally require Accessibility access.

Run the deterministic mapping/report tests with:

```sh
./scripts/test.sh
```

## Project layout

- `InputBridgeCore` — controller state, profiles, mapping, mouse filtering, and
  64-byte DualShock 4 USB report encoding.
- `InputBridgeHID` — the entitlement-aware `IOHIDUserDevice` backend.
- `InputBridgeMac` — global event capture, permission checks, Remote Play focus
  gating, and fail-safe release behavior.
- `InputBridgeApp` — a native AppKit status window and live preview.
- `InputBridgeCoreTests` — deterministic unit and golden-report tests.

The app loads `Resources/default-mapping.json` at launch. Edit that file and
rebuild to customize bindings or mouse response; an invalid profile is rejected
and the safe built-in profile is used instead.

The detailed design is in [ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Scope

This prototype maps input only. It intentionally does not intercept Remote Play
network traffic, bypass PlayStation authentication, or modify the Remote Play
app. Rumble, adaptive triggers, audio, motion sensing, and touch coordinates are
not translated.

---

## JahvaScript Open-Source Release

**Development status: Experimental prototype**

The simulation pipeline and core report-mapping tests
have been verified in the development environment.

Virtual DualShock 4 operation and compatibility with
PS Remote Play are not yet verified. Apple's approved
virtual-HID entitlement and additional integration
testing are required.

See [BUILD-REPORT.md](BUILD-REPORT.md),
[Signing](docs/SIGNING.md), and
[Testing Plan](docs/TEST-PLAN.md).

### License

Original JahvaScript project code is released under
the [MIT License](LICENSE). Third-party rights and
trademarks remain with their respective owners.

InputBridge is an independent project and is not
affiliated with or endorsed by Sony or Apple.

## Everyone Is Welcome at JahvaScript

We welcome contributors of every background, ability,
belief, identity, and experience level.

We value peace, respect, accessibility, creativity,
learning, and constructive collaboration.

- [Code of Conduct](https://github.com/Jahvascript/.github/blob/main/CODE_OF_CONDUCT.md)
- [Contributing](https://github.com/Jahvascript/.github/blob/main/CONTRIBUTING.md)
- [Accessibility](https://github.com/Jahvascript/.github/blob/main/ACCESSIBILITY.md)
- [Support](https://github.com/Jahvascript/.github/blob/main/SUPPORT.md)

Community contact: jahvascripts@gmail.com

*JahvaScript — Code with purpose. Build with unity.*
