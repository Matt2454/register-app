#!/bin/bash
# Optional developer task. This is never run by the standalone Xcode project.
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
flutter_bin="$(command -v flutter || true)"
if [[ -z "$flutter_bin" ]]; then
  echo "Rebuilding Dart changes requires Flutter 3.47.5 on PATH." >&2
  exit 1
fi
flutter_version="$("$flutter_bin" --version)"
case "$flutter_version" in
  'Flutter 3.47.5 '*) ;;
  *) echo "Use Flutter 3.47.5 to match the bundled runtime." >&2; exit 1 ;;
esac
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
build_root="$(mktemp -d "${TMPDIR:-/tmp}/register-frameworks.XXXXXX")"
trap 'rm -rf "$build_root"' EXIT
mkdir -p "$build_root/App"
rsync -a --exclude=build --exclude=.dart_tool --exclude=Pods --exclude=.symlinks \
  --exclude=ephemeral --exclude=.git --exclude=Generated.xcconfig \
  --exclude=flutter_export_environment.sh "$project_root/Source/Flutter/" "$build_root/App/"
cd "$build_root/App"
"$flutter_bin" pub get
"$(dirname "$flutter_bin")/dart" run build_runner build --delete-conflicting-outputs
"$flutter_bin" build ios-framework --no-profile --no-codesign --output="$build_root/Frameworks"
python3 - "$build_root/Frameworks" "$project_root" <<'PY'
import pathlib, re, shutil, sys, plistlib, zipfile, subprocess
source, root = map(pathlib.Path, sys.argv[1:])
for mode in ['Debug', 'Release']:
    expected = {p.name for p in (root/'Frameworks'/mode).glob('*.xcframework')}
    generated = {p.name for p in (source/mode).glob('*.xcframework') if p.stem != 'integration_test'}
    if expected != generated:
        raise SystemExit('Plugin dependencies changed. Update the Xcode framework references before replacing frameworks.')
for mode in ['Debug', 'Release']:
    for framework in (source/mode).glob('*.xcframework'):
        if framework.stem == 'integration_test': continue
        target = root/'Frameworks'/mode/framework.name
        shutil.rmtree(target)
        shutil.copytree(framework, target)
for filename in ['GeneratedPluginRegistrant.h', 'GeneratedPluginRegistrant.m']:
    text = (source/filename).read_text()
    if filename.endswith('.m'):
        text = re.sub(r'#if __has_include\(<integration_test/.*?#endif\n', '', text, flags=re.S)
        text = re.sub(r'^.*\[IntegrationTestPlugin registerWithRegistrar:.*\n', '', text, flags=re.M)
    (root/'App'/filename).write_text(text)
# GitHub public forks reject new LFS objects. Keep optional oversized symbols
# compressed while leaving all runtime frameworks directly usable in Xcode.
for mode in ['Debug', 'Release']:
    for framework in (root/'Frameworks'/mode).glob('*.xcframework'):
        info = framework/'Info.plist'
        metadata = plistlib.loads(info.read_bytes())
        changed = False
        for library in metadata['AvailableLibraries']:
            relative = library.get('DebugSymbolsPath')
            if not relative: continue
            folder = framework/library['LibraryIdentifier']/relative
            if not folder.exists() or not any(p.is_file() and p.stat().st_size > 95*1024*1024 for p in folder.rglob('*')): continue
            destination = root/'DeveloperTools/Symbols'
            destination.mkdir(parents=True, exist_ok=True)
            archive = destination/f'{mode}-{framework.stem}-{library["LibraryIdentifier"]}-symbols.zip'
            with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
                for file in sorted(folder.rglob('*')):
                    if file.is_file(): zipped.write(file, file.relative_to(folder))
            if archive.stat().st_size >= 95*1024*1024:
                raise SystemExit('Compressed symbols exceed the repository file-size limit.')
            shutil.rmtree(folder)
            del library['DebugSymbolsPath']
            changed = True
        if changed:
            info.write_bytes(plistlib.dumps(metadata))
            # Changing wrapper metadata invalidates its vendor signature. Keep
            # the inner runtime framework untouched; Xcode signs the app copy.
            if (framework/'_CodeSignature').exists():
                subprocess.run(['codesign', '--remove-signature', str(framework)], check=True)
PY
echo "Frameworks updated. Open Register.xcodeproj and Run."
