// A double clock-in through a running Supabase (SYNC_PLAN.md, Phase 7).
//
// Two tablets of one restaurant clock the same employee in on the same day,
// both offline. The server keeps both days; each tablet, receiving the
// other's, merges them the same way. After a few rounds both tablets hold one
// day with both sessions, flagged for the manager.
//
//   supabase start
//   flutter test test/integration --dart-define-from-file=config/local.json

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock_inventory/core/config/env.dart';
import 'package:stock_inventory/core/utils/attendance_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/device_access.dart';
import 'package:stock_inventory/data/employee_photo_store.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/services/auth_service.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/db_fixture.dart';

void main() {
  final skip = Env.hasServer
      ? false
      : 'no server: run with --dart-define-from-file=config/local.json';

  Future<(AppDatabase, AccountBackend, DeviceAccessController)> tablet() async {
    final db = openEmptyDatabase();
    final backend = SupabaseAccountBackend(
      SupabaseClient(
        Env.supabaseUrl,
        Env.supabasePublishableKey,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        accountBackendProvider.overrideWithValue(backend),
        employeePhotoStoreProvider.overrideWithValue(_NoPhotos()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => seedDeviceAccessSnapshot(DeviceAccess.demo));
    final controller = container.read(deviceAccessProvider.notifier);
    await controller.hydrate();
    return (db, backend, controller);
  }

  test(
    'two tablets clocking one employee in end with one merged day',
    () async {
      final run = DateTime.now().microsecondsSinceEpoch;
      final (a, backendA, controllerA) = await tablet();
      await controllerA.signUp('owner-$run@example.test', 'motdepasse-local');
      final owner = await controllerA.createRestaurant(
        restaurantName: 'Resto $run',
        city: 'Namur',
        phone: '081',
        firstName: 'Léa',
        lastName: 'Martin',
        pin: 'PIN-$run',
      );
      await SyncRunner(db: a, backend: backendA).run();
      final code = await backendA.createJoinCode();

      final (b, backendB, controllerB) = await tablet();
      await controllerB.signUp('manager-$run@example.test', 'motdepasse-local');
      await controllerB.joinWithCode(code);
      await SyncRunner(db: b, backend: backendB).run();

      final morning = DateTime(2026, 10, 12, 8);
      await AttendanceRepository(
        a,
      ).clockIn(owner.id, owner.storeId, now: morning);
      await AttendanceRepository(b).clockIn(
        owner.id,
        owner.storeId,
        now: morning.add(const Duration(minutes: 2)),
      );

      for (var round = 0; round < 4; round++) {
        for (final (db, backend) in [(a, backendA), (b, backendB)]) {
          final result = await SyncRunner(db: db, backend: backend).run();
          expect(result.outcome, SyncOutcome.done, reason: result.detail);
        }
      }

      final onA = await AttendanceRepository(a).forEmployee(owner.id);
      final onB = await AttendanceRepository(b).forEmployee(owner.id);
      expect(onA, hasLength(1));
      expect(onB, hasLength(1));
      expect(onA.single.id, onB.single.id);
      expect(onA.single.sessions, hasLength(2));
      expect(onB.single.sessions, hasLength(2));
      expect(
        attendanceAnomalies(onB.single, maxBreakMinutes: 30, now: morning),
        contains(AttendanceAnomaly.doublePointage),
      );
      expect(await OutboxRepository(a).pendingCount(), 0);
      expect(await OutboxRepository(b).pendingCount(), 0);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _NoPhotos extends EmployeePhotoStore {
  @override
  Future<void> deleteFor(String employeeId) async {}
}
