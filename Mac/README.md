# Register for Mac

Open **Register-Mac.xcodeproj**, select **Register-Mac → My Mac**, and press **⌘R**.
Run uses the bundled Release runtime. Flutter and CocoaPods are not needed to build
or run this project. Xcode 27.2 was used to verify it.

The app requires **macOS 14 or later**. Its executable, Flutter engine, Dart code,
and native plugins include both **Apple silicon and Intel** architectures.

The signing settings use the existing development team. On another developer's
Mac, choose their team and an installed Apple Development certificate. The Mac
app uses its own bundle identifier and a team-prefixed Mac app group. It does
not need a development provisioning profile: its encrypted credential database
uses the existing macOS Keychain implementation, without keychain sharing.
No signing keys or provisioning profiles are included in the project.

The desktop app includes Today, homework, grades, absences, the timetable,
report cards, messages, all five visual styles, and English, Italian and German.
Use **⌘,** to open Settings. Closing the window keeps the app running; click its
Dock icon to reopen it, or use **⌘Q** to quit.

## Apple Calendar

Open Calendar in Register and use the export icon. Select lessons, tests and/or
tasks. On Mac, confirm export to **Apple Calendar's default calendar**, configured
in Apple Calendar → Settings → General. Only write access is requested; existing
events are not read. The app keeps a local duplicate-prevention ledger. A later
change to the default calendar can require turning off “Avoid duplicates” for
that export. Exports are one-time copies, not automatic synchronization.

## Desktop widgets

Move Register.app to Applications and open it once. Right-click the desktop →
Edit Widgets → Register. The extension contains timetable, tasks/tests, and grade
average widgets. They use locally cached data, refreshed while the app updates;
WidgetKit controls refresh timing. Settings lets you disable widget sharing.
Logging out or disabling local saving clears the shared widget cache.

## Rebuilding the Dart code

The editable cross-platform code is in `../Source/Flutter`. To update the bundled
Mac frameworks after editing it, use `../DeveloperTools/RebuildMacFrameworks.sh`
with Flutter 3.47.5, CocoaPods and Xcode installed. Ordinary Xcode builds do not
run that script or contact package registries. The large upstream engine dSYM is
excluded; it remains available in that Flutter SDK's release engine cache.

This is a locally development-signed build. A public distribution release still
needs Developer ID signing and Apple notarization.
