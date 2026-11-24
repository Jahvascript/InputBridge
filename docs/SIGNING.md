# Signing and virtual-HID entitlement

## Why special signing is required

Apple's `IOHIDUserDeviceCreateWithProperties` documentation states that
creating a virtual HID device requires:

```text
com.apple.developer.hid.virtual.device
```

This is an app entitlement, not the similarly named DriverKit virtual-device
entitlement. Apple DTS describes the DriverKit virtual-device entitlement as
defunct and recommends the CoreHID/IOHIDUserDevice route for software-only HID
devices.

## Developer-account setup

1. Join the Apple Developer Program and create an explicit App ID for the final
   bundle identifier.
2. In Certificates, Identifiers & Profiles, submit a Capability Request for
   **HID Virtual Device** (`com.apple.developer.hid.virtual.device`).
3. After approval, enable that capability for the App ID and regenerate the
   Developer ID or Development provisioning profile.
4. Sign the app with that identity/profile plus `InputBridge.entitlements`.
   The build script uses a safe ad-hoc signature with no restricted entitlement
   by default. To select an approved signing identity, run:

   ```sh
   INPUTBRIDGE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
     ./scripts/build-app.sh release
   ```

   If Apple's approved profile must be embedded for the chosen distribution
   path, copy it to `dist/InputBridge.app/Contents/embedded.provisionprofile`
   before the final signing pass, or configure the project in Xcode so profile
   embedding and signing are managed together.
5. Verify the signed result before launching:

   ```sh
   codesign -d --entitlements :- dist/InputBridge.app
   ```

   The output must show the entitlement as `true`, and the embedded profile (if
   required) must authorize the same key. Adding the key to a plist or an
   ad-hoc signature is not sufficient; on current macOS such an invalid build
   can be terminated before `main` runs.

6. Grant InputBridge Accessibility/Input Monitoring permission in System
   Settings and relaunch it.

For distribution, enable hardened runtime, sign every nested executable,
notarize the app, and staple the notarization ticket. Do not ad-hoc sign a
release that claims to provide Virtual DS4 mode.

## API choice

The project uses `IOHIDUserDevice` for macOS 12–14 compatibility. Apple's newer
CoreHID `HIDVirtualDevice` API provides a Swift-native wrapper on newer systems,
but it is governed by the same virtual-device entitlement. A DriverKit system
extension would add installation, approval, and signing complexity without
removing the entitlement requirement.

References:

- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.hid.virtual.device
- https://developer.apple.com/documentation/corehid/creatingvirtualdevices
