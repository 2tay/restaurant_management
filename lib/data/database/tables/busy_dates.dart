import 'package:drift/drift.dart';

import 'stores.dart';
import 'sync_columns.dart';

/// The one-off busy days of the calendar — a public holiday, a festival, a
/// local event — on top of the weekdays that are busy every week
/// ([Stores.busyWeekdays]).
///
/// [day] is the calendar date as `YYYY-MM-DD` text, not a `DateTime`. A busy
/// day is a date on the wall calendar, not an instant: stored as a timestamp,
/// "25 December" would drift to the 24th the day the machine's time zone or
/// daylight-saving offset disagreed with the one that wrote it.
@DataClassName('BusyDateRow')
class BusyDates extends Table with Touched, Deletable {
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();
  TextColumn get day => text().withLength(min: 10, max: 10)();

  @override
  Set<Column<Object>> get primaryKey => {storeId, day};
}
