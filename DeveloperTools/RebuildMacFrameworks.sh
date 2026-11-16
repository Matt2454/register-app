#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/register-mac-rebuild.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
command -v flutter >/dev/null
command -v pod >/dev/null
# Build outside iCloud-backed folders, which can add signing-breaking metadata.
rsync -a --exclude=.dart_tool --exclude=build --exclude=Pods --exclude=.symlinks \
  --exclude=ephemeral "$ROOT/Source/Flutter/" "$STAGE/app/"
cd "$STAGE/app"
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build macos-framework --no-debug --no-profile --no-pub --no-codesign \
  --output="$STAGE/frameworks"
python3 - "$STAGE/frameworks/Release" "$ROOT/Mac/Frameworks" <<'PY'
from pathlib import Path
import plistlib, shutil, subprocess, sys
source, target = map(Path, sys.argv[1:])
frameworks = {p.name for p in source.glob('*.xcframework') if p.name != 'integration_test.xcframework'}
expected = {p.name for p in target.glob('*.xcframework')}
if frameworks != expected:
    raise SystemExit('Plugin list changed. Update the Mac Xcode project before replacing its frameworks.')
engine = source / 'FlutterMacOS.xcframework'
for path in engine.rglob('dSYMs'):
    shutil.rmtree(path)
info = engine / 'Info.plist'
plist = plistlib.loads(info.read_bytes())
for library in plist['AvailableLibraries']:
    library.pop('DebugSymbolsPath', None)
info.write_bytes(plistlib.dumps(plist, sort_keys=False))
subprocess.run(['codesign', '--remove-signature', str(engine)], check=True)
for name in sorted(frameworks):
    shutil.rmtree(target / name)
    shutil.copytree(source / name, target / name, symlinks=True)
PY
# Mirror the native source used by the standalone Mac project.
for name in AppDelegate.swift MainFlutterWindow.swift CalendarExport.swift Info.plist Release.entitlements; do
  cp "$ROOT/Source/Flutter/macos/Runner/$name" "$ROOT/Mac/App/$name"
done
cp macos/Flutter/GeneratedPluginRegistrant.swift "$ROOT/Mac/App/GeneratedPluginRegistrant.swift"
cp "$ROOT/Source/Flutter/macos/RegisterWidget/RegisterWidget.swift" "$ROOT/Mac/RegisterWidget/RegisterWidget.swift"
cp "$ROOT/Source/Flutter/macos/RegisterWidget/Info.plist" "$ROOT/Mac/RegisterWidget/Info.plist"
cp "$ROOT/Source/Flutter/macos/RegisterWidget/RegisterWidget.entitlements" "$ROOT/Mac/RegisterWidget/RegisterWidget.entitlements"
for language in en it de; do
  cp "$ROOT/Source/Flutter/macos/Runner/$language.lproj/InfoPlist.strings" "$ROOT/Mac/App/$language.lproj/InfoPlist.strings"
  cp "$ROOT/Source/Flutter/macos/Runner/$language.lproj/MainMenu.strings" "$ROOT/Mac/App/$language.lproj/MainMenu.strings"
  cp "$ROOT/Source/Flutter/macos/RegisterWidget/$language.lproj/Localizable.strings" "$ROOT/Mac/RegisterWidget/$language.lproj/Localizable.strings"
done
sed 's/customModule="Runner"/customModule="Register"/g' \
  "$ROOT/Source/Flutter/macos/Runner/Base.lproj/MainMenu.xib" > "$ROOT/Mac/App/Base.lproj/MainMenu.xib"
echo 'Mac frameworks updated. Open Mac/Register-Mac.xcodeproj and build.'
