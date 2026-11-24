# Build and verification report

Verified on October 3, 2026 using macOS 13.7.8 (Intel), Apple Swift 5.8.1,
and the macOS 13.3 Command Line Tools SDK.

## Passed here

- All four modules (`InputBridgeCore`, `InputBridgeHID`, `InputBridgeMac`, and
  `InputBridgeApp`) compiled for a macOS 12 deployment target.
- The release build produced `dist/InputBridge.app`.
- The comprehensive standalone core harness passed profile round-trip and
  validation, opposing-key behavior, mouse conversion/recentering, fail-safe
  reset, and golden DS4 report-byte checks.
- The bundle's plist and bundled JSON mapping validate.
- Strict code-signature verification passes.
- The default ad-hoc signature contains no restricted virtual-HID entitlement,
  avoiding macOS's pre-launch termination of improperly entitled builds.
- The executable remained alive through the launch check.

## Included but not executable on this host

The project contains 27 XCTest cases. This Mac's Command Line Tools installation
does not include Xcode's platform metadata or macOS XCTest module, so
`scripts/test.sh` correctly ran the standalone harness instead. With full Xcode
installed, the same script runs the complete XCTest suite and does not mask a
test failure with the fallback.

## Requires an authorized signing environment

Virtual DS4 creation and PS Remote Play acceptance were not claimed as verified.
Apple requires the managed `com.apple.developer.hid.virtual.device` entitlement,
which is not present in this environment. The app reports that limitation and
continues to work in Simulation mode. Follow `docs/SIGNING.md`, then execute the
matrix in `docs/TEST-PLAN.md` on the final provisioned build.
