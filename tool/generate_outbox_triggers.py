"""Writes lib/data/database/outbox_triggers.drift (SYNC_PLAN.md, Phase 2).

Two triggers per synced table, one on insert and one on update, each copying
the row as it now is into `outbox`. The column lists come from the newest
drift schema dump, so the SQL is never typed by hand and cannot miss a column.

Run it after any schema change to a synced table, in this order:

    dart run drift_dev schema dump lib/data/database/app_database.dart lib/data/database/migrations/
    python tool/generate_outbox_triggers.py
    dart run build_runner build --force-jit

`test/db/outbox_test.dart` fails if the triggers and the tables disagree.
"""

import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
MIGRATIONS = ROOT / 'lib/data/database/migrations'
SYNC_TABLES = ROOT / 'lib/data/database/sync_tables.dart'
OUT = ROOT / 'lib/data/database/outbox_triggers.drift'

# Figures every device recomputes from the movement log (`StockLedger`).
# Sending them would only let one device's arithmetic overwrite another's.
EXCLUDED = {
    'items': {'quantity', 'average_cost'},
}

# Tables whose updates send only the columns that changed
# (SYNC_PERSONNEL_PLAN.md, step 4): the personnel, and the notifications that
# carry its signalements. Every other table sends the whole row.
PARTIAL = {
    'employees',
    'payroll_periods',
    'attendances',
    'attendance_sessions',
    'attendance_pauses',
    'business_days',
    'notifications',
}

# Columns whose value before the edit travels too (`outbox.base_values`), so
# the server can tell when this edit overwrites another tablet's unseen one
# (rule E2). Only in PARTIAL tables.
WATCHED = {
    'employees': ['pay', 'role', 'archived_at'],
}

# The key and the establishment of a row, as SQL over the row's own columns.
ROW_KEY = {'busy_dates': "store_id || '|' || day"}
STORE = {'stores': 'id'}

QUIET_KEY = 'syncQuiet'  # MetaKeys.syncQuiet


def synced_tables():
    text = SYNC_TABLES.read_text(encoding='utf-8')
    block = re.search(r'synced = \{(.*?)\};', text, re.S).group(1)
    return re.findall(r"'([a-z_]+)'", block)


def newest_dump():
    dumps = sorted(
        MIGRATIONS.glob('drift_schema_v*.json'),
        key=lambda p: int(re.search(r'v(\d+)', p.name).group(1)),
    )
    return json.loads(dumps[-1].read_text(encoding='utf-8')), dumps[-1].name


def columns_by_table(dump):
    result = {}
    for entity in dump['entities']:
        if entity['type'] == 'table':
            data = entity['data']
            result[data['name']] = [c['name'] for c in data['columns']]
    return result


def changed_list(sent):
    """SQL for the JSON array of the columns this UPDATE changed."""
    picks = '\n        UNION ALL '.join(
        f"SELECT '{c}' AS c WHERE NEW.{c} IS NOT OLD.{c}" for c in sent
    )
    return f"""(SELECT json_group_array(c) FROM (
        {picks}))"""


def base_values(table):
    """SQL for the JSON object of the watched columns' values before this
    UPDATE, for those it changed; NULL when the table watches none."""
    watched = WATCHED.get(table)
    if not watched:
        return 'NULL'
    picks = '\n        UNION ALL '.join(
        f"SELECT '{c}' AS c, OLD.{c} AS v WHERE NEW.{c} IS NOT OLD.{c}"
        for c in watched
    )
    return f"""(SELECT CASE WHEN count(*) = 0 THEN NULL
          ELSE json_group_object(c, v) END FROM (
        {picks}))"""


def trigger(table, event, columns):
    sent = [c for c in columns if c not in EXCLUDED.get(table, set())]
    pairs = ',\n      '.join(f"'{c}', {c}" for c in sent)
    key = ROW_KEY.get(table, 'id')
    store = STORE.get(table, 'store_id')
    partial = event == 'update' and table in PARTIAL
    changed = changed_list(sent) if partial else 'NULL'
    # A pending new row stays whole; two partial edits add up.
    merged = (
        """CASE
      WHEN outbox.changed_columns IS NULL
        OR excluded.changed_columns IS NULL THEN NULL
      ELSE (SELECT json_group_array(value) FROM (
        SELECT value FROM json_each(outbox.changed_columns)
        UNION SELECT value FROM json_each(excluded.changed_columns)))
    END"""
        if partial
        else 'NULL'
    )
    base = base_values(table) if partial else 'NULL'
    # The value before the *first* pending edit is kept.
    base_merged = (
        """CASE
      WHEN outbox.base_values IS NULL THEN excluded.base_values
      WHEN excluded.base_values IS NULL THEN outbox.base_values
      ELSE (SELECT json_group_object("key", value) FROM (
        SELECT "key", value FROM json_each(outbox.base_values)
        UNION ALL SELECT "key", value FROM json_each(excluded.base_values)
          WHERE "key" NOT IN (
            SELECT "key" FROM json_each(outbox.base_values))))
    END"""
        if partial and table in WATCHED
        else 'NULL'
    )
    return f"""CREATE TRIGGER {table}_outbox_{event} AFTER {event.upper()} ON {table}
  WHEN NOT EXISTS (SELECT 1 FROM meta WHERE "key" = '{QUIET_KEY}')
BEGIN
  INSERT INTO outbox (changed_table, row_key, store_id, payload,
    changed_columns, base_values, queued_at)
  SELECT '{table}', {key}, {store}, json_object(
      {pairs}
    ), {changed}, {base}, (SELECT now FROM sync_clock)
  FROM {table} WHERE rowid = NEW.rowid
  ON CONFLICT (changed_table, row_key) DO UPDATE SET
    store_id = excluded.store_id,
    payload = excluded.payload,
    changed_columns = {merged},
    base_values = {base_merged},
    queued_at = excluded.queued_at,
    attempts = 0,
    last_error = NULL;
END;
"""


def main():
    dump, dump_name = newest_dump()
    columns = columns_by_table(dump)
    parts = [
        '-- GENERATED by tool/generate_outbox_triggers.py from '
        f'migrations/{dump_name}. Do not edit by hand.',
        '--',
        '-- Queues every change to a synced table (SYNC_PLAN.md, Phase 2). Each',
        '-- trigger reads the row back from its table rather than from NEW, so the',
        '-- entry always holds the row as it is at the end, whichever order SQLite',
        '-- runs this and the `*_touch` trigger in.',
        '--',
        f"-- Silent while `meta` holds the '{QUIET_KEY}' key: see `SyncQuiet`.",
        '',
        "import 'sync_triggers.drift';",
        "import 'tables/outbox.dart';",
        *[
            f"import 'tables/{f.name}';"
            for f in sorted((ROOT / 'lib/data/database/tables').glob('*.dart'))
            if f.name not in ('outbox.dart', 'sync_columns.dart')
        ],
        '',
    ]
    for table in synced_tables():
        if table not in columns:
            raise SystemExit(f'{table} is in sync_tables.dart but not in {dump_name}')
        for event in ('insert', 'update'):
            parts.append(trigger(table, event, columns[table]))
    OUT.write_text('\n'.join(parts), encoding='utf-8', newline='\n')
    print(f'wrote {OUT.relative_to(ROOT)} from {dump_name}')


if __name__ == '__main__':
    main()
