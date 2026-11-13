import 'dart:convert';

import 'package:built_redux/built_redux.dart';
import 'package:dr/actions/app_actions.dart';
import 'package:dr/app_language.dart';
import 'package:dr/app_state.dart';
import 'package:dr/container/login_page.dart';
import 'package:dr/localized_store_connection.dart';
import 'package:dr/reducer/reducer.dart';
import 'package:dr/ui/login_page_content.dart';
import 'package:dr/ui/theme.dart';
import 'package:dr/ui/today_page.dart';
import 'package:dr/utc_date_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'agenda_test.dart' show agendaFixture;

Widget languageApp(Widget home, {double textScale = 1}) =>
    ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, language, _) => MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('en'), Locale('it'), Locale('de')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildAppTheme(Brightness.dark, platform: TargetPlatform.iOS),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'app.language': 'de'});
    await loadAppLanguage();
  });

  test(
      'all three catalogs cover the same keys and preserve argument placeholders',
      () async {
    final catalogs = <String, Map>{};
    for (final code in supportedLanguageCodes) {
      catalogs[code] =
          jsonDecode(await rootBundle.loadString('assets/i18n/$code.json'))
              as Map;
    }
    expect(catalogs['de']!.length, greaterThan(500));
    for (final code in ['en', 'it']) {
      expect(catalogs[code]!.keys.toSet(), catalogs['de']!.keys.toSet());
    }
    for (final entry in catalogs['de']!.entries) {
      final placeholders = RegExp(r'\{\d+\}')
          .allMatches(entry.key as String)
          .map((m) => m[0])
          .toSet();
      for (final code in supportedLanguageCodes) {
        final value = catalogs[code]![entry.key];
        for (final text in value is Map ? value.values : [value]) {
          expect(
              RegExp(r'\{\d+\}')
                  .allMatches(text as String)
                  .map((m) => m[0])
                  .toSet(),
              placeholders,
              reason: '$code: ${entry.key}');
        }
      }
    }
  });

  test('chosen language persists and counts have singular and plural forms',
      () async {
    for (final (code, one, many) in [
      ('en', '1 day', '2 days'),
      ('it', '1 giorno', '2 giorni'),
      ('de', '1 Tag', '2 Tage')
    ]) {
      await setAppLanguage(code);
      expect(tr('{0} Tage', [1]), one);
      expect(tr('{0} Tage', [2]), many);
      await loadAppLanguage();
      expect(appLanguage.value, code);
    }
  });

  testWidgets('language switching keeps typed sign-in details', (tester) async {
    final state =
        AppState((b) => b..url = 'https://vinzentinum.digitalesregister.it');
    await tester.pumpWidget(languageApp(LoginPageContent(
      vm: LoginPageViewModel.from(state),
      onLogin: (_, __, ___) {},
      onChangePass: (_, __, ___, ____) {},
      setSaveNoPass: (_) {},
      onReload: () {},
      onRequestPassReset: (_) {},
      onSelectAccount: (_) {},
    )));
    await tester.pumpAndSettle();
    Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label);
    await tester.ensureVisible(field('Benutzername'));
    await tester.enterText(field('Benutzername'), 'kept-user');
    await tester.ensureVisible(field('Passwort'));
    await tester.enterText(field('Passwort'), 'kept-password');
    await setAppLanguage('it');
    // The real app invalidates localized descendants without replacing their
    // state. Rebuild the login widget the same way for this focused form test.
    (tester.element(find.byType(LoginPageContent)) as StatefulElement)
        .markNeedsBuild();
    await tester.pumpAndSettle();
    expect(find.text('kept-user'), findsOneWidget);
    expect(find.text('kept-password'), findsOneWidget);
    expect(field('Nome utente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long room names remain readable with larger text on a phone',
      (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await setAppLanguage('it');
    final data = TodayData.from(
        agendaFixture(rooms: ['Physikraum', 'Physikpraktikumsraum']),
        at: UtcDateTime(2026, 11, 9, 9));
    await tester.pumpWidget(languageApp(
        TodayPage(
            data: data,
            onCreateStudyPlan: (_, __) {},
            onShowGrades: () {},
            onShowAbsences: () {},
            onShowCalendar: () {},
            onShowTasks: () {},
            onRefresh: () async {},
            noInternet: false),
        textScale: 1.4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'derived display values change language without resetting child state',
      (tester) async {
    final store = Store<AppState, AppStateBuilder, AppActions>(
        appReducerBuilder.build(), AppState(), AppActions());
    await tester.pumpWidget(
      MaterialApp(
        home: ReduxProvider(
          store: store,
          child: ValueListenableBuilder<String>(
            valueListenable: appLanguage,
            builder: (context, _, __) =>
                StoreConnection<AppState, AppActions, String>(
              connect: (_) => tr('Kalender'),
              builder: (context, label, _) => Scaffold(
                body: Column(children: [
                  Text(label),
                  const TextField(key: ValueKey('kept-state')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
        find.byKey(const ValueKey('kept-state')), 'retained');
    await setAppLanguage('it');
    await tester.pumpAndSettle();
    expect(find.text('Calendario'), findsOneWidget);
    expect(find.text('retained'), findsOneWidget);
  });

  for (final style in AppStyle.values) {
    for (final language in supportedLanguageCodes) {
      for (final size in [const Size(375, 667), const Size(1024, 1366)]) {
        testWidgets('Today lays out with ${style.name} in $language at $size',
            (tester) async {
          final previousStyle = appStyle.value;
          appStyle.value = style;
          addTearDown(() => appStyle.value = previousStyle);
          addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
          await setAppLanguage(language);
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final data =
              TodayData.from(agendaFixture(), at: UtcDateTime(2026, 11, 9, 9));
          await tester.pumpWidget(languageApp(TodayPage(
              data: data,
              onCreateStudyPlan: (_, __) {},
              onShowGrades: () {},
              onShowAbsences: () {},
              onShowCalendar: () {},
              onShowTasks: () {},
              onRefresh: () async {},
              noInternet: false)));
          await tester.pumpAndSettle();
          expect(find.text(tr('Raum {0}', ['204'])), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
