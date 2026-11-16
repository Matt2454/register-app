import 'dart:io';

import 'package:dr/app_state.dart';
import 'package:dr/widget_export.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'agenda_test.dart' show agendaFixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('register/widget');
  final calls = <MethodCall>[];
  setUp(() {
    widgetsEnabled.value = true;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() {
    widgetsEnabled.value = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('desktop widgets clear school data after logout', () async {
    await exportWeekForWidget(AppState());
    expect(calls.single.method, 'clearWeek');
  }, skip: !Platform.isMacOS);

  test('desktop widgets clear data when saving is disabled', () async {
    await exportWeekForWidget(
        agendaFixture().rebuild((b) => b.settingsState.noDataSaving = true));
    expect(calls.single.method, 'clearWeek');
  }, skip: !Platform.isMacOS);

  test('desktop widget sharing can be disabled without logging out', () async {
    widgetsEnabled.value = false;
    await exportWeekForWidget(agendaFixture());
    expect(calls.single.method, 'clearWeek');
  }, skip: !Platform.isMacOS);
}
