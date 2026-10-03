-- Employees across tablets (SYNC_PERSONNEL_PLAN.md, step 8, rules E1–E5).
--
-- - The retirement (`archived_at`) joins the watched columns: archived on
--   one tablet, restored on another — the last change wins, and the answer
--   names it in `overwrote` so the device signals it (rule E5), like a rate
--   or a role (rule E2).
-- - The watched values are now compared in the column's own type rather
--   than as JSON text, so a date written with the device's offset and the
--   same date as the server prints it are not taken for a change.
-- - Nothing here merges two records of one person (rule E1): the server
--   stays a mirror; every device merges them the same way as they arrive.
--
-- `private.apply_change` is redefined as in 20261003000400_paid_days.sql,
-- with that comparison.

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
  v_overwrote jsonb := '[]'::jsonb;
  v_named text[];
  v_compared text[];
  v_paid_day text;
  v_differs boolean;
  v_watch text;
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

  if jsonb_typeof(p_change -> 'columns') = 'array' then
    v_named := array(select jsonb_array_elements_text(p_change -> 'columns'));
  end if;

  -- PA1: a day another payment reached the server with first. It stays
  -- with that payment; the device puts it back (`restore`), with that
  -- payment's row so the day's link holds, and marks its own run a
  -- « paiement en double ».
  if v_table = 'attendances' and v_existing is not null
     and v_existing ->> 'payroll_period_id' is not null
     and v_payload ->> 'payroll_period_id' is not null
     and v_payload ->> 'payroll_period_id'
         is distinct from v_existing ->> 'payroll_period_id' then
    return jsonb_build_object('id', v_id, 'status', 'rejected',
      'reason', 'day_already_paid',
      'restore', jsonb_build_array(
        (select jsonb_build_object('table', 'payroll_periods',
                  'row', to_jsonb(p) - 'server_seq' - 'updated_by_device')
           from public.payroll_periods p
          where p.id = v_existing ->> 'payroll_period_id'),
        jsonb_build_object('table', 'attendances',
          'row', v_existing - 'server_seq' - 'updated_by_device')));
  end if;

  -- PA2: a paid day is frozen. Any change to it, its sessions or their
  -- breaks — or a session moved into it — is refused; the device puts the
  -- server's version back and signals the difference.
  v_paid_day := case v_table
    when 'attendances' then v_existing ->> 'payroll_period_id'
    when 'attendance_sessions' then (
      select max(a.payroll_period_id) from public.attendances a
       where a.id in (v_existing ->> 'attendance_id',
                      v_payload ->> 'attendance_id'))
    when 'attendance_pauses' then (
      select max(a.payroll_period_id)
        from public.attendance_sessions s
        join public.attendances a on a.id = s.attendance_id
       where s.id in (v_existing ->> 'session_id', v_payload ->> 'session_id'))
  end;
  if v_paid_day is not null then
    if v_existing is null then
      v_differs := true;
    else
      v_compared := array(
        select c from unnest(private.writable_columns(v_table)) c
         where c <> all (v_meta.key_columns)
           and c not in ('updated_at', 'payroll_period_id')
           and (v_named is null or c = any (v_named)));
      if cardinality(v_compared) = 0 then
        v_differs := false;
      else
        execute format(
          'select exists (select 1 from public.%1$I t, '
          'jsonb_populate_record(null::public.%1$I, $1) r where %2$s and (%3$s))',
          v_table, v_where,
          (select string_agg(format('r.%1$I is distinct from t.%1$I', c), ' or ')
             from unnest(v_compared) c))
          into v_differs using v_payload;
      end if;
    end if;
    if v_differs then
      return jsonb_build_object('id', v_id, 'status', 'rejected',
        'reason', 'paid_day_frozen',
        'restore', case
          when v_existing is null then '[]'::jsonb
          -- A day comes back with its payment, so its link holds.
          when v_table = 'attendances' then jsonb_build_array(
            (select jsonb_build_object('table', 'payroll_periods',
                      'row', to_jsonb(p) - 'server_seq' - 'updated_by_device')
               from public.payroll_periods p
              where p.id = v_existing ->> 'payroll_period_id'),
            jsonb_build_object('table', v_table,
              'row', v_existing - 'server_seq' - 'updated_by_device'))
          else jsonb_build_array(jsonb_build_object('table', v_table,
            'row', v_existing - 'server_seq' - 'updated_by_device')) end);
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

  -- A watched column (a password, a rate, a role) this edit replaces while
  -- the server holds another value than the one the device started from:
  -- another tablet changed it meanwhile. The edit still wins; the answer
  -- names the column so the device can signal it.
  -- Compared as the column's own type, not as JSON text: a date the device
  -- writes with its offset and the same date as the server prints it are
  -- one value (the retirement, rule E5).
  if v_existing is not null
     and jsonb_typeof(p_change -> 'base') = 'object' then
    select string_agg(format(
             'select %1$L::text as k where b.%1$I is distinct from t.%1$I '
             'and r.%1$I is distinct from t.%1$I', k), ' union all ')
      into v_watch
      from jsonb_object_keys(p_change -> 'base') k
     where k = any (private.writable_columns(v_table));
    if v_watch is not null then
      execute format(
        'select coalesce(jsonb_agg(x.k), ''[]''::jsonb) '
        'from public.%1$I t, '
        'jsonb_populate_record(null::public.%1$I, $1) r, '
        'jsonb_populate_record(null::public.%1$I, $2) b, '
        'lateral (%3$s) x where %2$s',
        v_table, v_where, v_watch)
        into v_overwrote using v_payload, p_change -> 'base';
    end if;
  end if;

  -- Write it: insert, or replace the row — only the columns the device
  -- changed, when it names them (and the server has the row).
  v_columns := private.writable_columns(v_table);
  if v_existing is not null and v_named is not null then
    v_changed := v_named || array['updated_at'];
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

  return jsonb_build_object('id', v_id, 'status', 'accepted', 'seq', v_seq,
    'overwrote', v_overwrote);
end;
$$;
