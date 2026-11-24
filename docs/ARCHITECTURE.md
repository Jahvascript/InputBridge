# Architecture

## Goals

InputBridge has four separable responsibilities:

```text
CGEvent tap                 Mapping core                 Controller backend
keyboard + mouse  ──────▶  ControllerState  ──────▶  Simulation logger
      │                           │                      or IOHIDUserDevice
      └── focus/permission gate   └── DS4 report encoder       │
                                                               ▼
                                                     PS Remote Play
```

The mapping and report layers contain no AppKit or IOKit dependencies. That
makes timing, opposing-key behavior, mouse decay, and report bytes testable
without privacy permission or special signing.

## Capture and safety

`CGEventTap` observes keyboard, mouse-button, and mouse-motion events. Capture
starts only after an explicit click. The default frontmost-app gate accepts
mapped input only while the Remote Play bundle is active. Stopping capture,
losing focus, an event-tap timeout, or the emergency shortcut clears all held
keys/buttons and emits a neutral controller report so inputs cannot stick.

The event callback performs minimal work. State mutation and controller output
are serialized, while a bounded update timer handles mouse recentering and
report delivery.

## Mapping model

`MappingProfile` is Codable and validates sensitivity, smoothing, recentering,
and bindings. `InputMapper` tracks physical key state separately from controller
state. Opposite directions cancel, so pressing A+D or W+S is neutral and
releasing either key restores the still-held direction.

Mouse deltas pass through sensitivity, smoothing, clamping, and time-based
recentering. The result is a right-stick vector in `-1...1`.

## Report format

The virtual backend models a wired DualShock 4 v2:

- USB vendor/product ID `054C:09CC`
- Generic Desktop / Game Pad top-level collection
- report ID `0x01`, 64-byte input report
- four 8-bit stick axes, hat switch, 14 digital buttons, and two 8-bit triggers
- neutral inertial/touch fields

The encoder packs state using the layout consumed by Sony-compatible DS4
drivers. The virtual backend adds the six-bit packet counter, reports a wired
controller with a full battery, accepts the 32-byte output report, and answers
the calibration, pairing, and firmware feature requests used during normal DS4
initialization. Other descriptor-defined vendor feature reports return an
unsupported result and remain part of signed-device compatibility testing.

## Backend boundary

Both output modes implement the same backend interface:

- **Simulation** retains/logs encoded reports and always works.
- **Virtual DS4** creates an `IOHIDUserDevice`, publishes USB identity
  properties, and submits reports with monotonic timestamps.

Creation failure is surfaced to the UI with actionable entitlement guidance;
the app does not silently claim that a controller exists.

## Compatibility boundary

Sony supports physical DualShock 4, DualSense, and DualSense Edge controllers
in Remote Play on Mac, but does not specify how it recognizes them. Matching a
DS4 HID interface is the most direct experiment, not an official Sony contract.
Successful macOS enumeration, GameController discovery, and Remote Play input
must all be verified on the final signed build.
