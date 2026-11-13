#!/bin/bash
# Build the shared Register application for iPhone/iPad without signing.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != Darwin ]]; then
  echo "iOS builds require macOS and Xcode." >&2
  exit 1
fi

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

command -v flutter >/dev/null || { echo "Add Flutter 3.47.5 to PATH." >&2; exit 1; }
xcrun --sdk iphoneos --show-sdk-path >/dev/null

mode="${1:-device}"
case "$mode" in
  device|simulator|prepare) ;;
  *) echo "Usage: $0 [device|simulator|prepare]" >&2; exit 2 ;;
esac

flutter pub get
dart run build_runner build --delete-conflicting-outputs

case "$mode" in
  device) flutter build ios --release --no-codesign ;;
  simulator) flutter build ios --simulator --debug ;;
  prepare)
    flutter build ios --release --config-only --no-codesign
    echo "Open ios/Runner.xcworkspace, choose your signing team and iPhone, then Run."
    ;;
esac
