// A restaurant with several tablets on one fake server (SYNC_TESTS_PLAN.md,
// step 0.3).
//
// Each tablet is its own in-memory database with its own device id and its
// own link to the shared server, so one tablet can lose the Wi-Fi while the
// others carry on. `expectAllTheSame` is the check every scenario ends with:
// after syncing, every tablet must hold exactly the same business data.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/images/product_images.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/services/auth_service.dart';
import 'package:stock_inventory/services/photo_sync.dart';
import 'package:stock_inventory/services/sync_service.dart';

import 'db_fixture.dart';
import 'fake_account_backend.dart';

/// The business tables the restaurant scenarios compare: every synced table
/// except the staff ones, which `sync_personnel_full_test.dart` covers.
const List<String> comparedTables = [
  'stores',
  'categories',
  'units',
  'items',
  'suppliers',
  'supplier_prices',
  'price_history',
  'stock_movements',
  'purchase_orders',
  'purchase_order_lines',
  'goods_receipts',
  'goods_receipt_lines',
  'notifications',
  'busy_dates',
];

/// One tablet's connection to the shared server. While [offline], every
/// call fails the way a dead Wi-Fi does.
class TabletLink implements AccountBackend {
  TabletLink(this.server, this._db);

  /// The shared fake server, or a real one (test/integration).
  final AccountBackend server;
  final AppDatabase _db;
  bool offline = false;

  /// Runs once, after the server hands over a page and before the tablet
  /// writes it: a test uses it to have someone edit the tablet meanwhile.
  Future<void> Function()? duringPull;

  /// The fake server hands rows back as the device sent them, with SQLite's
  /// 0 and 1 for booleans; Postgres hands back `true` and `false`. Received
  /// rows get real booleans, as from the real server.
  Map<String, Object?> _asPostgres(String table, Map<String, Object?> row) {
    if (server is! FakeAccountBackend) return row;
    final columns = {
      for (final t in _db.allTables)
        if (t.actualTableName == table)
          for (final c in t.$columns)
            if (c.type == DriftSqlType.bool) c.name,
    };
    return {
      for (final MapEntry(:key, :value) in row.entries)
        key: columns.contains(key) && value is int ? value == 1 : value,
    };
  }

  void _reach() {
    if (offline) throw const AccountException(AccountErrorCode.network);
  }

  @override
  bool get isAvailable => true;

  @override
  AccountUser? get currentUser => server.currentUser;

  @override
  Future<AccountUser> signIn({
    required String email,
    required String password,
  }) async {
    _reach();
    return server.signIn(email: email, password: password);
  }

  @override
  Future<AccountUser> signUp({
    required String email,
    required String password,
  }) async {
    _reach();
    return server.signUp(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    _reach();
    return server.signOut();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    _reach();
    return server.sendPasswordReset(email);
  }

  @override
  Future<AccountSummary> myAccount() async {
    _reach();
    return server.myAccount();
  }

  @override
  Future<String> createOrganization(String name) async {
    _reach();
    return server.createOrganization(name);
  }

  @override
  Future<String> joinOrganization(String code) async {
    _reach();
    return server.joinOrganization(code);
  }

  @override
  Future<String> createJoinCode() async {
    _reach();
    return server.createJoinCode();
  }

  @override
  Future<void> registerDevice(String deviceId, {String name = ''}) async {
    _reach();
    return server.registerDevice(deviceId, name: name);
  }

  @override
  Future<List<DeviceInfo>> devices() async {
    _reach();
    return server.devices();
  }

  @override
  Future<bool> removeDevice(String deviceId) async {
    _reach();
    return server.removeDevice(deviceId);
  }

  @override
  Future<List<PushResult>> pushChanges(
    String deviceId,
    List<Map<String, Object?>> changes,
  ) async {
    _reach();
    return server.pushChanges(deviceId, changes);
  }

  @override
  Future<List<String>> storeIds() async {
    _reach();
    return server.storeIds();
  }

  @override
  Future<PullPage> pullChanges(
    String storeId, {
    required int after,
    int limit = 500,
  }) async {
    _reach();
    final page = await server.pullChanges(storeId, after: after, limit: limit);
    final hook = duringPull;
    duringPull = null;
    await hook?.call();
    return PullPage(
      changes: [
        for (final c in page.changes)
          PulledChange(
            seq: c.seq,
            table: c.table,
            row: _asPostgres(c.table, c.row),
          ),
      ],
      nextAfter: page.nextAfter,
      hasMore: page.hasMore,
    );
  }

  @override
  Stream<LiveSignal> storeChanges(List<String> storeIds) =>
      server.storeChanges(storeIds);

  @override
  Future<void> uploadPhoto(
    String path,
    Uint8List bytes, {
    required String contentType,
  }) async {
    _reach();
    return server.uploadPhoto(path, bytes, contentType: contentType);
  }

  @override
  Future<Uint8List?> downloadPhoto(String path) async {
    _reach();
    return server.downloadPhoto(path);
  }

  @override
  Future<void> removePhotos(List<String> paths) async {
    _reach();
    return server.removePhotos(paths);
  }
}

class Tablet {
  Tablet(this.name, this.db, this.link, [this.photos]);

