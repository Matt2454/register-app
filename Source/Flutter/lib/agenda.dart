import 'package:dr/app_state.dart';
import 'package:dr/data.dart';
import 'package:dr/lesson_time.dart';
import 'package:dr/utc_date_time.dart';

/// One teaching period. Separate periods keep breaks out of live countdowns.
class AgendaPeriod {
  final CalendarHour lesson;
  final UtcDateTime start, end;
  const AgendaPeriod(this.lesson, this.start, this.end);
}

class AgendaTask {
  final Homework homework;
  final UtcDateTime date;
  const AgendaTask(this.homework, this.date);
}

/// The same filtered, dated data powers Today and the iOS widgets.
class AgendaSnapshot {
  final UtcDateTime now, today;
  final List<CalendarHour> lessons;
  final List<AgendaPeriod> periods;
  final List<AgendaTask> tasks;
  final bool lessonsLoaded, tasksLoaded;
  final UtcDateTime? lastUpdated;

  const AgendaSnapshot._(this.now, this.today, this.lessons, this.periods,
      this.tasks, this.lessonsLoaded, this.tasksLoaded, this.lastUpdated);

  factory AgendaSnapshot.from(AppState state, {UtcDateTime? at}) {
    final now = at ?? wallClockNow();
    final today = now.stripTime();
    final horizon = today.add(const Duration(days: 14));
    final calendarDay = state.calendarState.days[today];
    final lessons = calendarDay?.hours.toList() ?? <CalendarHour>[];
    lessons.sort((a, b) => a.fromHour.compareTo(b.fromHour));
    final periods = <AgendaPeriod>[
      for (final day in state.calendarState.days.values)
        if (!day.date.isBefore(today) && !day.date.isAfter(horizon))
          for (final lesson in day.hours)
            for (final span in lesson.timeSpans)
              if (span.to.isAfter(span.from))
                AgendaPeriod(lesson, span.from, span.to),
    ]..sort((a, b) => a.start.compareTo(b.start));
    final pending = <String, AgendaTask>{};
    final completed = <String>{
      for (final day in state.dashboardState.allDays ?? <Day>[])
        for (final task in day.homework)
          if (task.deleted || task.checked) homeworkMoveKey(task),
    };
    final timestamps = <UtcDateTime>[
      if (calendarDay?.lastFetched != null) calendarDay!.lastFetched!,
      for (final day in state.dashboardState.allDays ?? <Day>[])
        day.lastRequested,
    ];
    for (final day in state.dashboardState.allDays ?? <Day>[]) {
      for (final hw in day.homework) {
        final key = homeworkMoveKey(hw);
        if (completed.contains(key) ||
            hw.type == HomeworkType.grade ||
            hw.type == HomeworkType.observation) {
          continue;
        }
        final date =
            (state.dashboardState.movedHomework[key] ?? day.date).stripTime();
        // Old uncompleted reminders remain visible as overdue; never invent a
        // deadline from the time at which the dashboard was downloaded.
        pending.putIfAbsent(key, () => AgendaTask(hw, date));
      }
    }
    final tasks = pending.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    timestamps.sort();
    return AgendaSnapshot._(
        now,
        today,
        lessons,
        periods,
        tasks,
        calendarDay != null,
        state.dashboardState.allDays != null,
        timestamps.isEmpty ? null : timestamps.last);
  }

  AgendaPeriod? get current {
    for (final period in periods) {
      if (!now.isBefore(period.start) && now.isBefore(period.end)) {
        return period;
      }
    }
    return null;
  }

  AgendaPeriod? get next {
    for (final period in periods) {
      if (period.start.isAfter(now)) return period;
    }
    return null;
  }

  List<AgendaTask> dueOn(UtcDateTime date) =>
      tasks.where((t) => t.date == date.stripTime()).toList();
  List<AgendaTask> get overdue => tasks
      .where((t) =>
          t.date.isBefore(today) &&
          t.homework.checkable &&
          !isTestEntry(t.homework))
      .toList()
      .reversed
      .toList();
  List<AgendaTask> get tests => tasks
      .where((t) =>
          isTestEntry(t.homework) &&
          !t.date.isBefore(today) &&
          t.date.difference(today).inDays <= 30)
      .toList();
}
