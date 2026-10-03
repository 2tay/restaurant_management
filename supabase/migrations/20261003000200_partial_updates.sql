-- Only the fields that changed (SYNC_PERSONNEL_PLAN.md, step 4, rules E2
-- and E3).
--
-- An edit of a personnel row (employees, credentials, pay periods,
-- pointages, journées, notifications) now carries `columns`: the names of
-- the columns it changed. On a row the server already has, only those (and
-- `updated_at`) are overwritten; every other column keeps the server's
-- value. Two tablets editing different fields of one employee both keep
-- their edit; two edits of the same field — the last to arrive wins.
--
-- An entry without `columns` (a new row, a whole-row table, an older app)
-- is applied as before: the whole row. Rule 8 of push_changes becomes
-- "the last change to arrive wins, for the columns it changed".
--
-- `private.apply_change` is redefined as in 20260929000300_push_changes.sql,
-- with the write at the end restricted to the named columns.

create or replace function private.apply_change(
  p_org uuid,
  p_role public.member_role,
  p_device_id text,
  p_change jsonb
) returns jsonb
  language plpgsql security definer set search_path = ''
as $$
declare
  v_id jsonb := p_change -> 'id';
  v_table text := p_change ->> 'table';
  v_payload jsonb;
  v_meta record;
  v_store text;
  v_where text;
  v_existing jsonb;
  v_existing_org uuid;
  v_columns text[];
  v_changed text[];
  v_updates text;
  v_sql text;
  v_seq bigint;
begin
  if jsonb_typeof(p_change -> 'payload') = 'string' then
    v_payload := (p_change ->> 'payload')::jsonb;
  else
    v_payload := p_change -> 'payload';
  end if;

  select * into v_meta from private.sync_tables where name = v_table;
  if not found or v_payload is null or jsonb_typeof(v_payload) <> 'object' then
    return jsonb_build_object('id', v_id, 'status', 'rejected',
      'reason', 'unknown_table');
  end if;

  v_store := v_payload ->> v_meta.store_column;

  -- The row as the server has it, if it has it.
  select string_agg(format('t.%I = $1 ->> %L', k, k), ' and ')
    into v_where from unnest(v_meta.key_columns) k;
  execute format('select to_jsonb(t) from public.%I t where %s',
                 v_table, v_where)
    into v_existing using v_payload;

  -- Access.
  if v_table = 'stores' then
    if p_role is distinct from 'owner' then
      return jsonb_build_object('id', v_id, 'status', 'rejected',
        'reason', 'owner_only');
    end if;
    v_existing_org := (v_existing ->> 'organization_id')::uuid;
    if v_existing is not null and v_existing_org <> p_org then
      return jsonb_build_object('id', v_id, 'status', 'rejected',
        'reason', 'no_access');
    end if;
  else
    if not private.can_access_store(v_store) then
      return jsonb_build_object('id', v_id, 'status', 'rejected',
        'reason', 'no_access');
    end if;
    if v_existing is not null
       and v_existing ->> v_meta.store_column is distinct from v_store then
      return jsonb_build_object('id', v_id, 'status', 'rejected',
        'reason', 'store_changed');
    end if;
  end if;

  -- Conflict rules.
  if v_existing is not null then
    if v_existing ->> 'deleted_at' is not null
       and v_payload ->> 'deleted_at' is null then
      return jsonb_build_object('id', v_id, 'status', 'rejected',
        'reason', 'deleted');
    end if;

    if v_table = 'purchase_orders'
       and v_payload ->> 'status' is distinct from v_existing ->> 'status' then
      if v_existing ->> 'status' in ('received', 'cancelled') then
        return jsonb_build_object('id', v_id, 'status', 'rejected',
          'reason', 'status_closed');
      end if;
      if private.order_status_rank(v_payload ->> 'status')
         < private.order_status_rank(v_existing ->> 'status') then
        return jsonb_build_object('id', v_id, 'status', 'rejected',
          'reason', 'status_backwards');
      end if;
    end if;

    -- A retry of the same payment (same status, same payer) is accepted, so
    -- a device that lost the first answer can send it again.
    if v_table = 'payroll_periods' and v_existing ->> 'status' = 'paid'
       and (v_payload ->> 'status' is distinct from 'paid'
            or v_payload ->> 'paid_by_employee_id'
               is distinct from v_existing ->> 'paid_by_employee_id') then
      return jsonb_build_object('id', v_id, 'status', 'rejected',
        'reason', 'already_paid');
    end if;
  end if;

  -- Write it: insert, or replace the row — only the columns the device
  -- changed, when it names them (and the server has the row).
  v_columns := private.writable_columns(v_table);
  if v_existing is not null
     and jsonb_typeof(p_change -> 'columns') = 'array' then
    v_changed := array(
      select jsonb_array_elements_text(p_change -> 'columns')
    ) || array['updated_at'];
  end if;
  select string_agg(format('%I = excluded.%I', c, c), ', ')
    into v_updates
    from unnest(v_columns) c
   where c <> all (v_meta.key_columns)
     and (v_changed is null or c = any (v_changed));

  v_sql := format(
    'insert into public.%1$I (%2$s, updated_by_device%3$s) '
    'select %4$s, $2%5$s from jsonb_populate_record(null::public.%1$I, $1) r '
    'on conflict (%6$s) do update set %7$s, '
    'updated_by_device = excluded.updated_by_device '
    'returning server_seq',
    v_table,
    (select string_agg(quote_ident(c), ', ') from unnest(v_columns) c),
    case when v_table = 'stores' then ', organization_id' else '' end,
    (select string_agg('r.' || quote_ident(c), ', ') from unnest(v_columns) c),
    case when v_table = 'stores' then ', $3' else '' end,
    (select string_agg(quote_ident(k), ', ') from unnest(v_meta.key_columns) k),
    v_updates
  );
  execute v_sql into v_seq using v_payload, p_device_id, p_org;

  return jsonb_build_object('id', v_id, 'status', 'accepted', 'seq', v_seq);
end;
$$;
