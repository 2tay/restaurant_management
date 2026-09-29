/// TODO: Phase 3 — an offline queue and conflict resolution.
///
/// Nothing here yet, and nothing pretending to be. What Phase 2 left it is a
/// clear starting point: every write already goes through one repository per
/// aggregate, in a transaction, against a local database that is the source of
/// truth. A queue records what those transactions did; it does not have to
/// invent where they happened.
///
/// The queue it will send already exists: the `outbox` table, filled by
/// triggers (SYNC_PLAN.md, Phase 2) and counted by `pendingChangesProvider` in
/// `shared/widgets/offline_banner.dart`.
class SyncService {}
