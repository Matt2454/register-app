# Register for Android

The Android app is built from `../Source/Flutter`. Open that folder as a Flutter
project in Android Studio or VS Code. The installed APK runs independently of
Flutter, a development computer, and a debugger.

## Build a release APK

Install Flutter 3.47.5, JDK 21 and the Android SDK. Then, in `Source/Flutter`:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release
```

Allow the release build to run its normal dependency/tooling step after tests;
that regenerates the native plugin list without development-only plugins.

Before building a release, copy `android/key.properties.example` to
`android/key.properties` and configure your private signing key. Preserve that
key for future updates. Release builds never fall back to a debug certificate.
Neither the key nor its passwords belong in Git.

The repository's **Android release build** GitHub Actions workflow builds an
unsigned release, checks APK alignment, and installs a test-signed copy on a
disposable Android emulator. The unsigned artifact is then signed locally;
the private release key is not sent to GitHub. To explicitly build an unsigned
APK yourself, set `REGISTER_ALLOW_UNSIGNED_RELEASE=1`.

The application ID is `app.register.personal.r9457c4543606d986`. The existing
Kotlin namespace remains `it.digitalesregisterapp`.

## Features

Today, homework, grades, absences, timetable, report cards, messages, the five
visual styles, offline fonts, and English/Italian/German share the app's
cross-platform implementation. Android uses its own notification and background
work plugins. Background checks depend on Android scheduling and battery policy;
they are not an instant push-notification service.

Apple Calendar export and the Apple widget extensions belong to the Apple
versions. The Android app does not request access to your device calendars.

The app and source remain GPL-3.0. Third-party licenses are bundled with the app.
