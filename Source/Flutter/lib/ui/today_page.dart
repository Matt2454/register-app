// Copyright (C) 2026 kererleon
//
// This file is part of digitales_register.
//
// digitales_register is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// digitales_register is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with digitales_register.  If not, see <http://www.gnu.org/licenses/>.

import 'package:dr/absence_projection.dart';
import 'package:dr/agenda.dart';
import 'package:dr/app_language.dart';
import 'package:dr/app_state.dart';
import 'package:dr/calendar_export.dart' show calendarPlainText;
import 'package:dr/data.dart';
import 'package:dr/grade_forecast.dart';
import 'package:dr/lesson_time.dart';
import 'package:dr/ui/absence_meter.dart';
import 'package:dr/ui/holo.dart';
import 'package:dr/ui/theme.dart';
import 'package:dr/utc_date_time.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:responsive_scaffold/responsive_scaffold.dart';

/// Everything the "Heute" page shows, taken from the app state.
class TodayData {
  final AgendaSnapshot agenda;
  final UtcDateTime today;
  final List<CalendarHour> lessons;
  final bool lessonsLoaded;
  final List<Homework> dueToday;
  final List<Homework> dueTomorrow;
  final List<UpcomingTest> tests;

  /// The subject of each test, for the grade it needs.
  final Map<UpcomingTest, Subject> testSubjects;
  final Semester semester;
  final double? absencePercent;
  final AbsenceProjection? absenceProjection;
  final List<(Subject, double)> weakSubjects;
  final BuiltMapLike subjectNicks;

  const TodayData({
    required this.agenda,
    required this.today,
    required this.lessons,
    required this.lessonsLoaded,
    required this.dueToday,
    required this.dueTomorrow,
    required this.tests,
    required this.testSubjects,
    required this.semester,
    required this.absencePercent,
    this.absenceProjection,
    required this.weakSubjects,
    required this.subjectNicks,
  });

  static bool isTest(Homework hw) => isTestEntry(hw);

