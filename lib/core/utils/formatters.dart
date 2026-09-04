import 'package:intl/intl.dart';

/// Every number and date the user sees is formatted here.
///
/// Belgian French conventions differ from English *and* from France in places,
/// and getting them subtly wrong is exactly the kind of detail that makes an
/// app read as machine-translated:
///
/// - Currency: `12,50 €` — comma decimal, symbol last, non-breaking space
/// - Thousands: `1 250,00 €` — a space, never a comma
/// - Dates: `22/08/2026`, and spelled-out months are lowercase (`août`)
///
/// `intl` produces all of that correctly from the `fr_BE` locale. The only real
/// risk is somebody hand-rolling a format elsewhere, so this file is the single
/// place any of it happens.
abstract final class Formatters {
  static const String locale = 'fr_BE';

  // ---------------------------------------------------------------------------
  // Money
  // ---------------------------------------------------------------------------

  static final NumberFormat _currency = NumberFormat.currency(
    locale: locale,
    symbol: '€',
    decimalDigits: 2,
  );

  static final NumberFormat _currencyCompact = NumberFormat.currency(
    locale: locale,
    symbol: '€',
    decimalDigits: 0,
  );

  /// The symbol on its own, for a field's suffix where the value is being
  /// typed rather than displayed.
  static const String currencySymbol = '€';

  /// `12,50 €`
  static String price(double value) => _currency.format(value);

  /// A number as the user typed it, or null if it is not one yet.
  ///
  /// Accepts the comma decimal separator a Belgian keyboard produces. Here
  /// rather than at each call site for the same reason every format is: one
  /// screen accepting `12,50` while another silently rejects it is precisely
  /// the kind of inconsistency nobody reports and everybody works around.
  static double? parseDecimal(String raw) =>
      double.tryParse(raw.replaceAll(',', '.').trim());

  /// `1 248 €` — for dashboard tiles where the cents are noise.
  static String priceCompact(double value) => _currencyCompact.format(value);

  /// `+0,35 €` / `−0,20 €`
  ///
  /// Uses a real minus sign (U+2212) rather than a hyphen: at a glance in a
  /// price-change column, a hyphen reads as a dash rather than as negative.
  static String priceDelta(double value) {
    final formatted = _currency.format(value.abs());
    return value < 0 ? '−$formatted' : '+$formatted';
  }

  // ---------------------------------------------------------------------------
  // Quantities
  // ---------------------------------------------------------------------------

  static final NumberFormat _quantity = NumberFormat.decimalPattern(locale)
    ..maximumFractionDigits = 2
    ..minimumFractionDigits = 0;

  /// `48` / `2,5`
  static String quantity(double value) => _quantity.format(value);

  /// `48 kg` / `2,5 L`
  static String quantityWithUnit(double value, String unitAbbreviation) =>
      '${quantity(value)} $unitAbbreviation';

  /// `+12 kg` / `−3 kg`, for movement rows.
  static String quantityDelta(double value, String unitAbbreviation) {
    final formatted = quantityWithUnit(value.abs(), unitAbbreviation);
    return value < 0 ? '−$formatted' : '+$formatted';
  }

  /// `12 %`
  ///
  /// Takes 0.0–1.0. French puts a space before the percent sign.
  static String percent(double fraction) =>
      '${_quantity.format(fraction * 100)} %';

  // ---------------------------------------------------------------------------
  // Durations
  // ---------------------------------------------------------------------------

  /// `7 h 48` — worked time, break length, overtime.
  static String duration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    return '$hours h ${minutes.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Dates
  // ---------------------------------------------------------------------------

  static final DateFormat _shortDate = DateFormat('dd/MM/yyyy', locale);
  static final DateFormat _longDate = DateFormat('d MMMM yyyy', locale);
  static final DateFormat _dayMonth = DateFormat('d MMM', locale);
  static final DateFormat _time = DateFormat('HH:mm', locale);

  /// `22/08/2026`
  static String date(DateTime value) => _shortDate.format(value);

  /// `22 août 2026`
  static String dateLong(DateTime value) => _longDate.format(value);

  /// `22 août` — chart axes and compact rows.
  static String dayMonth(DateTime value) => _dayMonth.format(value);

  /// `14:32` — Belgium uses a 24-hour clock.
  static String time(DateTime value) => _time.format(value);

  /// Minutes since midnight → `08:30`. For a stored schedule time that is a
  /// plain int rather than a `DateTime` (see `Employee.scheduledStartMinutes`).
  static String minutesToClock(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// `08:30` / `8h30` / `8:30` → minutes since midnight, or null if it does
  /// not parse to a valid time of day.
  static int? clockToMinutes(String value) {
    final match = RegExp(
      r'^\s*(\d{1,2})\s*[:hH]\s*(\d{2})\s*$',
    ).firstMatch(value);
    if (match == null) return null;
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    if (h > 23 || m > 59) return null;
    return h * 60 + m;
  }

  /// `22/08/2026 à 14:32`
  static String dateTime(DateTime value) => '${date(value)} à ${time(value)}';

  /// `il y a 3 jours`, `hier`, `à l'instant`.
  ///
  /// Falls back to an absolute date beyond a month — "il y a 47 jours" is
  /// harder to reason about than the date itself.
  static String relative(DateTime value, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final difference = reference.difference(value);

    if (difference.inMinutes < 1) return "à l'instant";
    if (difference.inMinutes < 60) return 'il y a ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'il y a ${difference.inHours} h';
    if (difference.inDays == 1) return 'hier';
    if (difference.inDays < 30) return 'il y a ${difference.inDays} jours';
    return date(value);
  }
}
