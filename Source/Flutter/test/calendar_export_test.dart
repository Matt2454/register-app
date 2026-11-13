import 'package:built_collection/built_collection.dart';
import 'package:dr/app_state.dart';
import 'package:dr/calendar_export.dart';
import 'package:dr/data.dart';
import 'package:dr/ui/calendar_export_dialog.dart';
import 'package:dr/utc_date_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final monday = UtcDateTime(2026, 11, 9);
TimeSpan span(int h1, int m1, int h2, int m2) => TimeSpan(
      (b) => b
        ..from = UtcDateTime(2026, 11, 9, h1, m1)
        ..to = UtcDateTime(2026, 11, 9, h2, m2),
    );
CalendarHour lesson({
  List<TimeSpan> spans = const [],
  List<HomeworkExam> exams = const [],
}) =>
    CalendarHour(
      (b) => b
        ..fromHour = 1
        ..toHour = 3
        ..subject = 'Mathematik'
        ..rooms = ListBuilder(['204'])
        ..timeSpans = ListBuilder(spans)
        ..homeworkExams = ListBuilder(exams)
        ..lessonContents = ListBuilder(),
    );
AppState state({
  List<CalendarHour> lessons = const [],
  List<Homework> homework = const [],
  Map<String, UtcDateTime> moved = const {},
}) =>
    AppState(
      (b) => b
        ..url = 'https://school.digitalesregister.it'
        ..loginState.username = 'student'
        ..calendarState.currentMonday = monday
        ..calendarState.days[monday] = CalendarDay(
          (b) => b
            ..date = monday
            ..hours = ListBuilder(lessons),
        )
        ..dashboardState.allDays = ListBuilder([
          Day(
            (b) => b
              ..date = monday
              ..homework = ListBuilder(homework),
          ),
        ])
        ..dashboardState.movedHomework = MapBuilder(moved),
    );
Homework task(int id, {HomeworkType? type, bool checked = false}) => Homework(
      (b) => b
        ..id = id
        ..title = 'Hausaufgabe'
        ..subtitle = '<p>A &amp; B<br>Seite 10</p>'
        ..type = type ?? HomeworkType.lessonHomework
        ..checked = checked,
    );

void main() {
  test(
      'teaching periods merge only across adjoining times, keeping breaks and school clock',
      () {
    final snapshot = calendarExportForWeek(
      state(
        lessons: [
          lesson(
            spans: [
              span(7, 45, 8, 30),
              span(8, 30, 9, 15),
              span(9, 30, 10, 15),
            ],
          ),
        ],
      ),
      monday,
    );
    expect(snapshot.events.length, 2);
    expect(snapshot.events.first.toMap()['start'], [2026, 11, 9, 7, 45]);
    expect(snapshot.events.first.toMap()['end'], [2026, 11, 9, 9, 15]);
    expect(snapshot.events.last.start.minute, 30);
    expect(snapshot.events.first.location, '204');
    expect(snapshot.events.first.allDay, false);
  });
  test(
    'lessons with unknown times are reported, never given invented times',
    () {
      final snapshot = calendarExportForWeek(
        state(lessons: [lesson()]),
        monday,
      );
      expect(snapshot.events, isEmpty);
      expect(snapshot.lessonsWithoutTime, 1);
    },
  );
  test(
      'all-day deadlines respect moved dates and skip completed entries and other weeks',
      () {
    final snapshot = calendarExportForWeek(
      state(
        homework: [task(1), task(2), task(3, checked: true)],
        moved: {
          'lessonHomework:1': monday.add(const Duration(days: 6)),
          'lessonHomework:2': monday.add(const Duration(days: 7)),
        },
      ),
      monday,
    );
    expect(snapshot.events.length, 1);
    final event = snapshot.events.single;
    expect(event.allDay, true);
    expect(event.start, UtcDateTime(2026, 11, 15));
    expect(event.end, UtcDateTime(2026, 11, 16));
    expect(event.notes, 'A & B\nSeite 10');
  });
  test('calendar and dashboard copies of the same test export only once', () {
    final exam = HomeworkExam(
      (b) => b
        ..id = 7
        ..name = 'Schularbeit'
        ..homework = false
        ..online = false
        ..deadline = UtcDateTime(2026, 11, 9, 7, 45)
        ..hasGrades = false
        ..hasGradeGroupSubmissions = false
        ..typeId = 1
        ..typeName = 'Schularbeit'
        ..warning = true,
    );
    final hw = task(
      7,
      type: HomeworkType.gradeGroup,
    ).rebuild((b) => b..title = 'Schularbeit');
    final snapshot = calendarExportForWeek(
      state(
        lessons: [
          lesson(exams: [exam]),
        ],
        homework: [hw],
      ),
      monday,
    );
    expect(snapshot.events.length, 1);
    expect(snapshot.events.single.kind, CalendarExportKind.test);
    expect(snapshot.events.single.notes, contains('07:45'));
    expect(snapshot.accountScope, contains('student'));
  });
  test(
      'school times serialize without a UTC suffix or device time-zone conversion',
      () {
    final event = CalendarExportEvent(
      id: 'summer',
      title: 'Lesson',
      start: UtcDateTime(2027, 4, 5, 7, 45),
      end: UtcDateTime(2027, 4, 5, 8, 30),
      kind: CalendarExportKind.lesson,
    );
    expect(event.toMap()['start'], [2027, 4, 5, 7, 45]);
  });
  testWidgets('cancel export never invokes native calendar access', (
    tester,
  ) async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appleCalendarChannel, (call) async {
      calls++;
      return {'cancelled': true};
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appleCalendarChannel, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppleCalendarExport(
                context,
                calendarExportForWeek(state(homework: [task(1)]), monday),
                monday,
              ),
              child: const Text('Export'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });
  testWidgets('denied calendar permission displays a useful settings action', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appleCalendarChannel, (call) async {
      throw PlatformException(
        code: 'calendar_permission',
        message: 'Bitte erlauben',
      );
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appleCalendarChannel, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppleCalendarExport(
                context,
                calendarExportForWeek(state(homework: [task(1)]), monday),
                monday,
              ),
              child: const Text('Export'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kalender auswählen'));
    await tester.tap(find.text('Kalender auswählen'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte erlauben'), findsOneWidget);
    expect(find.text('Einstellungen'), findsOneWidget);
  });
}
