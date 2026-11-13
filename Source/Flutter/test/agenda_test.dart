import 'dart:convert';

import 'package:built_collection/built_collection.dart';
import 'package:dr/agenda.dart';
import 'package:dr/app_state.dart';
import 'package:dr/data.dart';
import 'package:dr/lesson_time.dart';
import 'package:dr/utc_date_time.dart';
import 'package:dr/widget_export.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = UtcDateTime(2026, 11, 9);
TimeSpan _period(int fromHour, int fromMinute, int toHour, int toMinute) =>
    TimeSpan((b) => b
      ..from = UtcDateTime(2026, 11, 9, fromHour, fromMinute)
      ..to = UtcDateTime(2026, 11, 9, toHour, toMinute));
Homework _task(int id,
        {bool checked = false,
        bool deleted = false,
        HomeworkType type = HomeworkType.lessonHomework}) =>
    Homework((b) => b
      ..id = id
      ..title = '<b>Read &amp; revise</b>'
      ..subtitle = ''
      ..type = type
      ..checked = checked
      ..checkable = true
      ..deleted = deleted);

AppState agendaFixture({List<String> rooms = const ['204']}) =>
    AppState((b) => b
      ..url = 'https://private-school.example'
      ..loginState.username = 'private-student'
      ..loginState.loggedIn = true
      ..calendarState.days[_today] = CalendarDay((b) => b
        ..date = _today
        ..lastFetched = UtcDateTime(2026, 11, 9, 7, 0)
        ..hours = ListBuilder([
          CalendarHour((b) => b
            ..subject = 'Mathematik'
            ..fromHour = 1
            ..toHour = 3
            ..rooms = ListBuilder(rooms)
            ..homeworkExams = ListBuilder()
            ..lessonContents = ListBuilder()
            ..timeSpans =
                ListBuilder([_period(8, 30, 9, 15), _period(9, 30, 10, 15)]))
        ]))
      ..dashboardState.allDays = ListBuilder([
        Day((b) => b
          ..date = _today.subtract(const Duration(days: 1))
          ..lastRequested = UtcDateTime(2026, 11, 9, 7)
          ..homework = ListBuilder([_task(1)])),
        Day((b) => b
          ..date = _today
          ..lastRequested = UtcDateTime(2026, 11, 9, 7)
          ..homework = ListBuilder([
            _task(2),
            _task(3, checked: true),
            _task(4, deleted: true),
            _task(5, type: HomeworkType.grade),
            _task(6, type: HomeworkType.observation),
            _task(7)
          ])),
      ])
      ..dashboardState.movedHomework['lessonHomework:7'] =
          _today.add(const Duration(days: 1)));

void main() {
  test('old untrackable entries are not reported as unfinished overdue work',
      () {
    final state = agendaFixture().rebuild((b) => b.dashboardState.allDays[0] =
        b.dashboardState.allDays[0].rebuild((day) => day.homework[0] =
            day.homework[0].rebuild((task) => task.checkable = false)));
    expect(AgendaSnapshot.from(state, at: _today).overdue, isEmpty);
  });
  test(
      'Today separates overdue, today, and moved deadlines and hides completed data',
      () {
    final agenda =
        AgendaSnapshot.from(agendaFixture(), at: UtcDateTime(2026, 11, 9, 9));
    expect(agenda.overdue.map((t) => t.homework.id), [1]);
    expect(agenda.dueOn(_today).map((t) => t.homework.id), [2]);
    expect(agenda.dueOn(_today.add(const Duration(days: 1))).single.homework.id,
        7);
    expect(agenda.tasks.length, 3);
  });

  test('live lesson uses the actual period end and the break is free time', () {
    final state = agendaFixture();
    final during = AgendaSnapshot.from(state, at: UtcDateTime(2026, 11, 9, 9));
    expect(during.current!.end, UtcDateTime(2026, 11, 9, 9, 15));
    final pause =
        AgendaSnapshot.from(state, at: UtcDateTime(2026, 11, 9, 9, 20));
    expect(pause.current, isNull);
    expect(pause.next!.start, UtcDateTime(2026, 11, 9, 9, 30));
    final boundary =
        AgendaSnapshot.from(state, at: UtcDateTime(2026, 11, 9, 9, 15));
    expect(boundary.current, isNull);
  });

  test('missing data is distinct from a loaded day without lessons', () {
    final missing = AgendaSnapshot.from(AppState(), at: _today);
    expect(missing.lessonsLoaded, false);
    expect(missing.tasksLoaded, false);
    final loaded = AgendaSnapshot.from(agendaFixture(), at: _today);
    expect(loaded.lessonsLoaded, true);
    expect(loaded.tasksLoaded, true);
  });

  test('duplicate completed source entries cannot reappear as pending tasks',
      () {
    final state =
        agendaFixture().rebuild((b) => b.dashboardState.allDays.add(Day((b) => b
          ..date = _today
          ..homework = ListBuilder([_task(2, checked: true)]))));
    final agenda = AgendaSnapshot.from(state, at: _today);
    expect(agenda.tasks.any((t) => t.homework.id == 2), false);
  });

  test('widget payload shares only cleaned lessons and pending future tasks',
      () {
    final data = iosWidgetSnapshot(agendaFixture(), at: _today);
    final json = jsonEncode(data);
    expect(json, isNot(contains('private-student')));
    expect(json, isNot(contains('private-school')));
    expect(json, isNot(contains('password')));
    expect(data['days'], hasLength(14));
    final tasks = data['tasks']! as List;
    expect(tasks, hasLength(2));
    expect(tasks.first['title'], 'Read & revise');
    expect(tasks.last['date'], '2026-11-10');
    final days = data['days']! as List;
    expect(days.first['lessons'][0]['periods'], hasLength(2));
  });

  test(
      'school clock follows Rome in winter and summer regardless of device zone',
      () {
    expect(wallClockNow(DateTime.utc(2026, 11, 9, 6, 45)),
        UtcDateTime(2026, 11, 9, 7, 45));
    expect(wallClockNow(DateTime.utc(2027, 4, 5, 5, 45)),
        UtcDateTime(2027, 4, 5, 7, 45));
    expect(wallClockNow(DateTime.utc(2026, 11, 8, 23, 30)).stripTime(), _today);
  });
}
