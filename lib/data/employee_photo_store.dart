import 'dart:io';

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

  Future<Directory> _dir() async {
    final base = await _baseDir();
    final dir = Directory(p.join(base.path, _folder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
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
    return dest;
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
