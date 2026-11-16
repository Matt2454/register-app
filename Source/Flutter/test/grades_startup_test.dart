import 'package:built_redux/built_redux.dart';
import 'package:dr/actions/app_actions.dart';
import 'package:dr/app_state.dart';
import 'package:dr/middleware/middleware.dart';
import 'package:dr/reducer/reducer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('grades can be requested while a saved account is still initializing',
      () async {
    final actions = AppActions();
    final store = Store<AppState, AppStateBuilder, AppActions>(
      appReducerBuilder.build(),
      AppState((b) => b.loginState.loggedIn = true),
      actions,
      middleware: middleware(),
    );
    expect(store.state.config, isNull);
    await actions.gradesActions.load(Semester.first);
    // A missing configuration must not schedule a later null assertion either.
    await pumpEventQueue();
    expect(store.state.gradesState.subjects, isEmpty);
    await store.dispose();
  });
}
