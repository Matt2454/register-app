import 'package:dr/app_language.dart';
import 'package:flutter/material.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: languagePreference,
        builder: (context, preference, _) => PopupMenuButton<String>(
          tooltip: tr('Sprache'),
          initialValue: preference,
          onSelected: setAppLanguage,
          icon: const Icon(Icons.language_rounded),
          itemBuilder: (context) => [
            PopupMenuItem(value: 'system', child: Text(tr('Gerätesprache'))),
            const PopupMenuItem(value: 'en', child: Text('English')),
            const PopupMenuItem(value: 'it', child: Text('Italiano')),
            const PopupMenuItem(value: 'de', child: Text('Deutsch')),
          ],
        ),
      );
}
