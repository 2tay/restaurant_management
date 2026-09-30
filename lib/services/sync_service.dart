import 'dart:async';

import 'package:clock/clock.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/database/meta_keys.dart';
import '../data/device_access.dart';
import '../data/providers.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/outbox_repository.dart';
import 'auth_service.dart';

/// Sending the outbox to the server (SYNC_PLAN.md, Phase 5).
///
/// Two layers:
///
/// - [SyncRunner] does one pass: it sends the queue in batches, oldest first,
///   and handles every answer. No timers, so it is tested directly.
/// - [SyncController] decides when a pass runs — a few seconds after a local
///   change, when the app comes back, when the network returns, every few
///   minutes, and on the sync page's button — and holds the [SyncState] the
///   screens show. It only runs on a device signed in to a restaurant
///   account; in the demo it does nothing.
///
/// Receiving the other devices' changes is Phase 6.

/// How one pass ended.
enum SyncOutcome {
  /// The queue is empty, or holds only rows changed during the pass.
  done,

  /// The server could not be reached. Nothing was lost; try again later.
  offline,

  /// The account's session ended: someone must sign in again.
  sessionExpired,

  /// The owner removed this device from the restaurant.
  deviceRemoved,

  /// Anything else the server said no to as a whole.
  failed,
}

class SyncRunResult {
  const SyncRunResult(
    this.outcome, {
    this.accepted = 0,
    this.rejected = 0,
    this.detail,
  });

  final SyncOutcome outcome;
  final int accepted;
  final int rejected;
  final String? detail;
}

/// One pass over the outbox.
class SyncRunner {
  SyncRunner({required AppDatabase db, required AccountBackend backend})
    : _db = db,
      _backend = backend;

  final AppDatabase _db;
  final AccountBackend _backend;

  /// Entries per call. The server accepts up to 500.
  static const int batchSize = 100;

  /// A pass stops after this many batches, so a row edited faster than it
  /// can be sent cannot keep one pass going forever. The next pass picks up.
  static const int maxBatches = 50;

  Future<SyncRunResult> run() async {
    final outbox = OutboxRepository(_db);
    final deviceId = await DeviceRepository(_db).deviceId();
    var accepted = 0;
    var rejected = 0;

    for (var batch = 0; batch < maxBatches; batch++) {
      final entries = await outbox.pending(limit: batchSize);
      if (entries.isEmpty) break;

      final List<PushResult> answers;
      try {
        answers = await _backend.pushChanges(deviceId, [
          for (final entry in entries) _asChange(entry),
        ]);
      } on AccountException catch (error) {
        await outbox.recordFailure(entries, error.toString());
        return SyncRunResult(
          switch (error.code) {
            AccountErrorCode.network => SyncOutcome.offline,
            AccountErrorCode.sessionExpired => SyncOutcome.sessionExpired,
            _ => SyncOutcome.failed,
          },
          accepted: accepted,
          rejected: rejected,
          detail: error.detail,
        );
      }

      final byId = {for (final entry in entries) entry.id: entry};
      var progressed = false;
      for (final answer in answers) {
        final entry = byId[answer.id];
        if (entry == null) continue;
        if (answer.accepted) {
          accepted++;
          if (await outbox.removeIfUnchanged(entry)) progressed = true;
        } else if (answer.reason == 'device_unknown') {
          return SyncRunResult(
            SyncOutcome.deviceRemoved,
            accepted: accepted,
            rejected: rejected,
          );
        } else {
          rejected++;
          await outbox.reject(
            entry,
            reason: answer.reason ?? 'invalid',
            message: answer.message,
          );
          progressed = true;
        }
      }

      // Every entry was edited while it travelled: their newer versions are
      // queued, and the next pass sends them. Stop instead of spinning.
      if (!progressed) break;
    }

    return SyncRunResult(
      SyncOutcome.done,
      accepted: accepted,
      rejected: rejected,
    );
  }

  static Map<String, Object?> _asChange(OutboxRow entry) => {
    'id': entry.id,
    'table': entry.changedTable,
    'row_key': entry.rowKey,
    'store_id': entry.storeId,
    'payload': entry.payload,
  };
}

enum SyncStatus {
  /// Not an account device (the demo, or nothing set up): nothing syncs.
  disabled,
  idle,
  syncing,
  offline,

  /// Stopped until someone acts: see [SyncState.problem].
  error,
}

class SyncState {
  const SyncState({required this.status, this.lastSyncAt, this.problem});

  static const SyncState disabled = SyncState(status: SyncStatus.disabled);

  final SyncStatus status;

  /// When the outbox was last emptied into the server.
  final DateTime? lastSyncAt;

  /// Why syncing stopped, when [status] is [SyncStatus.error].
  final SyncOutcome? problem;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncAt,
    SyncOutcome? problem,
  }) => SyncState(
    status: status ?? this.status,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    problem: problem,
  );
}

/// Whether the device has a network, as it changes. Overridden in tests.
final Provider<Stream<bool>> networkChangesProvider = Provider<Stream<bool>>(
  (ref) => Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  ),
);