  factory TodayData.from(AppState state, {UtcDateTime? at}) {
    final agenda = AgendaSnapshot.from(state, at: at);
    final today = agenda.today;
    final tomorrow = today.add(const Duration(days: 1));
    final tests = <UpcomingTest>[
      for (final task in agenda.tests) UpcomingTest(task.homework, task.date),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final calendarDay = state.calendarState.days[today];
    final semester = state.gradesState.semester;
    final weak = <(Subject, double)>[
      for (final subject in state.gradesState.subjects)
        if (subject.average(semester) case final avg?)
          if (avg / 100 < passMark) (subject, avg / 100),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return TodayData(
      agenda: agenda,
      today: today,
      lessons: calendarDay?.hours.toList() ?? const [],
      lessonsLoaded: calendarDay != null,
      dueToday: agenda.dueOn(today).map((t) => t.homework).toList(),
      dueTomorrow: agenda.dueOn(tomorrow).map((t) => t.homework).toList(),
      tests: tests,
      testSubjects: {
        for (final test in tests)
          if (subjectForLabel(
            state.gradesState.subjects,
            test.homework.label,
          )
              case final subject?)
            test: subject,
      },
      semester: semester,
      absencePercent: parseAbsencePercentage(
        state.absencesState.statistic?.percentage,
      ),
      absenceProjection: switch (state.absencesState.statistic) {
        final stat? =>
          projectAbsences(stat, state.calendarState.days, DateTime.now()),
        null => null,
      },
      weakSubjects: weak,
      subjectNicks: BuiltMapLike(state.settingsState.subjectNicks.toMap()),
    );
  }
}

/// A plain map wrapper so [TodayData] does not depend on built_collection.
class BuiltMapLike {
  final Map<String, String> map;
  const BuiltMapLike(this.map);
  String nick(String subject) => map[subject.toLowerCase()] ?? subject;
}

typedef CreateStudyPlanCallback = void Function(
    UpcomingTest test, List<UtcDateTime> days);

class TodayPage extends StatelessWidget {
  final Widget? navigationDrawer;
  final TodayData data;
  final CreateStudyPlanCallback onCreateStudyPlan;
  final VoidCallback onShowGrades;
  final VoidCallback onShowAbsences;
  final VoidCallback onShowCalendar;
  final VoidCallback onShowTasks;
  final Future<void> Function() onRefresh;
  final bool noInternet;

  const TodayPage({
    super.key,
    this.navigationDrawer,
    required this.data,
    required this.onCreateStudyPlan,
    required this.onShowGrades,
    required this.onShowAbsences,
    required this.onShowCalendar,
    required this.onShowTasks,
    required this.onRefresh,
    required this.noInternet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      drawer: navigationDrawer,
      appBar: ResponsiveAppBar(
        title: Text(
            br(tr("Heute"), tr("Heute, no cap 💀"), tr("Shalom achi! 🇮🇱"))),
        actions: [
          IconButton(
              tooltip: tr("Aktualisieren"),
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: minuteTicker,
        builder: (context, _, __) => LayoutBuilder(
            builder: (context, constraints) => ListView(
                  padding: readablePadding(
                      constraints.maxWidth, const EdgeInsets.only(bottom: 40)),
                  children: [
                    _NowCard(data: data, onShowCalendar: onShowCalendar),
                    _AgendaStatus(data: data, noInternet: noInternet),
                    _TodayActions(
                        data: data,
                        onShowTasks: onShowTasks,
                        onShowCalendar: onShowCalendar),
                    if (data.agenda.overdue.isNotEmpty) ...[
                      SectionLabel(tr("Überfällig")),
                      for (final task in data.agenda.overdue.take(3))
                        _TaskRow(
                            homework: task.homework,
                            when: DateFormat('dd.MM.').format(task.date),
                            urgent: true),
                    ],
                    if (isIsrael) const _MemeOfTheDay(),
                    if (data.agenda.tasksLoaded &&
                        data.dueToday.isEmpty &&
                        data.dueTomorrow.isEmpty)
                      HoloPanel(
                          child: Text(tr(
                              'Keine offenen Aufgaben für heute oder morgen.'))),
                    if (data.dueToday.isNotEmpty ||
                        data.dueTomorrow.isNotEmpty) ...[
                      SectionLabel(br(tr("Fällig"), tr("Fällig 😬"),
                          tr("Fällig – yalla yalla ⏰"))),
                      for (final hw in data.dueToday.take(4))
                        _TaskRow(homework: hw, when: tr("Heute"), urgent: true),
                      for (final hw in data.dueTomorrow.take(3))
                        _TaskRow(homework: hw, when: tr("Morgen")),
                    ],
                    TextButton.icon(
                        onPressed: onShowTasks,
                        icon: const Icon(Icons.checklist_rounded),
                        label: Text(tr("Alle Aufgaben öffnen"))),
                    SectionLabel(br(tr("Tests & Schularbeiten"),
                        tr("Boss-Fights ⚔️"), tr("Tests – Yalla Balagan 🤯"))),
                    if (data.tests.isEmpty)
                      HoloPanel(
                        child: Text(
                          tr("Keine Tests in den nächsten 30 Tagen eingetragen."),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    for (final test in data.tests.take(5))
                      _TestCountdown(
                        test: test,
                        subject: data.testSubjects[test],
                        semester: data.semester,
                        today: data.today,
                        noInternet: noInternet,
                        onCreateStudyPlan: onCreateStudyPlan,
                      ),
                    if (data.weakSubjects.isNotEmpty) ...[
                      SectionLabel(br(
                          tr("Achtung bei den Noten"),
                          tr("Ohio-Zone 🌽"),
                          tr("Oy vey, Balagan bei den Noten 😵"))),
                      for (final (subject, avg) in data.weakSubjects)
                        HoloPanel(
                          accent: AppColors.danger,
                          onTap: onShowGrades,
                          child: Row(
                            children: [
                              NeonRing(
                                value: avg,
                                label: formatGradeSteps(avg),
                                size: 44,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(subject.name,
                                        style: theme.textTheme.titleMedium),
                                    Text(
                                      tr("Unter 6 – unter Noten siehst du, was du im nächsten Test brauchst."),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                    ],
                    if (data.absencePercent != null) ...[
                      SectionLabel(br(tr("Fehlstunden"),
                          tr("Skip-Statistik 🛌"), tr("Fehlstunden 🏖️"))),
                      HoloPanel(
                        onTap: onShowAbsences,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr("{0} % der Unterrichtszeit", [
                                NumberFormat('0.0', appLanguage.value)
                                    .format(data.absencePercent!)
                              ]),
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            AbsenceMeter(percent: data.absencePercent!),
                            if (data.absenceProjection
                                case final projection?) ...[
                              const SizedBox(height: 12),
                              AbsenceYearOutlook(projection: projection),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                )),
      ),
    );
  }
}

String _time(UtcDateTime t) => DateFormat("HH:mm").format(t);

String _lessonTimes(CalendarHour hour) {
  if (hour.timeSpans.isEmpty) return "";
  return "${_time(hour.timeSpans.first.from)}–${_time(hour.timeSpans.last.to)}";
}

class _NowCard extends StatelessWidget {
  final TodayData data;
  final VoidCallback onShowCalendar;
  const _NowCard({required this.data, required this.onShowCalendar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final agenda = data.agenda;
    final current = agenda.current;
    final focus = current ?? agenda.next;
    final now = agenda.now;
    final label = current != null ? tr("Jetzt") : tr("Nächste Stunde");
    final headline = focus != null
        ? data.subjectNicks.nick(focus.lesson.subject)
        : !data.lessonsLoaded
            ? tr("Stundenplan wird geladen")
            : data.lessons.isEmpty
                ? tr("Heute frei")
                : tr("Schulschluss");
    final remaining = focus == null
        ? null
        : (current != null ? focus.end : focus.start).difference(now);
    final minutes = remaining == null ? 0 : (remaining.inSeconds / 60).ceil();
    final progress = current == null
        ? null
        : (now.difference(current.start).inSeconds /
                current.end.difference(current.start).inSeconds)
            .clamp(0.0, 1.0);

    return GlowCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              HudLabel(DateFormat('EEEE, d. MMMM', appLanguage.value)
                  .format(data.today)),
              if (focus != null)
                StatusPill(
                    label: label,
                    color: current != null ? AppColors.cyan : AppColors.violet),
            ]),
        const SizedBox(height: 18),
        GradientText(headline, style: theme.textTheme.headlineMedium),
        if (focus != null) ...[
          const SizedBox(height: 10),
          Wrap(
              spacing: 18,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.schedule_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text('${_time(focus.start)}–${_time(focus.end)}',
                      style: theme.textTheme.titleMedium),
                ]),
                if (focus.lesson.rooms.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.meeting_room_outlined,
                        size: 18, color: AppColors.cyan),
                    const SizedBox(width: 6),
                    Flexible(
                        child: Text(
                            tr("Raum {0}", [focus.lesson.rooms.join(", ")]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium)),
                  ]),
              ]),
          const SizedBox(height: 10),
          Text(
              current != null
                  ? tr("Noch {0} min", [minutes])
                  : focus.start.stripTime() == data.today
                      ? tr("Beginnt in {0} min", [minutes])
                      : DateFormat('EEEE, d. MMMM', appLanguage.value)
                          .format(focus.start),
              style: theme.textTheme.bodyMedium),
          if (progress != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    color: AppColors.cyan,
                    backgroundColor: AppColors.cyan.withValues(alpha: 0.15))),
          ],
        ] else ...[
          const SizedBox(height: 8),
          Text(
              !data.lessonsLoaded
                  ? tr(
                      "Sobald die Woche geladen ist, siehst du hier deine Stunden.")
                  : data.lessons.isEmpty
                      ? tr("Kein Unterricht eingetragen.")
                      : tr("Für heute geschafft."),
              style: theme.textTheme.bodyMedium),
        ],
        if (data.lessons.isNotEmpty) ...[
          const SizedBox(height: 12),
          Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(tr("Stundenplan heute"),
                      style: theme.textTheme.titleSmall),
                  children: [
                    for (final hour in data.lessons)
                      _LessonLine(
                        hour: hour,
                        nick: data.subjectNicks.nick(hour.subject),
                        isNow: current?.lesson == hour,
                        isPast: hour.timeSpans.isNotEmpty &&
                            !now.isBefore(hour.timeSpans.last.to),
                      )
                  ])),
        ],
        Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
                onPressed: onShowCalendar,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(tr("Kalender öffnen")))),
      ]),
    );
  }
}

class _AgendaStatus extends StatelessWidget {
  final TodayData data;
  final bool noInternet;
  const _AgendaStatus({required this.data, required this.noInternet});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          Icon(noInternet ? Icons.cloud_off_rounded : Icons.sync_rounded,
              size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  data.agenda.lastUpdated == null
                      ? tr("Noch keine gespeicherten Daten")
                      : tr("{0}Letzte Aktualisierung: {1}", [
                          noInternet ? tr("Offline · ") : "",
                          DateFormat("dd.MM. HH:mm")
                              .format(data.agenda.lastUpdated!)
                        ]),
                  style: Theme.of(context).textTheme.bodySmall)),
        ]),
      );
}

