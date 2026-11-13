import 'dart:convert';
import 'dart:io';

import 'package:dr/container/absences_page_container.dart';
import 'package:dr/container/calendar_container.dart';
import 'package:dr/container/certificate_container.dart';
import 'package:dr/container/grades_page_container.dart';
import 'package:dr/container/settings_page.dart';
import 'package:dr/container/today_container.dart';
import 'package:dr/desktop.dart';
import 'package:dr/main.dart' as app;
import 'package:dr/ui/login_page_content.dart';
import 'package:dr/ui/messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';

// Run on a fresh, dedicated iOS simulator; this signs in to the bundled demo.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('iOS demo login, Keychain, and core screens', (tester) async {
    await app.main();

    Future<void> waitFor(Finder finder) async {
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (finder.evaluate().isNotEmpty) {
          return;
        }
      }
      fail('Screen did not appear: $finder');
    }

    await waitFor(find.byType(LoginPageContent));
    Finder field(String label) => find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == label);
    Future<void> enter(String label, String value) async {
      await tester.ensureVisible(field(label));
      await tester.enterText(field(label), value);
      await tester.pump(const Duration(milliseconds: 200));
    }

    await enter('Schule', 'Vinzentinum');
    await enter('Benutzername', 'demo-user-6540');
    await enter('Passwort', 'demo');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('Login'));
    await tester.tap(find.text('Login'));
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(LoginPageContent).evaluate().isEmpty &&
          app.scaffoldKey?.currentState != null) {
        break;
      }
    }
    expect(find.byType(LoginPageContent), findsNothing);
    expect(app.scaffoldKey?.currentState, isNotNull);

    // Exercise the real iOS Keychain plugin, including persisted demo login.
    final storage = getFlutterSecureStorage();
    final login = json.decode((await storage.read(key: 'login'))!) as Map;
    expect(login['user'], 'demo-user-6540');
    const probe = 'ios-smoke-keychain-probe';
    try {
      await storage.write(key: probe, value: 'round-trip');
      expect(await storage.read(key: probe), 'round-trip');
    } finally {
      await storage.delete(key: probe);
    }

    final screens = <(Future<void> Function(), Type)>[
      (() async => app.actions.routingActions.showToday(), TodayContainer),
      (
        () async => app.actions.routingActions.showGrades(),
        GradesPageContainer
      ),
      (
        () async => app.actions.routingActions.showAbsences(),
        AbsencesPageContainer
      ),
      (
        () async => app.actions.routingActions.showCalendar(),
        CalendarContainer
      ),
      (
        () async => app.actions.routingActions.showCertificate(),
        CertificateContainer
      ),
      (() async => app.actions.routingActions.showMessages(), MessagesPage),
      (
        () async => app.actions.routingActions.showSettings(),
        SettingsPageContainer
      ),
    ];
    for (final (navigate, screenType) in screens) {
      await navigate();
      await waitFor(find.byType(screenType));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: '$screenType');
    }
  }, skip: !Platform.isIOS);
}
