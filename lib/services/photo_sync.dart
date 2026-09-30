import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../data/database/app_database.dart';
import '../data/employee_photo_store.dart';
import '../data/images/product_images.dart';
import 'auth_service.dart';

/// Photo files between the device and the server (SYNC_PLAN.md, Phase 8).
///
/// Rows naming a photo (`items.image_path`, `employees.photo_asset`) travel
/// through the outbox like any row. The files travel here:
///
/// - [upload]: every photo in `photo_uploads` marked `upload` is shrunk
///   (longest side 1024 px, JPEG) and put at `<store>/<kind>/<file>` in the
///   server's private `photos` store. Runs **before** the rows are sent, so a
///   tablet receiving the row can already find its file.
/// - [removeOld]: photos marked `remove` (replaced, dropped, or their row
///   deleted) leave the server. Runs **after** the rows are sent: a photo is
///   only removed once the change that dropped it has gone out.
/// - [downloadMissing]: every photo a live row names but this device does not
///   have is fetched, in the background, after receiving. Offline, screens
///   show their usual placeholder.
///
/// A photo never blocks sync: a failed upload is retried next pass, a photo
/// the server does not have is skipped.
class PhotoSync {
  PhotoSync({
    required AppDatabase db,
    required AccountBackend backend,
    PhotoFiles? files,
  }) : _db = db,
       _backend = backend,
       _files = files ?? DevicePhotoFiles();

  final AppDatabase _db;
  final AccountBackend _backend;
  final PhotoFiles _files;

  /// Longest side of an uploaded photo, in pixels.
  static const int maxSide = 1024;

  /// Uploads queued photos. Returns how many went up; throws
  /// [AccountException] with [AccountErrorCode.network] when offline.
  Future<int> upload() async {
    var uploaded = 0;
    for (final entry in await _queued('upload')) {
      final file = await _files.file(entry.kind, entry.fileName);
      if (file == null || !await file.exists()) {
        // Nothing to send: the file was replaced or cleared meanwhile.
        await _done(entry);
        continue;
      }
      try {
        final shrunk = await shrink(await file.readAsBytes());
        await _backend.uploadPhoto(
          _path(entry),
          shrunk.bytes,
          contentType: shrunk.contentType,
        );
        await _done(entry);
        uploaded++;
      } on AccountException catch (error) {
        await _failed(entry, error.toString());
        if (error.code == AccountErrorCode.network) rethrow;
      }
    }
    return uploaded;
  }

  /// Removes photos that were replaced, dropped, or whose row was deleted.
  Future<int> removeOld() async {
    final entries = await _queued('remove');
    if (entries.isEmpty) return 0;
    try {
      await _backend.removePhotos([for (final e in entries) _path(e)]);
    } on AccountException catch (error) {
      for (final entry in entries) {
        await _failed(entry, error.toString());
      }
      if (error.code == AccountErrorCode.network) rethrow;
      return 0;
    }
    for (final entry in entries) {
      await _done(entry);
    }
    return entries.length;
  }

  /// Fetches every photo a live row names that this device does not have.
  Future<int> downloadMissing() async {
    var downloaded = 0;
    for (final (kind, storeId, name) in await _namedPhotos()) {
      final file = await _files.file(kind, name);
      if (file != null && await file.exists()) continue;
      // Asked again every pass while missing: the other tablet may not have
      // uploaded it yet.
      final bytes = await _backend.downloadPhoto('$storeId/$kind/$name');
      if (bytes == null) continue;
      await _files.write(kind, name, bytes);
      downloaded++;
    }
    return downloaded;
  }

  /// A photo made small enough to send: longest side [maxSide] pixels, JPEG.
  /// Anything that does not decode as an image is sent as it is.
  static Future<({Uint8List bytes, String contentType})> shrink(
    Uint8List original,
  ) async {
    try {
      final encoded = await Isolate.run(() => _shrinkSync(original));
      if (encoded != null) return (bytes: encoded, contentType: 'image/jpeg');
    } catch (_) {
      // Fall through: send the original.
    }
    return (bytes: original, contentType: 'image/jpeg');
  }

  static Uint8List? _shrinkSync(Uint8List original) {
    final decoded = img.decodeImage(original);
    if (decoded == null) return null;
    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final resized = longest <= maxSide
        ? decoded
        : img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxSide : null,
            height: decoded.height > decoded.width ? maxSide : null,
          );
    return img.encodeJpg(resized, quality: 82);
  }

  static String _path(PhotoUploadRow entry) =>
      '${entry.storeId}/${entry.kind}/${entry.fileName}';

  Future<List<PhotoUploadRow>> _queued(String operation) =>
      (_db.select(_db.photoUploads)
            ..where((u) => u.operation.equals(operation))
            ..orderBy([(u) => OrderingTerm(expression: u.id)]))
          .get();

  /// Removes an entry, unless the photo was queued again while it travelled.
  Future<void> _done(PhotoUploadRow entry) =>
      (_db.delete(_db.photoUploads)..where(
            (u) =>
                u.id.equals(entry.id) &
                u.operation.equals(entry.operation) &
                u.queuedAt.equals(entry.queuedAt),
          ))
          .go();

  Future<void> _failed(PhotoUploadRow entry, String error) =>
      (_db.update(
        _db.photoUploads,
      )..where((u) => u.id.equals(entry.id))).write(
        PhotoUploadsCompanion(
          attempts: Value(entry.attempts + 1),
          lastError: Value(error),
        ),
      );

  /// Every bare photo name a live article or employee holds.
  Future<List<(String, String, String)>> _namedPhotos() async {
    final items =
        await (_db.select(_db.items)
              ..where((i) => i.imagePath.isNotNull() & i.deletedAt.isNull()))
            .get();
    final employees =
        await (_db.select(_db.employees)..where(
              (e) => e.photoAsset.isNotNull() & e.deletedAt.isNull(),
            ))
            .get();
    bool bare(String name) => !name.contains('/') && !name.contains(r'\');
    return [
      for (final item in items)
        if (bare(item.imagePath!)) ('items', item.storeId, item.imagePath!),
      for (final employee in employees)
        if (bare(employee.photoAsset!))
          ('employees', employee.storeId, employee.photoAsset!),
    ];
  }
}

/// Where photo files live on this device, by kind.
abstract interface class PhotoFiles {
  Future<File?> file(String kind, String name);
  Future<void> write(String kind, String name, List<int> bytes);
}

/// The app's own folders: `ProductImages` and `EmployeePhotoStore`.
class DevicePhotoFiles implements PhotoFiles {
  DevicePhotoFiles({EmployeePhotoStore? employees})
    : _employees = employees ?? EmployeePhotoStore();

  final EmployeePhotoStore _employees;

  @override
  Future<File?> file(String kind, String name) => kind == 'items'
      ? ProductImages.fileFor(name)
      : _employees.fileFor(name);

  @override
  Future<void> write(String kind, String name, List<int> bytes) =>
      kind == 'items'
      ? ProductImages.write(name, bytes)
      : _employees.write(name, bytes);
}

/// A folder per kind under one directory, for tests.
class FolderPhotoFiles implements PhotoFiles {
  FolderPhotoFiles(this.root);

  final Directory root;

  @override
  Future<File?> file(String kind, String name) async =>
      File(p.join(root.path, kind, name));

  @override
  Future<void> write(String kind, String name, List<int> bytes) async {
    final file = File(p.join(root.path, kind, name));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }
}
