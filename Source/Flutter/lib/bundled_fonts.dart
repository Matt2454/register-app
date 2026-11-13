import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

bool _configured = false;

/// Use the original designs' fonts from assets, including on first offline use.
void configureBundledFonts() {
  GoogleFonts.config.allowRuntimeFetching = false;
  if (_configured) return;
  _configured = true;
  LicenseRegistry.addLicense(() async* {
    for (final family in [
      'Inter',
      'Sora',
      'Bangers',
      'ComicNeue',
      'Rubik',
      'JetBrainsMono',
    ]) {
      final license =
          await rootBundle.loadString('assets/fonts/LICENSE-$family.txt');
      yield LicenseEntryWithLineBreaks([family], license);
    }
  });
}
