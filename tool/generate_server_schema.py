"""Writes the server's mirror of the synced tables (SYNC_PLAN.md, Phase 3).

Output: supabase/migrations/20260929000200_sync_tables.sql, generated from the
newest drift schema dump so the server has exactly the app's columns:

- one table per synced table, same columns, same keys, plus `server_seq`
  (the growing change number devices pull by) and `updated_by_device`;
- the triggers that stamp `server_seq` and keep `store_changes` current;
- read-only row level security (writes only go through `push_changes`);
- `pull_changes`, which returns everything in a store after a change number.

Run after a schema change to a synced table, then add a new migration that
alters the server tables to match (never edit a migration already applied):

    python tool/generate_server_schema.py
"""

import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
MIGRATIONS = ROOT / 'lib/data/database/migrations'
SYNC_TABLES = ROOT / 'lib/data/database/sync_tables.dart'
OUT = ROOT / 'supabase/migrations/20260929000200_sync_tables.sql'

TYPES = {
    'string': 'text',
    'dateTime': 'timestamptz',
    'double': 'double precision',
    'int': 'bigint',
    'bool': 'boolean',
}

# Figures every device recomputes from its movement log; the server never
# holds them (they are not in the outbox payload either).
EXCLUDED = {'items': {'quantity', 'average_cost'}}


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


def tables_in(dump):
    return {
        e['data']['name']: e['data']
        for e in dump['entities']
        if e['type'] == 'table'
    }


def store_column(name):
    return 'id' if name == 'stores' else 'store_id'


def create_table(name, data):
    lines = []
    for column in data['columns']:
        if column['name'] in EXCLUDED.get(name, set()):
            continue
        sql_type = TYPES[column['moor_type']]
        null = '' if column['nullable'] else ' not null'
        ref = ''
        if column['name'] == 'store_id' and name != 'stores':
            ref = ' references public.stores (id)'
        lines.append(f'  {column["name"]} {sql_type}{null}{ref}')
    if name == 'stores':
        lines.append(
            '  organization_id uuid not null '
            'references public.organizations (id)'
        )
    lines.append('  server_seq bigint not null')
    lines.append('  updated_by_device text')
    keys = ', '.join(data['explicit_pk'])
    lines.append(f'  primary key ({keys})')
    body = ',\n'.join(lines)
    store = store_column(name)
    index_on = 'organization_id' if name == 'stores' else store
    return f"""create table public.{name} (
{body}
);
create index {name}_pull on public.{name} ({index_on}, server_seq);
create trigger {name}_seq before insert or update on public.{name}
  for each row execute function private.stamp_server_seq();
create trigger {name}_store_change after insert or update on public.{name}
  for each row execute function private.note_store_change('{store}');
alter table public.{name} enable row level security;
create policy {name}_read on public.{name} for select to authenticated
  using ({"organization_id = private.my_organization()" if name == 'stores'
          else f"private.can_access_store({store})"});
revoke insert, update, delete, truncate on public.{name}
  from anon, authenticated;
revoke all on public.{name} from anon;
insert into private.sync_tables (name, key_columns, store_column)
  values ('{name}', array[{', '.join(f"'{k}'" for k in data['explicit_pk'])}],
          '{store}');
"""


def pull_function(names):
    selects = []
    for name in names:
        store = store_column(name)
        strip = " - 'organization_id'" if name == 'stores' else ''
        selects.append(
            f"    select server_seq, '{name}'::text as tbl,\n"
            f"           to_jsonb(t) - 'server_seq' - 'updated_by_device'{strip}"
            f" as row\n"
            f"      from public.{name} t\n"
            f"     where {store} = p_store_id and server_seq > p_after"
        )
    union = '\n    union all\n'.join(selects)
    return f"""-- Everything in one store that changed after `p_after`, oldest first, at
-- most `p_limit` rows. The caller saves `next_after` and asks again while
-- `has_more` is true. Deleted rows come back too (with `deleted_at` set):
-- that is how a device learns about a delete.
create function public.pull_changes(
  p_store_id text,
  p_after bigint default 0,
  p_limit integer default 500
) returns jsonb
  language plpgsql stable security definer set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 500), 1), 1000);
  v_rows jsonb;
  v_count integer;
  v_last bigint;
begin
  if not private.can_access_store(p_store_id) then
    raise exception 'no access to store %', p_store_id using errcode = '42501';
  end if;

  with changes as (
{union}
  ), page as (
    select * from changes order by server_seq limit v_limit + 1
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'seq', server_seq, 'table', tbl, 'row', row) order by server_seq)
           filter (where rn <= v_limit), '[]'::jsonb),
         count(*),
         max(server_seq) filter (where rn <= v_limit)
    into v_rows, v_count, v_last
    from (select *, row_number() over (order by server_seq) as rn
            from page) numbered;

  return jsonb_build_object(
    'changes', v_rows,
    'next_after', coalesce(v_last, p_after),
    'has_more', v_count > v_limit
  );
end;
$$;

revoke execute on function public.pull_changes(text, bigint, integer)
  from anon, public;
grant execute on function public.pull_changes(text, bigint, integer)
  to authenticated;
"""