class _TodayActions extends StatelessWidget {
  final TodayData data;
  final VoidCallback onShowTasks, onShowCalendar;
  const _TodayActions(
      {required this.data,
      required this.onShowTasks,
      required this.onShowCalendar});

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String count, Color accent, IconData icon,
            VoidCallback action) =>
        Expanded(
            child: HoloPanel(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.all(12),
          accent: accent,
          onTap: action,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 21, color: accent),
            const SizedBox(height: 10),
            Text(count, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(label,
                style: Theme.of(context).textTheme.labelMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
        ));
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          tile(
              tr("Fällig heute"),
              data.agenda.tasksLoaded ? '${data.dueToday.length}' : '–',
              AppColors.cyan,
              Icons.checklist_rounded,
              onShowTasks),
          tile(
              tr("Überfällig"),
              data.agenda.tasksLoaded ? '${data.agenda.overdue.length}' : '–',
              AppColors.warning,
              Icons.flag_outlined,
              onShowTasks),
          tile(
              tr("Nächster Test"),
              data.tests.isEmpty
                  ? '–'
                  : tr("{0} Tage",
                      [data.tests.first.date.difference(data.today).inDays]),
              AppColors.violet,
              Icons.event_outlined,
              onShowCalendar),
        ])));
  }
}

class _LessonLine extends StatelessWidget {
  final CalendarHour hour;
  final String nick;
  final bool isNow;
  final bool isPast;