  final String name;
  final AppDatabase db;
  final TabletLink link;

  /// This tablet's photo folders, when the restaurant was opened with photos.
  final FolderPhotoFiles? photos;

  void offline() => link.offline = true;
  void online() => link.offline = false;
  bool get isOffline => link.offline;

  /// One pass: send, then receive.
  Future<SyncRunResult> sync({int pageSize = 500}) => SyncRunner(
    db: db,
    backend: link,
    pageSize: pageSize,
    photoFiles: photos,
  ).run();

  Future<int> waiting() => OutboxRepository(db).pendingCount();

  /// What the sync page lists under « À vérifier ».
  Future<List<SyncErrorRow>> toCheck() => SyncErrorRepository(db).all();

  ItemRepository get items => ItemRepository(db);
  MovementRepository get movements => MovementRepository(db);
  OrderRepository get orders => OrderRepository(db);
  SupplierRepository get suppliers => SupplierRepository(db);
  CatalogRepository get catalog => CatalogRepository(db);
  StoreRepository get stores => StoreRepository(db);
  CalendarRepository get calendar => CalendarRepository(db);

  Future<double> stockOf(String itemId) async =>
      (await items.item(itemId))!.quantity;

  @override
  String toString() => name;
}

/// One restaurant: a fake server, its tablets, and the first day's data
/// made on the first tablet and shared with every one.
class Restaurant {
  Restaurant._(this.server, this.organization, this.photoRoot);

  final FakeAccountBackend server;
  final String organization;

  /// Where every tablet's photo folder lives, when opened with photos.
  final Directory? photoRoot;
  final Map<String, Tablet> tablets = {};

  late Store store;
  late Category legumes;
  late UnitOfMeasure kg;
  late Supplier metro;

  /// The products of the first day, by name: Tomates, Oignons, Saumon.
  final Map<String, Item> products = {};

  Tablet operator [](String name) => tablets[name]!;

  /// Opens the restaurant: the first tablet creates the establishment, a
  /// category, a unit, a supplier and three products with stock; then every
  /// tablet syncs, so all start from the same data.
  static Future<Restaurant> open({
    List<String> tablets = const ['Cuisine', 'Bar', 'Bureau'],
    bool photos = false,
  }) async {
    Directory? photoRoot;
    if (photos) {
      final root = await Directory.systemTemp.createTemp('restaurant_photos_');
      photoRoot = root;
      addTearDown(() => root.delete(recursive: true));
      // The app's own product folder, used when a replaced photo is deleted
      // locally; no platform folder in a unit test.
      ProductImages.directoryOverride = Directory(p.join(root.path, 'app'));
      addTearDown(() => ProductImages.directoryOverride = null);
    }
    final server = FakeAccountBackend();
    final organization = server.addOrganization('Brasserie');
    server.addUser(
      'owner@resto.be',
      'motdepasse',
      organizationId: organization,
    );
    await server.signIn(email: 'owner@resto.be', password: 'motdepasse');

    final restaurant = Restaurant._(server, organization, photoRoot);
    for (final name in tablets) {
      await restaurant.addTablet(name, sync: false);
    }

    final first = restaurant[tablets.first];
    restaurant.store = await first.stores.createStore(
      name: 'Brasserie',
      addressLine: '',
      postalCode: '',
      city: 'Namur',
      phone: '081',
    );
    final storeId = restaurant.store.id;
    restaurant.legumes = (await first.catalog.createCategory(
      storeId: storeId,
      name: 'Légumes',
    ))!;
    restaurant.kg = (await first.catalog.createUnit(
      storeId: storeId,
      name: 'Kilogramme',
      abbreviation: 'kg',
    ))!;
    restaurant.metro = await first.suppliers.create(
      storeId: storeId,
      name: 'Metro',
      contactName: 'Paul',
      email: 'metro@example.be',
      phone: '081 00 00 00',
      addressLine: '',
      postalCode: '',
      city: 'Namur',
    );
    for (final (name, quantity, cost) in [
      ('Tomates', 10.0, 2.0),
      ('Oignons', 20.0, 1.0),
      ('Saumon', 5.0, 20.0),
    ]) {
      restaurant.products[name] = (await first.items.create(
        storeId: storeId,
        name: name,
        categoryId: restaurant.legumes.id,
        unitId: restaurant.kg.id,
        lowStockThreshold: 3,
        quantity: quantity,
        openingUnitCost: cost,
      ))!;
    }
    await restaurant.syncAll();
    return restaurant;
  }

