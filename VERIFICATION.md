# Verification record

Verified on 13 November 2026 with Xcode 27.2 (27B52), Flutter 3.47.5,
Dart 3.13.4, and CocoaPods 1.16.2.

## Standalone Xcode project

Open `Register.xcodeproj`, select Register and a simulator or your iPhone, and
press Run. All runtime frameworks, plugins, fonts, and assets are included.
Running the project requires Xcode only. Flutter and CocoaPods are needed only
when changing and rebuilding the Dart application source.

- Signed iPhone Release build with the selected development team: passed.
- Embedded app/framework signature verification: passed.
- Simulator Debug build and both native Xcode UI tests: passed, zero failures.
- Run uses Release without a debugger, allowing an installed app to launch from
  the home screen independently of Xcode.
- Unique bundle identifier: `app.register.personal.r9457c4543606d986`.
- Targets iPhone and iPad on iOS 15 or later; app version 8.2.15 (50).
- Debug and Release each include App, Flutter, and 11 production plugin
  XCFrameworks. Optional large engine symbols are ZIP-compressed separately.
- Frameworks are regular Git files, with no Git LFS requirement.

## Apple Calendar export

The native simulator test logged into the bundled demo, opened Calendar,
cancelled and reopened export, chose a destination in Apple's calendar chooser,
and exported 31 events. Repeating the same export added zero events and skipped
all 31 duplicates. The successful export screenshot was inspected.

Export uses write-only Calendar permission on iOS 17+, with the legacy permission
API on iOS 15–16. Only the newer API was exercised in the simulator. It exports
the selected week as a one-time copy. Lessons retain Europe/Rome wall-clock times
and teaching breaks; tasks and tests use all-day due dates. Duplicate tracking is
local to this installation, account, and destination calendar.

## Application checks

- All 47 unit/widget tests passed, including seven Calendar export tests.
- Login layouts passed in all five designs at 375×667 and 1024×1366.
- Calendar tests cover teaching breaks, missing times, moved/completed tasks,
  HTML cleanup, duplicate source entries, wall-clock serialization, cancellation,
  and denied-permission handling.
- Scoped analysis: no errors; four existing warnings and 87 informational
  findings. Vendored packages retain their original analysis findings.
- Earlier native demo tests verified authentication, iOS Keychain write/read/
  delete, saved credentials, and navigation through the main screens.
- All 54 original font files were verified by hash and length; their six OFL
  licenses are included. Runtime font downloads are disabled.

## Source and limits

Based on [kererleon/register-app](https://github.com/kererleon/register-app),
commit `706186888cd68c9652c0cecc6c457cf9eb9024a8`, under GPL-3.0. The complete
application source is under `Source/Flutter`; optional rebuild instructions are
in README.md.

The physical phone was not connected for this final build. Device installation,
home-screen cold launch, real school authentication, notification delivery,
background refresh, and Calendar export on a physical phone remain unverified.
No signing certificates, private keys, or provisioning profiles are included.
