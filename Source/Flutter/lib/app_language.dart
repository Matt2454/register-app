import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const supportedLanguageCodes = ['en', 'it', 'de'];
final appLanguage = ValueNotifier<String>('de');
final languagePreference = ValueNotifier<String>('system');
final Map<String, Map<String, dynamic>> _catalogs = {};

String _resolveLanguage(String preference) {
  if (supportedLanguageCodes.contains(preference)) return preference;
  for (final locale in PlatformDispatcher.instance.locales) {
    if (supportedLanguageCodes.contains(locale.languageCode)) {
      return locale.languageCode;
    }
  }
  return 'en';
}

Future<void> loadAppLanguage() async {
  for (final code in supportedLanguageCodes) {
    final values =
        jsonDecode(await rootBundle.loadString('assets/i18n/$code.json'))
            as Map<String, dynamic>;
    _catalogs[code] = values;
    await initializeDateFormatting(code);
  }
  final prefs = await SharedPreferences.getInstance();
  languagePreference.value = prefs.getString('app.language') ?? 'system';
  appLanguage.value = _resolveLanguage(languagePreference.value);
  Intl.defaultLocale = appLanguage.value;
}

Future<void> setAppLanguage(String preference) async {
  if (preference != 'system' && !supportedLanguageCodes.contains(preference)) {
    throw ArgumentError.value(preference, 'preference');
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('app.language', preference);
  languagePreference.value = preference;
  appLanguage.value = _resolveLanguage(preference);
  Intl.defaultLocale = appLanguage.value;
}

void updateSystemLanguage() {
  if (languagePreference.value == 'system') {
    appLanguage.value = _resolveLanguage('system');
    Intl.defaultLocale = appLanguage.value;
  }
}

/// German source keys keep existing school data and persisted identifiers intact.
/// Arguments are substituted after lookup, so names and server content never
/// become translation keys or lose their original text.
String tr(String source, [List<Object?> arguments = const []]) {
  final translated = _catalogs[appLanguage.value]?[source] ?? source;
  final String value;
  if (translated is Map) {
    final count = arguments.isEmpty ? null : num.tryParse('${arguments.first}');
    value = Intl.plural(count ?? 0,
        one: translated['one'] as String,
        other: translated['other'] as String,
        locale: appLanguage.value);
  } else {
    value = translated as String;
  }
  return value.replaceAllMapped(RegExp(r'\{(\d+)\}'), (match) {
    final index = int.parse(match[1]!);
    return index < arguments.length ? '${arguments[index] ?? ''}' : match[0]!;
  });
}
