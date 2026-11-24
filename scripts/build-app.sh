#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGURATION="${1:-release}"

case "$CONFIGURATION" in
  debug|release) ;;
  *)
    echo "Usage: $0 [debug|release]" >&2
    exit 64
    ;;
esac

MODULE_CACHE="$PROJECT_DIR/.build/module-cache"
BUILD_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$BUILD_DIR/InputBridge.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MODULE_CACHE" "$BUILD_DIR"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE"

echo "Building InputBridge ($CONFIGURATION)…"
if xcrun --sdk macosx --show-sdk-platform-path >/dev/null 2>&1; then
  # With a complete Xcode installation, a SwiftPM failure is a real build
  # failure and must not be hidden by the fallback compiler path.
  swift build --package-path "$PROJECT_DIR" -c "$CONFIGURATION" --product InputBridgeApp
  BIN_DIR="$(swift build --package-path "$PROJECT_DIR" -c "$CONFIGURATION" --show-bin-path)"
else
  echo
  echo "This Command Line Tools installation has no macOS platform metadata."
  echo "Falling back to the equivalent four-module swiftc build…"

  MANUAL_DIR="$PROJECT_DIR/.build/manual-$CONFIGURATION"
  SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
  TARGET_TRIPLE="$(uname -m)-apple-macosx12.0"
  rm -rf "$MANUAL_DIR"
  mkdir -p "$MANUAL_DIR"

  OPTIMIZATION=()
  if [[ "$CONFIGURATION" == "release" ]]; then
    OPTIMIZATION=(-O)
  else
    OPTIMIZATION=(-Onone -g)
  fi

  COMMON=(
    "${OPTIMIZATION[@]}"
    -target "$TARGET_TRIPLE"
    -sdk "$SDK_PATH"
    -module-cache-path "$MODULE_CACHE"
  )

  swiftc "${COMMON[@]}" -emit-module -emit-library -static -parse-as-library \
    -module-name InputBridgeCore \
    "$PROJECT_DIR"/Sources/InputBridgeCore/*.swift \
    -emit-module-path "$MANUAL_DIR/InputBridgeCore.swiftmodule" \
    -o "$MANUAL_DIR/libInputBridgeCore.a"

  swiftc "${COMMON[@]}" -emit-module -emit-library -static -parse-as-library \
    -module-name InputBridgeHID \
    "$PROJECT_DIR"/Sources/InputBridgeHID/*.swift \
    -I "$MANUAL_DIR" -framework IOKit \
    -emit-module-path "$MANUAL_DIR/InputBridgeHID.swiftmodule" \
    -o "$MANUAL_DIR/libInputBridgeHID.a"

  swiftc "${COMMON[@]}" -emit-module -emit-library -static -parse-as-library \
    -module-name InputBridgeMac \
    "$PROJECT_DIR"/Sources/InputBridgeMac/*.swift \
    -I "$MANUAL_DIR" -framework AppKit -framework ApplicationServices \
    -emit-module-path "$MANUAL_DIR/InputBridgeMac.swiftmodule" \
    -o "$MANUAL_DIR/libInputBridgeMac.a"

  swiftc "${COMMON[@]}" \
    "$PROJECT_DIR"/Sources/InputBridgeApp/*.swift \
    -I "$MANUAL_DIR" -L "$MANUAL_DIR" \
    -lInputBridgeMac -lInputBridgeHID -lInputBridgeCore \
    -framework AppKit -framework ApplicationServices -framework IOKit \
    -o "$MANUAL_DIR/InputBridgeApp"

  BIN_DIR="$MANUAL_DIR"
fi

if [[ ! -x "$BIN_DIR/InputBridgeApp" ]]; then
  echo "Build succeeded but InputBridgeApp was not found in $BIN_DIR" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_DIR/InputBridgeApp" "$MACOS_DIR/InputBridgeApp"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/default-mapping.json" "$RESOURCES_DIR/default-mapping.json"

if [[ "${INPUTBRIDGE_SKIP_SIGNING:-0}" != "1" ]]; then
  SIGN_IDENTITY="${INPUTBRIDGE_SIGN_IDENTITY:-}"
  if [[ -n "$SIGN_IDENTITY" && "$SIGN_IDENTITY" != "-" ]]; then
    codesign --force --timestamp=none --sign "$SIGN_IDENTITY" \
      --entitlements "$PROJECT_DIR/InputBridge.entitlements" \
      "$APP_BUNDLE"
  else
    # An ad-hoc signature deliberately carries no restricted entitlements.
    # This is the safe, launchable default for Simulation mode.
    codesign --force --timestamp=none --sign - "$APP_BUNDLE"
  fi
fi

echo
echo "Created: $APP_BUNDLE"
if [[ -z "${INPUTBRIDGE_SIGN_IDENTITY:-}" || "${INPUTBRIDGE_SIGN_IDENTITY:-}" == "-" ]]; then
  echo "Note: the default ad-hoc signature intentionally omits Apple's managed virtual-HID entitlement."
  echo "Simulation mode still works; Virtual DualShock 4 will show a clear error."
fi
