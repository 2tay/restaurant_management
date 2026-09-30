// EmployeePhotoStore — the on-disk half of an employee photo. The base
// directory is injected so nothing here touches a platform channel.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stock_inventory/data/employee_photo_store.dart';

void main() {
  late Directory tmp;
  late Directory src;
  late EmployeePhotoStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('photo_store_');
    src = await Directory.systemTemp.createTemp('photo_src_');
    store = EmployeePhotoStore(baseDir: () async => tmp);
  });

  tearDown(() async {
    for (final dir in [tmp, src]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  Future<String> makeImage(String name) async {
    final file = File(p.join(src.path, name));
    await file.writeAsBytes([1, 2, 3]);
    return file.path;
  }

  // A bare file name since schema v20 (SYNC_PLAN.md, Phase 8): the row
  // syncs to other tablets, where this device's path would mean nothing.
  test('save copies the file under the employee id and returns its name',
      () async {
    final name = await store.save(
      employeeId: 'emp-1',
      sourcePath: await makeImage('a.png'),
    );

    expect(name, isNot(contains(p.separator)));
    expect((await store.fileFor(name)).existsSync(), isTrue);
    expect(name, startsWith('emp-1-'));
    expect(p.extension(name), '.png');
  });

  test('a second save replaces the first file', () async {
    final first = await store.save(
      employeeId: 'emp-1',
      sourcePath: await makeImage('a.png'),
    );
    final second = await store.save(
      employeeId: 'emp-1',
      sourcePath: await makeImage('b.jpg'),
    );

    expect(first, isNot(second));
    expect((await store.fileFor(first)).existsSync(), isFalse);
    expect((await store.fileFor(second)).existsSync(), isTrue);
  });

  test('deleteFor removes the stored photo', () async {
    final path = await store.save(
      employeeId: 'emp-1',
      sourcePath: await makeImage('a.png'),
    );

    await store.deleteFor('emp-1');
    expect((await store.fileFor(path)).existsSync(), isFalse);
  });

  test('deleteFor leaves other employees untouched', () async {
    final keep = await store.save(
      employeeId: 'emp-2',
      sourcePath: await makeImage('a.png'),
    );
    await store.save(employeeId: 'emp-1', sourcePath: await makeImage('b.png'));

    await store.deleteFor('emp-1');
    expect((await store.fileFor(keep)).existsSync(), isTrue);
  });

  test('deleteFor on an employee with no photo is a no-op', () async {
    await store.deleteFor('nobody');
  });
}