  /// A new tablet signed in to the restaurant, empty until it syncs.
  Future<Tablet> addTablet(String name, {bool sync = true}) async {
    final db = openEmptyDatabase();
    final link = TabletLink(server, db);
    await server.registerDevice(await DeviceRepository(db).deviceId());
    await DeviceAccessRepository(db).writeAccount(
      email: 'owner@resto.be',
      organizationId: organization,
      organizationName: 'Brasserie',
      role: 'owner',
    );
    final root = photoRoot;
    final tablet = Tablet(
      name,
      db,
      link,
      root == null
          ? null
          : FolderPhotoFiles(Directory(p.join(root.path, name))),
    );
    tablets[name] = tablet;
    if (sync) await syncAll();
    return tablet;
  }

  String get storeId => store.id;
  Item get tomates => products['Tomates']!;
  Item get oignons => products['Oignons']!;
  Item get saumon => products['Saumon']!;

  /// Passes on every online tablet, round after round, until a whole round
  /// sends and receives nothing. Fails if it never settles.
  Future<void> syncAll({int maxRounds = 6}) async {
    for (var round = 0; round < maxRounds; round++) {
      var moved = 0;
      for (final tablet in tablets.values) {
        if (tablet.isOffline) continue;
        final result = await tablet.sync();
        expect(
          result.outcome,
          SyncOutcome.done,
          reason: '${tablet.name}: ${result.detail}',
        );
        moved += result.accepted + result.rejected + result.received;
      }
      if (moved == 0) return;
    }
    fail('the tablets never stopped sending each other changes');
  }

  /// Every online tablet holds exactly the same business data, row for row,
  /// stock figures included.
  Future<void> expectAllTheSame({Set<String> skip = const {}}) async {
    final online = [
      for (final t in tablets.values)
        if (!t.isOffline) t,
    ];
    final reference = online.first;
    for (final table in comparedTables) {
      if (skip.contains(table)) continue;
      final expected = await tableRows(reference.db, table);
      for (final other in online.skip(1)) {
        final actual = await tableRows(other.db, table);
        expect(
          actual,
          expected,
          reason: '$table differs between ${reference.name} and ${other.name}',
        );
      }
    }
  }

  /// Nothing waits to be sent on any online tablet.
  Future<void> expectNothingWaiting() async {
    for (final tablet in tablets.values) {
      if (tablet.isOffline) continue;
      expect(await tablet.waiting(), 0, reason: '${tablet.name} still waits');
    }
  }

  /// The end of every scenario: sync until quiet, then all the same and
  /// nothing waiting.
  Future<void> settle({Set<String> skip = const {}}) async {
    await syncAll();
    await expectAllTheSame(skip: skip);
    await expectNothingWaiting();
  }
}

/// Columns left out of the comparison, each because of a known finding
/// (SYNC_TESTS.md) that has its own test. Without this, one known difference
/// would hide every other one.
///
/// - F1: a stock rebuild stamps `items.updated_at` only on the tablets whose
///   figures it changed.
const Map<String, Set<String>> knownDifferences = {
  'items': {'updated_at'},
};

/// Every row of [table], sorted, doubles rounded so a cost computed in
/// another order does not differ in its 15th digit.
///
/// F2: a deleted product's stock figures are not rebuilt, so they may differ
/// between tablets; nobody can see them, so they are left out.
Future<List<Map<String, Object?>>> tableRows(
  AppDatabase db,
  String table, {
  bool strict = false,
}) async {
  final rows = await db.customSelect('SELECT * FROM $table').get();
  final ignored = strict ? const <String>{} : knownDifferences[table] ?? {};
  final maps = [
    for (final row in rows)
      {
        for (final MapEntry(:key, :value) in row.data.entries)
          if (!ignored.contains(key) &&
              !(!strict &&
                  table == 'items' &&
                  row.data['deleted_at'] != null &&
                  (key == 'quantity' || key == 'average_cost')))
            key: value is double ? (value * 1e6).roundToDouble() / 1e6 : value,
      },
  ];
  maps.sort((a, b) => a.toString().compareTo(b.toString()));
  return maps;
}

/// The `skip` of a test that shows a known finding (SYNC_TESTS.md): skipped
/// in the normal run, so the suite stays green, and run with
/// `--dart-define=KNOWN_ISSUES=true` to see it still fail (or pass, once
/// fixed).
String? knownIssue(String finding) =>
    const bool.fromEnvironment('KNOWN_ISSUES') ? null : finding;