HEADER = """-- GENERATED by tool/generate_server_schema.py from {dump}.
-- Do not edit by hand; a later change is a new migration.
--
-- The server's copy of the app's synced tables (SYNC_PLAN.md, Phase 3,
-- steps 3.2, 3.3, 3.5 and 3.6).
--
-- - Same columns and keys as the app, minus the two stock figures every
--   device recomputes (`items.quantity`, `items.average_cost`).
-- - `server_seq` is stamped from one sequence on every insert and update.
--   A device remembers the last number it saw and pulls what came after.
-- - The only foreign key is to `stores`, which is what access hangs on. The
--   app guarantees the others, and on a server fed by several offline
--   devices a child can legitimately arrive before a later edit of its
--   parent (an attendance linked to a pay period queued afterwards).
-- - Clients can read (row level security) but not write: every write goes
--   through `push_changes`, so its rules cannot be bypassed.

create sequence private.sync_seq;

create function private.stamp_server_seq() returns trigger
  language plpgsql set search_path = ''
as $$
begin
  new.server_seq := nextval('private.sync_seq');
  return new;
end;
$$;

-- The newest change number per store. Devices listen to this one small table
-- (realtime) rather than to twenty, and pull when it moves.
create table public.store_changes (
  store_id text primary key,
  last_seq bigint not null
);
alter table public.store_changes enable row level security;
revoke insert, update, delete, truncate on public.store_changes
  from anon, authenticated;
revoke all on public.store_changes from anon;

create function private.note_store_change() returns trigger
  language plpgsql security definer set search_path = ''
as $$
declare
  v_store text := to_jsonb(new) ->> tg_argv[0];
begin
  insert into public.store_changes (store_id, last_seq)
    values (v_store, new.server_seq)
  on conflict (store_id) do update
    set last_seq = greatest(public.store_changes.last_seq, excluded.last_seq);
  return null;
end;
$$;

-- Which tables `push_changes` accepts, their keys, and where their store is.
create table private.sync_tables (
  name text primary key,
  key_columns text[] not null,
  store_column text not null
);

"""

ACCESS = """-- Whether the caller may see and change this store's data: the store belongs
-- to the caller's organization.
create function private.can_access_store(p_store_id text) returns boolean
  language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.stores s
     where s.id = p_store_id
       and s.organization_id = private.my_organization()
  )
$$;

create policy store_changes_read on public.store_changes
  for select to authenticated
  using (private.can_access_store(store_id));

alter publication supabase_realtime add table public.store_changes;

"""


def main():
    dump, dump_name = newest_dump()
    tables = tables_in(dump)
    names = synced_tables()
    if names[0] != 'stores':
        raise SystemExit('stores must come first: every table references it')

    parts = [HEADER.format(dump=f'lib/data/database/migrations/{dump_name}')]
    for name in names:
        if name not in tables:
            raise SystemExit(f'{name} is in sync_tables.dart but not in {dump_name}')
        parts.append(create_table(name, tables[name]))
        if name == 'stores':
            parts.append(ACCESS)
    parts.append(pull_function(names))
    OUT.write_text('\n'.join(parts), encoding='utf-8', newline='\n')
    print(f'wrote {OUT.relative_to(ROOT)} from {dump_name}')


if __name__ == '__main__':
    main()
