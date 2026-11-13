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

import 'dart:math';

import 'package:dr/absence_projection.dart';
import 'package:dr/app_language.dart';
import 'package:dr/ui/holo.dart';
import 'package:dr/ui/theme.dart';
import 'package:flutter/material.dart';

/// Students who miss more than a quarter of the lessons can not be admitted
/// to the end-of-year assessment (except for documented reasons).
const absenceLimitPercent = 25.0;

double? parseAbsencePercentage(String? value) =>
    value == null ? null : double.tryParse(value.replaceAll(",", "."));

/// Traffic light for the share of missed lessons.
(Color, String) absenceLevel(double percent) {
  if (percent < 10)
    return (
      AppColors.success,
      br(tr("Im grünen Bereich"), tr("Chillig 😎"), tr("Sababa 😎"))
    );
  if (percent < 18)
    return (
      AppColors.warning,
      br(tr("Aufpassen"), tr("Sus 👀"), tr("Achi, aufpassen 👀"))
    );
  if (percent < absenceLimitPercent)
    return (
      AppColors.danger,
      br(tr("Kritisch"), tr("Gefährlich 💀"), tr("Oy vey! Balagan 😱"))
    );
  return (
    AppColors.danger,
    br(tr("Über der Grenze"), tr("Game over 💀"), tr("Balagan total 😱"))
  );
}

/// A bar from 0 to the 25 % limit with the student's current share.
class AbsenceMeter extends StatelessWidget {
  final double percent;
  const AbsenceMeter({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, label) = absenceLevel(percent);
    final left = (absenceLimitPercent - percent).clamp(0, absenceLimitPercent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatusPill(label: label, color: color),
            const Spacer(),
            HudLabel(
              percent >= absenceLimitPercent
                  ? tr("Grenze 25 % überschritten")
                  : tr("noch {0} % bis 25 %",
                      [left.toStringAsFixed(1).replaceAll(".", ",")]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final fraction = (percent / absenceLimitPercent).clamp(0.0, 1.0);
            return Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 8,
                  width: constraints.maxWidth * fraction,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.6), color],
                    ),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

String _decimal(double value) => value.toStringAsFixed(1).replaceAll(".", ",");

/// Whole hours, but a little absence never shows as 0.
String _hours(double value) =>
    value > 0 && value < 1 ? "1" : value.round().toString();

/// How many lessons may still be missed until the end of the school year,
/// and the share of the whole year already missed.
class AbsenceYearOutlook extends StatelessWidget {
  final AbsenceProjection projection;
  const AbsenceYearOutlook({super.key, required this.projection});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final p = projection;
    // Colour by how much of the year's allowance is used up.
    final used = p.totalLessons == 0
        ? 1.0
        : 1 -
            p.stillAllowed / max(1, p.totalLessons * absenceLimitPercent / 100);
    final (color, _) = absenceLevel(used * absenceLimitPercent);
    final end = "${p.end.day}. ${_months[p.end.month - 1]}";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_available_outlined, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: p.stillAllowed == 0
                          ? br(
                              tr("Keine Fehlstunde mehr übrig"),
                              tr("0 Skips übrig 💀"),
                              tr("Keine Stunde mehr übrig 😱"))
                          : "${br(tr("Noch"), tr("Noch"), tr("Noch"))} ~${p.stillAllowed} "
                              "${p.stillAllowed == 1 ? tr("Stunde") : tr("Stunden")} ",
                      style: theme.textTheme.titleSmall?.copyWith(color: color),
                    ),
                    if (p.stillAllowed > 0)
                      TextSpan(
                        text: tr("fehlen bis Schulende ({0}) erlaubt", [end]),
                        style: theme.textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Text(
            tr("Aufs ganze Schuljahr: {0} % (~{1} von ~{2} Stunden)",
                [_decimal(p.yearPercent), _hours(p.missed), p.totalLessons]),
            style: muted,
          ),
        ),
      ],
    );
  }
}

List<String> get _months => [
      tr("Jänner"),
      tr("Februar"),
      tr("März"),
      tr("April"),
      tr("Mai"),
      tr("Juni"),
      tr("Juli"),
      tr("August"),
      tr("September"),
      tr("Oktober"),
      tr("November"),
      tr("Dezember"),
    ];