  const _LessonLine({
    required this.hour,
    required this.nick,
    required this.isNow,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isNow ? AppColors.cyan : theme.colorScheme.onSurface;
    return Opacity(
      opacity: isPast ? 0.45 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isNow ? AppColors.cyan.withValues(alpha: 0.14) : null,
          borderRadius: BorderRadius.circular(10),
          border: isNow
              ? Border.all(color: AppColors.cyan.withValues(alpha: 0.6))
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                hour.fromHour == hour.toHour
                    ? "${hour.fromHour}."
                    : "${hour.fromHour}–${hour.toHour}",
                style: mono(theme.textTheme.bodySmall, weight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 92,
              child: Text(
                _lessonTimes(hour),
                style: mono(
                  theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            Expanded(
              child: Text(
                nick,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hour.warning)
              Icon(Icons.bolt_rounded, size: 16, color: AppColors.danger),
            if (hour.rooms.isNotEmpty)
              Text(
                hour.rooms.join(", "),
                style: mono(theme.textTheme.labelSmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final Homework homework;
  final String when;
  final bool urgent;
  const _TaskRow(
      {required this.homework, required this.when, this.urgent = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HoloPanel(
      accent: TodayData.isTest(homework)
          ? AppColors.danger
          : urgent
              ? AppColors.warning
              : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HudLabel(
                  [when, if (homework.label != null) homework.label!]
                      .join(" · "),
                ),
                const SizedBox(height: 4),
                Text(homework.title, style: theme.textTheme.titleMedium),
                if (homework.subtitle.isNotEmpty)
                  Text(
                    calendarPlainText(homework.subtitle),
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (homework.checked)
            Icon(Icons.check_circle_rounded, color: AppColors.success),
        ],
      ),
    );
  }
}

class _TestCountdown extends StatelessWidget {
  final UpcomingTest test;
  final Subject? subject;
  final Semester semester;
  final UtcDateTime today;
  final bool noInternet;
  final CreateStudyPlanCallback onCreateStudyPlan;

  const _TestCountdown({
    required this.test,
    required this.subject,
    required this.semester,
    required this.today,
    required this.noInternet,
    required this.onCreateStudyPlan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = test.date.difference(today).inDays;
    final countdown = switch (days) {
      0 => tr("Heute"),
      1 => tr("Morgen"),
      _ => tr("in {0} Tagen", [days]),
    };
    final color = days <= 1
        ? AppColors.danger
        : days <= 4
            ? AppColors.warning
            : AppColors.cyan;
    return HoloPanel(
      accent: color,
      highlighted: days <= 1,
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Column(
              children: [
                Text(
                  days <= 1 ? "!" : "$days",
                  style: mono(
                    theme.textTheme.headlineMedium?.copyWith(color: color),
                    weight: FontWeight.w700,
                  ),
                ),
                HudLabel(days <= 1 ? countdown : tr("Tage"), color: color),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HudLabel(
                  "${DateFormat("EE dd.MM.", appLanguage.value).format(test.date)}"
                  "${test.homework.label != null ? " · ${test.homework.label}" : ""}",
                ),
                const SizedBox(height: 4),
                Text(test.homework.title, style: theme.textTheme.titleMedium),
                if (test.homework.subtitle.isNotEmpty)
                  Text(
                    test.homework.subtitle,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (subject != null && subject!.average(semester) != null) ...[
                  const SizedBox(height: 8),
                  TestTargets(subject: subject!, semester: semester),
                ],
              ],
            ),
          ),
          if (days >= 2)
            IconButton(
              tooltip: tr("Lernplan erstellen"),
              icon: const Icon(Icons.auto_awesome_rounded),
              color: AppColors.violet,
              onPressed:
                  noInternet ? null : () => _showStudyPlanDialog(context),
            ),
        ],
      ),
    );
  }

  Future<void> _showStudyPlanDialog(BuildContext context) async {
    final maxSessions = test.date.difference(today).inDays.clamp(1, 5);
    var sessions = maxSessions.clamp(1, 3);
    final days = await showDialog<List<UtcDateTime>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final plan = studyDays(test.date, today, sessions);
          return AlertDialog(
            title: Text(tr("Lernplan erstellen")),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                      "Für „{0}“ am {1}. Die Lerntage werden als Erinnerungen im Register eingetragen.",
                      [
                        test.homework.title,
                        DateFormat("EEEE, d. MMMM", appLanguage.value)
                            .format(test.date)
                      ]),
                ),
                const SizedBox(height: 16),
                HudLabel(tr("Lerneinheiten")),
                Slider(
                  value: sessions.toDouble(),
                  min: 1,
                  max: maxSessions.toDouble(),
                  divisions: maxSessions > 1 ? maxSessions - 1 : null,
                  label: "$sessions",
                  onChanged: maxSessions > 1
                      ? (v) => setState(() => sessions = v.round())
                      : null,
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final d in plan)
                      Chip(
                        avatar: const Icon(Icons.menu_book_rounded, size: 16),
                        label: Text(DateFormat("EE dd.MM.", appLanguage.value)
                            .format(d)),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr("Abbrechen")),
              ),
              FilledButton(
                onPressed:
                    plan.isEmpty ? null : () => Navigator.pop(context, plan),
                child: Text(tr("{0} Erinnerungen eintragen", [plan.length])),
              ),
            ],
          );
        },
      ),
    );
    if (days != null && days.isNotEmpty) onCreateStudyPlan(test, days);
  }
}

/// The [sessions] days right before [testDate], from today on and without
/// Sundays.
List<UtcDateTime> studyDays(
    UtcDateTime testDate, UtcDateTime today, int sessions) {
  final result = <UtcDateTime>[];
  var day = testDate.subtract(const Duration(days: 1));
  while (result.length < sessions && !day.isBefore(today)) {
    if (day.weekday != DateTime.sunday) result.add(day);
    day = day.subtract(const Duration(days: 1));
  }
  return result.reversed.toList();
}

/// What a test needs for an average of 6, 7 and 8, as compact chips.
class TestTargets extends StatelessWidget {
  final Subject subject;
  final Semester semester;
  const TestTargets({super.key, required this.subject, required this.semester});

