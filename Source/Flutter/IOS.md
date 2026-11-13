# Register for iPhone and iPad

This version uses the original Flutter application, including its school API,
demo mode, grades and forecasts, homework, calendar, absences, messages, profile,
settings and all five visual styles. The source and GPL-3.0 license are retained.
The reference commit is `706186888cd68c9652c0cecc6c457cf9eb9024a8`.
The original fonts are bundled for offline use, with their SIL Open Font License
texts and checksums in `assets/fonts/`. Font downloads at runtime are disabled.

## Build

Use macOS, full Xcode with the iOS platform installed, Flutter **3.47.5** (the
version pinned by the original release workflow), and CocoaPods. Add Flutter's
`bin` directory to PATH. Accept Xcode's license and finish its first-launch setup.
Keep the checkout and Flutter SDK outside cloud-synced folders such as iCloud
Drive. File-provider metadata on generated frameworks can make Apple's signing
check fail with “resource fork, Finder information, or similar detritus not allowed”.

```sh
bash scripts/build_ios.sh simulator
# Or compile a release app for an iPhone/iPad without signing:
bash scripts/build_ios.sh device
```

The outputs are `build/ios/iphonesimulator/Runner.app` and
`build/ios/iphoneos/Runner.app`, respectively. An unsigned device build needs
Apple signing before it can be installed on a physical device.

## Install on your iPhone

```sh
bash scripts/build_ios.sh prepare
open ios/Runner.xcworkspace
```

In Xcode, select **Runner → Signing & Capabilities**, select your Apple development
team, connect and select your iPhone, then Run. Use a unique bundle identifier if
the original `com.webandgrow.register` is unavailable to your team. The background
task identifier must remain `com.webandgrow.register.check` in both Info.plist and
AppDelegate.swift; it is independent of the app's bundle identifier.

Alternatively, save `DEVELOPMENT_TEAM = YOUR_TEAM_ID` in
`ios/Flutter/Team.xcconfig`, which is ignored by Git. Never commit signing keys
or provisioning profiles. For distribution, use Xcode's **Product → Archive**
and the distribution method supported by your Apple account.

## Try the original demo

Choose school **Vinzentinum**, user **demo-user-6540**, and any password. Demo
data is bundled with the original application; no school account is needed.

## Verification

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart analyze --no-fatal-warnings lib test integration_test
flutter test
bash scripts/build_ios.sh simulator
bash scripts/build_ios.sh device
```

The `Verify iOS` GitHub Actions workflow runs these tests, runs a native smoke test
on a fresh iPhone simulator, and compiles both iOS targets without requiring Apple
signing secrets. Its device artifact is unsigned.

On a simulator or device, check login, all navigation sections, each style,
photo selection, relaunch with saved credentials, and notification permissions.
Background refresh must also be checked on a physical device: iOS schedules it
opportunistically and does not guarantee a 15-minute interval.

On a fresh, dedicated iOS simulator, run the native demo login, Keychain, and
navigation smoke test with:

```sh
flutter test integration_test/ios_smoke_test.dart -d YOUR_SIMULATOR_ID
```

This test saves the bundled demo login in that simulator's app storage. Use a
fresh simulator for each run so that the test begins at the login screen.

School HTTPS links require the school's cooperation to configure Apple's
Associated Domains and its `apple-app-site-association` file. That server setup
is not included in this project; password reset remains available through the
school website.