/// When passes run, and the state the sync page shows.
class SyncController extends Notifier<SyncState> {
  /// How long after a local change the queue is sent. Short enough to feel
  /// immediate, long enough that a delivery of ten lines goes in one call.
  static const Duration changeDelay = Duration(seconds: 3);

  /// A safety net: a pass this often while the app is open.
  static const Duration period = Duration(minutes: 5);

  /// Waits after consecutive failures: 5 s, 15 s, 1 min, then 5 min.
  static const List<Duration> retryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];

  Timer? _scheduled;
  Timer? _periodic;
  StreamSubscription<int>? _pending;
  StreamSubscription<bool>? _network;
  AppLifecycleListener? _lifecycle;
  Future<SyncRunResult>? _running;
  int _failures = 0;
  int _lastPending = 0;
  bool _active = false;

  @override
  SyncState build() {
    ref.onDispose(_stop);
    ref.listen<DeviceAccess>(
      deviceAccessProvider,
      (_, access) => _configure(access),
    );
    // After build returns, so `state` exists when it is read.
    scheduleMicrotask(() => _configure(ref.read(deviceAccessProvider)));
    return SyncState.disabled;
  }

  AppDatabase get _db => ref.read(databaseProvider);

  void _configure(DeviceAccess access) {
    if (access.isAccount) {
      _start();
    } else {
      _stop();
      state = SyncState.disabled;
    }
  }

  void _start() {
    if (_active) return;
    _active = true;
    state = const SyncState(status: SyncStatus.idle);
    _loadLastSync();

    _pending = OutboxRepository(_db).watchPendingCount().listen((count) {
      if (count > _lastPending) schedule(changeDelay);
      _lastPending = count;
    });
    _periodic = Timer.periodic(period, (_) => schedule(Duration.zero));
    try {
      _network = ref.read(networkChangesProvider).listen((online) {
        if (online) schedule(Duration.zero);
      }, onError: (Object _) {});
    } catch (_) {
      // No connectivity plugin (a test): passes still run on the other
      // triggers.
    }
    try {
      _lifecycle = AppLifecycleListener(
        onResume: () => schedule(Duration.zero),
      );
    } catch (_) {
      // No Flutter binding (a plain unit test).
    }
    schedule(Duration.zero);
  }

  void _stop() {
    _active = false;
    _scheduled?.cancel();
    _periodic?.cancel();
    _pending?.cancel();
    _network?.cancel();
    _lifecycle?.dispose();
    _scheduled = null;
    _periodic = null;
    _pending = null;
    _network = null;
    _lifecycle = null;
    _lastPending = 0;
  }

  /// Runs a pass after [delay], replacing any pass already scheduled.
  void schedule(Duration delay) {
    if (!_active) return;
    _scheduled?.cancel();
    _scheduled = Timer(delay, () {
      _scheduled = null;
      syncNow();
    });
  }

  /// Runs a pass now, or joins the one already running. The sync page's
  /// button calls this.
  Future<SyncRunResult> syncNow() {
    final running = _running;
    if (running != null) return running;
    if (!ref.read(deviceAccessProvider).isAccount) {
      return Future.value(const SyncRunResult(SyncOutcome.done));
    }
    return _running = _pass().whenComplete(() => _running = null);
  }

  Future<SyncRunResult> _pass() async {
    state = state.copyWith(status: SyncStatus.syncing);
    final result = await SyncRunner(
      db: _db,
      backend: ref.read(accountBackendProvider),
    ).run();
    if (!ref.mounted) return result;

    switch (result.outcome) {
      case SyncOutcome.done:
        _failures = 0;
        final now = clock.now();
        await _saveLastSync(now);
        state = SyncState(status: SyncStatus.idle, lastSyncAt: now);
        // Rows edited during the pass are still queued.
        if (await OutboxRepository(_db).pendingCount() > 0) {
          schedule(changeDelay);
        }
      case SyncOutcome.offline:
      case SyncOutcome.failed:
        _failures++;
        state = state.copyWith(
          status: result.outcome == SyncOutcome.offline
              ? SyncStatus.offline
              : SyncStatus.error,
          problem: result.outcome == SyncOutcome.offline
              ? null
              : result.outcome,
        );
        final index = (_failures - 1).clamp(0, retryDelays.length - 1);
        schedule(retryDelays[index]);
      case SyncOutcome.sessionExpired:
      case SyncOutcome.deviceRemoved:
        // Retrying cannot fix these; someone has to act.
        state = state.copyWith(
          status: SyncStatus.error,
          problem: result.outcome,
        );
    }
    return result;
  }

  Future<void> _loadLastSync() async {
    final row = await (_db.select(
      _db.meta,
    )..where((m) => m.key.equals(MetaKeys.lastSyncAt))).getSingleOrNull();
    final at = row == null ? null : DateTime.tryParse(row.value)?.toLocal();
    if (at != null && ref.mounted && state.lastSyncAt == null) {
      state = state.copyWith(lastSyncAt: at, problem: state.problem);
    }
  }

  Future<void> _saveLastSync(DateTime at) => _db
      .into(_db.meta)
      .insertOnConflictUpdate(
        MetaCompanion.insert(
          key: MetaKeys.lastSyncAt,
          value: at.toUtc().toIso8601String(),
        ),
      );
}

final NotifierProvider<SyncController, SyncState> syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);