  @override
  Widget build(BuildContext context) {
    final current = subject.average(semester)! / 100;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        HudLabel(tr("Ø jetzt {0} · brauchst", [formatGradeSteps(current)])),
        for (final target in const [6.0, 7.0, 8.0])
          _TargetChip(
            target: target,
            forecast: forecastNextGrade(subject, semester, target: target),
          ),
      ],
    );
  }
}

class _TargetChip extends StatelessWidget {
  final double target;
  final Forecast forecast;
  const _TargetChip({required this.target, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final needed = roundUpToQuarter(forecast.required);
    final (text, color) = switch (forecast.kind) {
      ForecastKind.safe => (
          br("sicher", tr("safe 🗿"), tr("sababa 😎")),
          AppColors.success
        ),
      ForecastKind.impossible => (
          br(tr("unmöglich"), "L 💀", tr("oy vey 😵")),
          AppColors.danger
        ),
      ForecastKind.reachable => (formatGradeSteps(needed), gradeColor(needed)),
    };
    return StatusPill(
      label: "Ø${target.toStringAsFixed(0)} → $text",
      color: color,
    );
  }
}

/// A daily Israeli-slang meme in the israel look; tap for the next one.
class _MemeOfTheDay extends StatefulWidget {
  const _MemeOfTheDay();

