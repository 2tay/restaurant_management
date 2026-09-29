import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

/// The "when did this row last change" stamp every synced table carries.
///
/// Set on insert by a client default, which reads `clock.now()` like the rest
/// of the app so a test can fix it. Set on update by the `*_touch` triggers in
/// `sync_triggers.drift`, which stamp the row whenever a write leaves this
/// column as it was. Nothing in a repository has to remember it.
///
/// **Always UTC**, to the millisecond. The trigger cannot write local time:
/// SQLite's `localtime` depends on how the library was built, and the Windows
/// one returns nothing. UTC from both sides keeps every value in one format,
/// so the column sorts correctly as text. It is a sync stamp, not something a
/// screen shows.
///
/// [Items] does not use this mixin: it had its own `updatedAt` before sync,
/// with a meaning the screens rely on ("last stock change"), and the same
/// trigger covers it.
mixin Touched on Table {
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => syncStampNow())();
}

/// Now, in UTC and to the millisecond: the same value the `*_touch` triggers
/// write, in the same format.
DateTime syncStampNow() => DateTime.fromMillisecondsSinceEpoch(
  clock.now().millisecondsSinceEpoch,
  isUtc: true,
);

/// A soft delete.
///
/// A deleted row stays in the table with this column set, and every read query
/// skips it. A row removed for real leaves nothing behind to tell another
/// device about, which is why synced tables never lose a row once sync exists.
mixin Deletable on Table {
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
