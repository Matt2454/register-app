# Verification record — Register 8.3.0 (51)

Verified on 13 November 2026 with Xcode 27.2 (27B52), Flutter 3.47.5,
Dart 3.13.4, and CocoaPods 1.16.2.

## Today, languages, and widgets

- All 89 Flutter unit/widget tests passed.
- Today was tested in all five designs, all three languages, and phone/iPad sizes.
- Larger text with long room names: passed without layout errors.
- Tracked overdue tasks, completed/deleted entries, moved deadlines, teaching
  breaks, missing data, duplicate source entries, and Rome summer/winter time:
  passed.
- All 549 catalog keys exist in English, Italian, and German, with argument
  placeholders checked and singular/plural count cases tested.
- Changing language retains form input and derived display values. Selected
  language persists across restart.
- All four installed-app Xcode UI checks passed: language switching/persistence,
  widget URLs, standalone launch, Calendar export/duplicate prevention, and
  adding the real Home Screen widget and opening Today after terminating the app.
- The Home Screen screenshot was inspected: the widget displayed the actual
  saved subject, teaching period, and room, rather than preview sample data.
- Simulator shared App Group verified: real snapshot contained 14 day records,
  loaded lessons, language choice, and no account identifiers or credentials.
- Native Swift widget checks passed: lesson boundaries, breaks, midnight,
  deadlines, stale data, Rome time zone, translations, atomic validation, and
  clearing the cache.

Widgets use cached lessons and deadlines refreshed by the app. Their timelines
include known lesson boundaries and midnight changes. WidgetKit controls reload
and rendering timing; the extension does not log into the school service.

## Xcode and signing

`Register.xcodeproj` runs with Xcode alone. All Flutter runtime frameworks, native
plugins, fonts, and assets are included locally; Flutter and CocoaPods are only
needed when rebuilding Dart source changes.

- Simulator Debug app and both widget kinds compiled successfully.
- Physical-device Release app and embedded widget extension built and signed
  with the selected development team and shared App Group. Deep/strict signature
  verification passed for the final app and its embedded code.
- Xcode Run remains Release without a debugger on a physical device.
- Default Release configuration simulator build was installed and cold-launched
  without a debugger; the running Today screen was visually inspected.
- Simulator framework selection is automatic; device Release uses the AOT runtime.
- Bundle ID: `app.register.personal.r9457c4543606d986`.
- Widget bundle ID: `app.register.personal.r9457c4543606d986.widgets`.
- App Group: `group.app.register.personal.r9457c4543606d986`.
- Targets iPhone and iPad, iOS 15 or later.
- Runtime frameworks are ordinary Git files below GitHub’s file-size limit.

## Calendar and earlier checks

Calendar export remains a one-time copy of the selected week. Lessons preserve
Europe/Rome school times and breaks; tests/tasks use all-day deadlines. iOS 17+
uses write-only Calendar access, with the legacy API on iOS 15–16. Duplicate
prevention remembers this installation, school account, and destination calendar.
The installed simulator export and repeat-export checks passed after this update.

The earlier native demo checks verified authentication, Keychain write/read/
delete, persisted credentials, and navigation through the application’s screens.
The 54 original fonts and six OFL licenses remain bundled; runtime font downloads
are disabled.

## Source and limits

Based on [kererleon/register-app](https://github.com/kererleon/register-app),
commit `706186888cd68c9652c0cecc6c457cf9eb9024a8`, under GPL-3.0. Full application
source, native widget code, and rebuild instructions are included. The optional
Flutter iOS project mirrors the native widget and language integration.

The physical phone was not connected for final installation. Physical-phone
installation, home-screen cold launch, real school authentication, background
notification delivery, and physical-device Calendar/widget behavior remain
unverified. Legacy iOS 15–16 Calendar permission fallback was compiled but not
exercised on an older runtime. No signing credentials are included.

Scoped analysis reports no errors and four existing warnings. Informational
legacy/style findings remain; vendored packages were not broadly rewritten.
