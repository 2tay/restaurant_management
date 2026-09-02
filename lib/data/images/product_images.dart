import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../repositories/new_id.dart';

/// Where product photos live, and the only thing that puts them there.
///
/// The database stores a **file name**, never a path — see the column note on
/// `Items.imagePath`. This resolves that name against the app's own support
/// directory, so a photo survives a reinstall moving the container, and a
/// database opened on another machine asks for files rather than for somebody
/// else's `C:\Users\...`.
///
/// The picked file is **copied**, not referenced. A cook who photographs a
/// crate of tomatoes and then tidies up their downloads folder should not
/// discover that the catalogue has gone blank; once the product is saved, the
/// app owns its copy.
///
/// Everything here is best-effort on the filesystem side. A missing directory,
/// a file that will not delete, a card pulled mid-write: none of it is worth
/// failing a save for, because the photo is decoration and the product is the
/// record. The database stays the source of truth, and a name pointing at a
/// file that is gone renders as "no photo".
abstract final class ProductImages {
  static const String _folder = 'product_images';

  /// Overridden by the tests, which have no platform channels and no business
  /// writing into the real application-support directory.
  static Directory? directoryOverride;

  /// The directory photos live in, created if it is not there yet.
  static Future<Directory> directory() async {
    final override = directoryOverride;
    final base = override ?? await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, _folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// The file a stored [name] refers to, or null when there is no photo.
  ///
  /// Does **not** check that the file exists. The caller is a widget deciding
  /// what to draw, and `Image.file` has to handle a missing file anyway — a
  /// second `exists()` per frame would buy nothing but I/O.
  static Future<File?> fileFor(String? name) async {
    if (name == null || name.isEmpty) return null;
    return File(p.join((await directory()).path, name));
  }

  /// Copies [source] in and returns the name to store, or null if it could not
  /// be copied.
  ///
  /// The name is a fresh id plus the original extension, rather than the
  /// original file name: two products photographed as `IMG_0042.jpg` must not
  /// land on each other, and a name the user chose is not a name this
  /// directory has to honour.
  static Future<String?> save(File source) async {
    try {
      final extension = p.extension(source.path).toLowerCase();
      final name = '${newId()}${extension.isEmpty ? '.jpg' : extension}';
      await source.copy(p.join((await directory()).path, name));
      return name;
    } on FileSystemException {
      return null;
    }
  }

  /// Removes a stored photo. Silent when it is already gone.
  ///
  /// Called when a product's photo is replaced or cleared, and when the
  /// product itself is deleted — an image directory that only ever grows is a
  /// disk leak nobody notices until it matters.
  static Future<void> delete(String? name) async {
    if (name == null || name.isEmpty) return;
    try {
      final file = await fileFor(name);
      if (file != null && await file.exists()) await file.delete();
    } on FileSystemException {
      // Best-effort: an orphaned file costs disk space, and a failed delete is
      // not a reason to refuse the edit the user actually asked for.
    }
  }
}
