import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where an employee's photo file lives once it has been chosen.
///
/// `Employee.photoAsset` holds a string the avatar renders. Before this it was
/// only ever an asset path (and never actually set); now it can also be an
/// absolute path to a file this store owns — [employeePhotoImage] in
/// `shared/widgets/employee_avatar.dart` tells the two apart.
///
/// Not a repository: it touches the filesystem, not the database, and the write
/// layer stays SQL-only. The add / edit form calls it, then writes the returned
/// path onto the employee row through `EmployeeRepository.update`.
///
/// [baseDir] is injectable so a test can point it at a temp directory — the
/// default reaches a real platform channel (`getApplicationSupportDirectory`).
class EmployeePhotoStore {
  EmployeePhotoStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDir;

  static const String _folder = 'employee_photos';

  /// The folder, once resolved: what the avatar reads synchronously
  /// (`employeePhotoImage`). `main()` resolves it before the first frame.
  static Directory? cachedDirectory;

  /// Bumped when a photo file arrives from the server (SYNC_PLAN.md,
  /// Phase 8), so avatars already on screen show it.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<Directory> directory() => _dir();

  Future<Directory> _dir() async {
    final base = await _baseDir();
    final dir = Directory(p.join(base.path, _folder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    cachedDirectory = dir;
    return dir;
  }

  /// The file behind a stored photo name.
  Future<File> fileFor(String name) async => File(p.join((await _dir()).path, name));

  /// Writes a photo received from the server under its name.
  Future<void> write(String name, List<int> bytes) async {
    await (await fileFor(name)).writeAsBytes(bytes, flush: true);
    revision.value++;
  }

  /// Copies [sourcePath] into the store as this employee's photo and returns the
  /// absolute path written. Any previous photo for [employeeId] is removed
  /// first, and the new file name carries a timestamp so `Image.file`'s
  /// path-keyed cache cannot serve the old bytes after a replacement.
  Future<String> save({
    required String employeeId,
    required String sourcePath,
  }) async {
    final dir = await _dir();
    await deleteFor(employeeId);

    final ext = p.extension(sourcePath).toLowerCase();
    final safeExt = ext.isEmpty ? '.png' : ext;
    final dest = p.join(
      dir.path,
      '$employeeId-${DateTime.now().microsecondsSinceEpoch}$safeExt',
    );
    await File(sourcePath).copy(dest);
    // The bare name, not the path: the row syncs to other tablets, where this
    // device's path means nothing (SYNC_PLAN.md, Phase 8).
    return p.basename(dest);
  }

  /// Removes every stored photo for [employeeId]. Safe to call when there is
  /// none.
  Future<void> deleteFor(String employeeId) async {
    final dir = await _dir();
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File &&
          p.basename(entity.path).startsWith('$employeeId-')) {
        try {
          await entity.delete();
        } catch (_) {
          // A file we cannot delete is not worth failing the save over.
        }
      }
    }
  }
}
