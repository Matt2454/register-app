# Register — open and run in Xcode

1. Open **Register.xcodeproj**.
2. Select the **Register** scheme and your **iPhone, iPad, or simulator**.
3. Press **⌘R**.

No Flutter installation, CocoaPods installation, package download, or terminal
setup is required. The app, Flutter runtime, native plugins, fonts, and assets
are bundled locally. Keep the complete folder together; the project references
its `Frameworks`, `App`, and `Debugging` folders by relative paths.

For a physical iPhone, select **Register → Signing & Capabilities → Team** and
choose your Apple development team, then select the connected iPhone and Run.
The app now uses the unique identifier `app.register.personal.r9457c4543606d986`.
Xcode has created its development profile and signed a Release device build with
your selected team. **Run uses Release by default**, without a debugger. After
installing it once with Xcode, open the app directly from the phone's home screen;
the Mac and Xcode are not needed to launch it. Use **Product → Archive** for
distribution builds.

Demo: school **Vinzentinum**, username **demo-user-6540**, any password.

## Apple Calendar export

Open **Kalender**, select a week, and tap the export icon at the top right.
Choose lessons, tests, and/or tasks, then choose the destination calendar in
Apple's calendar picker. Allow Calendar access when prompted. On iOS 17 or later
the app requests permission to add events, without reading existing events.

Lesson times retain the school's Europe/Rome time zone and actual teaching
breaks. Tests and tasks are exported as all-day deadlines. Completed tasks and
entries without usable lesson times are excluded. Duplicate prevention remembers
items exported by this installation; turn it off to explicitly export them again.
This is a one-time copy, not an automatically updated calendar subscription.

## Clone from GitHub

Clone this repository normally, then open `Register.xcodeproj`. The runtime
frameworks are included as ordinary Git files: no Git LFS, Flutter, or CocoaPods
setup is needed to run the app. Optional large Flutter crash-symbol files are
compressed in `DeveloperTools/Symbols/`; they are not needed to build or run.

The project targets iOS 15 or later and was verified with Xcode 27.2. Xcode must
have an iOS simulator runtime installed to run a simulator. Device signing
credentials are intentionally not included.

## Source and changes

The native launch code is in `App/`. The original Flutter application source,
including the iOS fixes and offline fonts, is in `Source/Flutter/`.

The Flutter UI is supplied as precompiled XCFrameworks so the app can run from
Xcode without installing Flutter. Swift/Objective-C launch-code changes build
directly in Xcode. After changing Dart source, developers with Flutter 3.47.5
and CocoaPods can run `bash DeveloperTools/RebuildFrameworks.sh` to update the
bundled application frameworks, then return to Xcode. Adding native plugin
dependencies also requires updating the project's framework references.

Third-party licenses are in `Licenses/`, `Source/Flutter/LICENSE.txt`, the font
asset directory, and the app's bundled notices. The app remains GPL-3.0.

## Launch test

Press **⌘U** to run the Xcode UI tests. They check application launch and, on a
simulator, demo Calendar export and duplicate prevention. Use a disposable
simulator: the export test writes demo events to its calendar. The app also
passed all 47 Flutter unit/widget tests. See `VERIFICATION.md` for checks and
remaining physical-device limits.
