import 'package:dr/app_language.dart';
import 'package:dr/calendar_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const appleCalendarChannel = MethodChannel('register/apple_calendar');

Future<void> showAppleCalendarExport(
  BuildContext context,
  CalendarExportSnapshot snapshot,
  DateTime monday,
) async {
  final selected = CalendarExportKind.values.toSet();
  var skipExisting = true;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(tr("In Apple Kalender exportieren")),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('dd.MM.yyyy').format(monday)} – ${DateFormat('dd.MM.yyyy').format(monday.add(const Duration(days: 6)))}',
                ),
                const SizedBox(height: 12),
                for (final kind in CalendarExportKind.values)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(kind),
                    title: Text(
                      '${switch (kind) {
                        CalendarExportKind.lesson => tr("Unterricht"),
                        CalendarExportKind.test => tr("Tests"),
                        CalendarExportKind.task => tr("Aufgaben"),
                      }} (${snapshot.events.where((e) => e.kind == kind).length})',
                    ),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        selected.add(kind);
                      } else {
                        selected.remove(kind);
                      }
                    }),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr("Doppelte vermeiden")),
                  subtitle: Text(
                    tr("Bereits von dieser App exportierte Termine überspringen."),
                  ),
                  value: skipExisting,
                  onChanged: (value) => setState(() => skipExisting = value),
                ),
                const SizedBox(height: 8),
                Text(
                  tr("Einmalige Kopie der angezeigten Woche. Änderungen werden nicht automatisch übernommen. Tests und Aufgaben werden als ganztägige Fälligkeiten hinzugefügt."),
                ),
                if (snapshot.lessonsWithoutTime > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    tr("{0} Unterrichtseinträge ohne Uhrzeit werden ausgelassen.",
                        [snapshot.lessonsWithoutTime]),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr("Abbrechen")),
          ),
          FilledButton(
            onPressed: snapshot.events.any((e) => selected.contains(e.kind))
                ? () => Navigator.pop(context, true)
                : null,
            child: Text(tr("Kalender auswählen")),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    final response =
        await appleCalendarChannel.invokeMapMethod<String, dynamic>('export', {
      'events': snapshot.events
          .where((e) => selected.contains(e.kind))
          .map((e) => e.toMap())
          .toList(),
      'scope': snapshot.accountScope,
      'language': appLanguage.value,
      'skipExisting': skipExisting,
    });
    if (!context.mounted || response?['cancelled'] == true) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("Export abgeschlossen")),
        content: Text(
          tr("{0} Termine exportiert · {1} bereits vorhanden.",
              [response?['added'] ?? 0, response?['skipped'] ?? 0]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr("OK")),
          ),
        ],
      ),
    );
  } on PlatformException catch (e) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("Kalenderexport")),
        content: Text(
          e.message ??
              tr("Der Export ist fehlgeschlagen. Bitte erneut versuchen."),
        ),
        actions: [
          if (e.code == 'calendar_permission')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                appleCalendarChannel.invokeMethod<void>('openSettings');
              },
              child: Text(tr("Einstellungen")),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr("OK")),
          ),
        ],
      ),
    );
  } on MissingPluginException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr("Bitte die aktualisierte iOS-Version installieren, um Kalender zu exportieren."),
        ),
      ),
    );
  }
}
