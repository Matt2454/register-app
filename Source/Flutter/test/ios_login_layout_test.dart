import 'package:dr/app_state.dart';
import 'package:dr/container/login_page.dart';
import 'package:dr/ui/login_page_content.dart';
import 'package:dr/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final style in AppStyle.values) {
    for (final size in [const Size(375, 667), const Size(1024, 1366)]) {
      testWidgets('iOS login works with ${style.name} at $size',
          (tester) async {
        final previousStyle = appStyle.value;
        addTearDown(() => appStyle.value = previousStyle);
        appStyle.value = style;
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        List<String>? submitted;
        final state = AppState(
            (b) => b..url = 'https://vinzentinum.digitalesregister.it');
        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(Brightness.dark, platform: TargetPlatform.iOS),
          home: LoginPageContent(
            vm: LoginPageViewModel.from(state),
            onLogin: (user, pass, url) => submitted = [user, pass, url],
            onChangePass: (_, __, ___, ____) {},
            setSaveNoPass: (_) {},
            onReload: () {},
            onRequestPassReset: (_) {},
            onSelectAccount: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        Finder field(String label) => find.byWidgetPredicate((widget) =>
            widget is TextField && widget.decoration?.labelText == label);
        await tester.ensureVisible(field('Benutzername'));
        await tester.enterText(field('Benutzername'), 'demo-user-6540');
        await tester.ensureVisible(field('Passwort'));
        await tester.enterText(field('Passwort'), 'demo');
        // Verify that the login remains reachable with the software keyboard.
        await tester.ensureVisible(find.text('Login'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Login'));
        await tester.pump();

        expect(submitted, [
          'demo-user-6540',
          'demo',
          'https://vinzentinum.digitalesregister.it',
        ]);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
