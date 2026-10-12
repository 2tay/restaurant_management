import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether this device can scan with its camera.
///
/// `mobile_scanner` covers Android, iOS, macOS and the web. Windows and Linux
/// have no camera scanning at all; there, a handheld USB or Bluetooth scanner
/// types the code like a keyboard, and the screens take it through the scan
/// field and [HardwareScanListener] — so a missing camera button is the only
/// difference anybody sees.
bool get cameraScanAvailable {
  if (kIsWeb) return true;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}

/// Whether a quantity in [unitAbbreviation] is weighed or measured rather
/// than counted — kilos, grams, litres — and so cannot be read off a scan.
///
/// A scan says "one of these". For a bottle, a tin or a crate that is the
/// quantity; for a 25 kg sack of flour scanned once, "1 kg" would be wrong, so
/// those units ask for the figure instead. Units are free text in this app
/// (`bac`, `caisse`), so the test is on the handful of metric and imperial
/// abbreviations that mean weight or volume; anything else counts.
bool isMeasuredUnit(String unitAbbreviation) {
  final unit = unitAbbreviation.trim().toLowerCase().replaceAll('.', '');
  return _measured.contains(unit);
}

const Set<String> _measured = {
  'kg',
  'g',
  'gr',
  'mg',
  'l',
  'cl',
  'dl',
  'ml',
  'lb',
  'lbs',
  'oz',
  'kilo',
  'kilos',
  'litre',
  'litres',
  'gramme',
  'grammes',
};

/// The sound and the buzz of a scan that landed: the person scanning is
/// looking at the goods, not the screen, and needs to know without looking.
void scanFeedback() {
  HapticFeedback.mediumImpact();
  SystemSound.play(SystemSoundType.click);
}

/// The buzz of a scan that did not match anything.
void scanMissFeedback() {
  HapticFeedback.heavyImpact();
}
