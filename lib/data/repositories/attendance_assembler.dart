import 'package:drift/drift.dart';

import '../../models/attendance.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';

/// Rebuilds `Attendance` objects for a set of rows, in the same order,
/// attaching each one's sessions and each session's pauses. Two extra
/// queries total, not one per row.
///
/// Shared by `AttendanceRepository` and `PayrollRepository`, which each kept
/// an identical copy — a fix made to one would have been missed in the other.
Future<List<Attendance>> assembleAttendances(
  AppDatabase db,
  List<AttendanceRow> rows,
) async {
  if (rows.isEmpty) return const <Attendance>[];

  final ids = rows.map((r) => r.id).toList();
  final sessionRows =
      await (db.select(db.attendanceSessions)
            ..where((s) => s.attendanceId.isIn(ids) & s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm(expression: s.position)]))
          .get();

  final sessionIds = sessionRows.map((s) => s.id).toList();
  final pauseRows = sessionIds.isEmpty
      ? const <AttendancePauseRow>[]
      : await (db.select(
          db.attendancePauses,
        )..where((p) => p.sessionId.isIn(sessionIds) & p.deletedAt.isNull())).get();

  final pausesBySession = <String, List<AttendancePauseRow>>{};
  for (final pause in pauseRows) {
    (pausesBySession[pause.sessionId] ??= <AttendancePauseRow>[]).add(pause);
  }

  final sessionsByAttendance = <String, List<AttendanceSession>>{};
  for (final row in sessionRows) {
    (sessionsByAttendance[row.attendanceId] ??= <AttendanceSession>[]).add(
      attendanceSessionFromRow(row, pausesBySession[row.id] ?? const []),
    );
  }

  return [
    for (final row in rows)
      attendanceFromRows(row, sessionsByAttendance[row.id] ?? const []),
  ];
}
