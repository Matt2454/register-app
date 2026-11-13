import 'package:dr/app_language.dart';
import 'package:dr/app_state.dart';
import 'package:dr/data.dart';
import 'package:dr/utc_date_time.dart';
import 'package:html/parser.dart' as html;

enum CalendarExportKind { lesson, test, task }

/// Times in the register are wall-clock components, even though its model uses
/// UtcDateTime. Send components to EventKit; never convert them with toLocal().
class CalendarExportEvent {
  final String id, title, notes, location;
  final UtcDateTime start, end;
  final bool allDay;
  final CalendarExportKind kind;

  const CalendarExportEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.kind,
    this.notes = '',
    this.location = '',
    this.allDay = false,
  });

  Map<String, Object> toMap() => {
        'id': id,
        'title': title,
        'notes': notes,
        'location': location,
        'start': [start.year, start.month, start.day, start.hour, start.minute],
        'end': [end.year, end.month, end.day, end.hour, end.minute],
        'allDay': allDay,
      };
}

String calendarPlainText(String text) =>
    html
        .parseFragment(
          text
              .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
              .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n'),
        )
        .text
        ?.trim() ??
    '';

class CalendarExportSnapshot {
  final List<CalendarExportEvent> events;
  final int lessonsWithoutTime;
  final String accountScope;
  const CalendarExportSnapshot(
    this.events,
    this.lessonsWithoutTime,
    this.accountScope,
  );
}

CalendarExportSnapshot calendarExportForWeek(
  AppState state,
  UtcDateTime monday,
) {
  final until = monday.add(const Duration(days: 7));
  bool inWeek(UtcDateTime d) => !d.isBefore(monday) && d.isBefore(until);
  String dateKey(UtcDateTime d) => '${d.year}-${d.month}-${d.day}';
  final events = <String, CalendarExportEvent>{};
  final completed = <String>{
    for (final day in state.dashboardState.allDays ?? <Day>[])
      for (final hw in day.homework)
        if (hw.checked || hw.deleted) homeworkMoveKey(hw),
  };
  var missingTime = 0;

  void due({
    required String id,
    required String title,
    required String notes,
    required UtcDateTime date,
    required CalendarExportKind kind,
  }) {
    if (!inWeek(date)) return;
    final day = UtcDateTime(date.year, date.month, date.day);
    final key = '$id:${dateKey(day)}';
    events.putIfAbsent(
      key,
      () => CalendarExportEvent(
        id: key,
        title: title,
        notes: calendarPlainText(notes),
        start: day,
        end: day.add(const Duration(days: 1)),
        allDay: true,
        kind: kind,
      ),
    );
  }

  for (final day in state.calendarState.daysForWeek(monday)) {
    for (final hour in day.hours) {
      final spans = hour.timeSpans.where((s) => s.to.isAfter(s.from)).toList()
        ..sort((a, b) => a.from.compareTo(b.from));
      if (spans.isEmpty) missingTime++;
      // Merge adjacent teaching periods, preserving actual breaks.
      final merged = <(UtcDateTime, UtcDateTime)>[];
      for (final span in spans) {
        if (merged.isNotEmpty && !span.from.isAfter(merged.last.$2)) {
          final previous = merged.removeLast();
          merged.add((
            previous.$1,
            span.to.isAfter(previous.$2) ? span.to : previous.$2,
          ));
        } else {
          merged.add((span.from, span.to));
        }
      }
      for (final (start, end) in merged) {
        if (!inWeek(start)) continue;
        final id =
            'lesson:${dateKey(day.date)}:${hour.fromHour}:${hour.toHour}:${start.hour}:${start.minute}';
        events[id] = CalendarExportEvent(
          id: id,
          title: hour.subject,
          start: start,
          end: end,
          location: hour.rooms.join(', '),
          kind: CalendarExportKind.lesson,
          notes: hour.teachers.map((t) => t.fullName).join(', '),
        );
      }
      for (final entry in hour.homeworkExams) {
        if (entry.hasGrades || completed.contains('gradeGroup:${entry.id}')) {
          continue;
        }
        final test = looksLikeTest('${entry.typeName} ${entry.name}') ||
            (!entry.homework &&
                !looksLikeHomework('${entry.typeName} ${entry.name}'));
        due(
          id: 'gradeGroup:${entry.id}',
          title:
              '${test ? tr("Test") : tr("Aufgabe")}: ${hour.subject} · ${calendarPlainText(entry.name)}',
          notes: [
            entry.typeName,
            if (entry.deadline.hour != 0 || entry.deadline.minute != 0)
              tr("Fällig um {0}:{1} (Schulzeit)", [
                entry.deadline.hour.toString().padLeft(2, '0'),
                entry.deadline.minute.toString().padLeft(2, '0')
              ]),
          ].join('\n'),
          date: state.dashboardState.movedHomework['gradeGroup:${entry.id}'] ??
              entry.deadline,
          kind: test ? CalendarExportKind.test : CalendarExportKind.task,
        );
      }
    }
  }
  for (final day in state.dashboardState.allDays ?? <Day>[]) {
    for (final hw in day.homework) {
      if (hw.deleted ||
          hw.checked ||
          hw.type == HomeworkType.grade ||
          hw.type == HomeworkType.observation) {
        continue;
      }
      final date =
          state.dashboardState.movedHomework[homeworkMoveKey(hw)] ?? day.date;
      final test = isTestEntry(hw);
      due(
        id: homeworkMoveKey(hw),
        title: '${test ? tr("Test") : tr("Aufgabe")}: ${[
          if (hw.label?.isNotEmpty == true) hw.label!,
          calendarPlainText(hw.title)
        ].join(' · ')}',
        notes: hw.subtitle,
        date: date,
        kind: test ? CalendarExportKind.test : CalendarExportKind.task,
      );
    }
  }
  final sorted = events.values.toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  return CalendarExportSnapshot(
    sorted,
    missingTime,
    '${state.url ?? ''}|${state.loginState.username ?? ''}',
  );
}
