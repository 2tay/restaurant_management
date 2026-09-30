import 'package:drift/drift.dart';

/// Photos waiting to reach the server, or to leave it (SYNC_PLAN.md,
/// Phase 8).
///
/// Filled by the triggers in `photo_triggers.drift` whenever an article's or
/// an employee's photo is set, replaced or dropped, and emptied by the sync
/// pass (`PhotoSync`). The row naming the photo travels through the outbox;
/// the file travels through here.
///
/// One entry per file: a photo set, then dropped before the next sync, ends
/// as a single `remove` operation.
///
/// Local only: never synced.
@DataClassName('PhotoUploadRow')
@TableIndex(name: 'photo_uploads_file', columns: {#kind, #fileName}, unique: true)
class PhotoUploads extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `items` or `employees`: the folder on the server.
  TextColumn get kind => text()();

  /// The establishment: the top folder on the server.
  TextColumn get storeId => text()();

  /// The file name, as the row stores it (`items.image_path`,
  /// `employees.photo_asset`).
  TextColumn get fileName => text()();

  /// `upload` or `remove`. (Not `action`: a keyword in drift's SQL.)
  TextColumn get operation => text()();

  DateTimeColumn get queuedAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}
