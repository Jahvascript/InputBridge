#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODULE_CACHE="$PROJECT_DIR/.build/module-cache"
SMOKE_DIR="$PROJECT_DIR/.build/smoke"

mkdir -p "$MODULE_CACHE" "$SMOKE_DIR"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE"

echo "Running InputBridge tests…"
if xcrun --sdk macosx --show-sdk-platform-path >/dev/null 2>&1; then
  # A real test failure must stay a failure; the smoke harness is only a
  # toolchain-compatibility fallback, never a way to mask failing unit tests.
  swift test --package-path "$PROJECT_DIR"
  exit $?
else
  echo "Swift Package Manager is unavailable with this Command Line Tools installation."
  echo "Running the deterministic core smoke harness instead…"
fi

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
TARGET_TRIPLE="$(uname -m)-apple-macosx12.0"
swiftc \
  -target "$TARGET_TRIPLE" \
  -sdk "$SDK_PATH" \
  -module-cache-path "$MODULE_CACHE" \
  "$PROJECT_DIR"/Sources/InputBridgeCore/*.swift \
  "$PROJECT_DIR/Tests/Smoke/main.swift" \
  -o "$SMOKE_DIR/InputBridgeSmoke"

"$SMOKE_DIR/InputBridgeSmoke"
