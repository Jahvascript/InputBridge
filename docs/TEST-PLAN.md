# Verification plan

## Automated checks included in the project

- default profile and invalid-value validation
- key down/up idempotence and key-repeat handling
- opposing direction cancellation and restoration
- button and trigger press/release behavior
- mouse sensitivity, clamp, smoothing, and time-based recentering
- reset-to-neutral behavior
- neutral and populated 64-byte DS4 golden reports
- stick endpoint, D-pad, button-bit, trigger, and packet-counter encoding

## Manual simulation checks

1. Launch InputBridge in Simulation mode.
2. Deny permission and confirm Start provides an actionable error.
3. Grant permission, relaunch, and start capture.
4. Confirm every default control in the mapping table updates the preview.
5. Hold a mapped input, switch away from Remote Play, and confirm the preview
   immediately returns to neutral.
6. Confirm Control-Option-Command-F12 stops capture and releases every input.
7. Force an event-tap timeout (for example, by pausing the process in a
   debugger), resume, and confirm no input remains stuck.

## Signed integration checks

These checks require a provisioning profile with Apple's virtual-HID
entitlement:

1. Select Virtual DS4 and confirm the app reports successful device creation.
2. Inspect IORegistry and confirm a USB-transport gamepad with VID/PID
   `054C:09CC`, product `Wireless Controller`, and a 64-byte input report.
3. Use a controller test client to exercise axes, hat, 14 buttons, and triggers.
4. Confirm output and feature-report callbacks complete without timeouts.
5. Launch PS Remote Play, connect to both a PS4 and PS5 where available, and
   record whether the controller appears before and after session connection.
6. Test every mapped input, multi-key chords, focus loss, emergency stop,
   reconnect, sleep/wake, and app termination.
7. Measure report cadence and end-to-end latency; verify there is no unbounded
   queue growth under high mouse-motion rates.

If IORegistry sees the controller but Remote Play does not, capture the exact
IOHID properties and report requests made for a physical DS4 and compare them
with the virtual device. Do not declare compatibility until this matrix passes
on the final signed build.