  @override
  State<_MemeOfTheDay> createState() => _MemeOfTheDayState();
}

class _MemeOfTheDayState extends State<_MemeOfTheDay> {
  static final _memes = [
    ("🥙", tr("Hummus > Mathe"), tr("Wissenschaftlich bewiesen, achi.")),
    (
      "🤯",
      tr("Yalla Balagan"),
      tr("Mein Stundenplan, meine Hausaufgaben, mein Leben.")
    ),
    ("😎", tr("Sababa"), tr("Note 6. Reicht. Tachles.")),
    ("🍳", tr("Shakshuka Time"), tr("Erst frühstücken, dann lernen. Beseder?")),
    ("🏖️", tr("Matkot > Schule"), tr("Pling. Plong. Pling. Plong.")),
    (
      "👀",
      tr("Ma nishma?"),
      tr("Ich nach dem Test, wenn jemand nach den Lösungen fragt.")
    ),
    ("🥜", tr("Bamba-Pause"), tr("Wichtigster Teil des Schultags.")),
    (
      "💙",
      tr("Kapara alecha"),
      tr("An alle, die mir die Hausaufgaben schicken.")
    ),
    ("😵", tr("Oy vey"), tr("Die Schularbeit ist morgen?!")),
    ("✌️", tr("Yalla bye"), tr("Letzte Stunde vorbei, ich bin weg.")),
    ("🐪", tr("Langsam, achi"), tr("Kamel-Tempo am Montagmorgen.")),
    (
      "🎤",
      tr("Eurovision-Energie"),
      tr("So laut feiere ich jede bestandene Prüfung.")
    ),
    (
      "☀️",
      tr("Tel-Aviv-Mood"),
      tr("30 Grad im Kopf, 12 Grad im Klassenzimmer.")
    ),
    ("📚", tr("Achi, lern mal"), tr("– meine Eltern, jeden Tag.")),
    ("🧆", tr("Falafel-Logik"), tr("Je mehr Lernzettel, desto mehr Snacks.")),
    ("🇮🇱", tr("Shalom, Test"), tr("Wir sehen uns. Leider.")),
  ];

  late int _index =
      DateTime.now().difference(DateTime(2026)).inDays % _memes.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (emoji, title, text) = _memes[_index];
    return HoloPanel(
      onTap: () => setState(() => _index = (_index + 1) % _memes.length),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween(begin: -0.1, end: 0.0).animate(animation),
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Text(
              emoji,
              key: ValueKey(_index),
              style: const TextStyle(fontSize: 44),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HudLabel(tr("Meme des Tages · tippen für mehr")),
                const SizedBox(height: 4),
                Text(title, style: theme.textTheme.titleLarge),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
