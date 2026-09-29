-- Receiving changes from a device (SYNC_PLAN.md, Phase 3, step 3.4).
--
-- `push_changes` takes a batch of outbox entries, exactly as the app's
-- `outbox` table holds them, and applies them one by one. Each entry gets an
-- answer: accepted (with the change number it was given) or rejected (with a
-- reason code the app can show in words). One bad entry never blocks the
-- others: each runs in its own sub-transaction.
--
-- An entry looks like:
--
--   {"id": 12, "table": "items", "row_key": "item-1", "store_id": "store-1",
--    "payload": {...the whole row...}}
--
-- `payload` may be a JSON object or the JSON text the outbox stores.
--
-- Rules, in order:
--
--   1. The device must be registered to the caller's organization.
--   2. The table must be a synced one.
--   3. Access: the row's store belongs to the caller's organization. A store
--      row itself can only be created or changed by an owner.
--   4. A row cannot move to another store.
--   5. Delete wins: a row deleted on the server stays deleted. An edit made
--      offline to a row someone else deleted is rejected.
--   6. A commande's status only moves forward, and a closed one stays closed.
--   7. A paid pay period is final.
--   8. Otherwise the last change to arrive wins, for the whole row.
--
-- Reason codes: device_unknown, unknown_table, no_access, owner_only,
-- store_changed, deleted, status_backwards, status_closed, already_paid,
-- invalid (the row itself was refused, the message says why).

create function private.order_status_rank(p_status text) returns integer
  language sql immutable set search_path = ''
as $$
  select case p_status
    when 'draft' then 0
    when 'sent' then 1
    when 'partial' then 2
    when 'cancelled' then 2
    when 'received' then 3
  end
$$;

-- The columns a device may write in `p_table`: everything the app has, minus
-- what only the server keeps.
create function private.writable_columns(p_table text) returns text[]
  language sql stable set search_path = ''
as $$
  select array_agg(a.attname::text order by a.attnum)
    from pg_catalog.pg_attribute a
   where a.attrelid = ('public.' || quote_ident(p_table))::regclass
     and a.attnum > 0 and not a.attisdropped
     and a.attname not in ('server_seq', 'updated_by_device', 'organization_id')
$$;

create function private.apply_change(
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

  -- Write it: insert, or replace the whole row.
  v_columns := private.writable_columns(v_table);
  select string_agg(format('%I = excluded.%I', c, c), ', ')
    into v_updates
    from unnest(v_columns) c
   where c <> all (v_meta.key_columns);

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

create function public.push_changes(p_device_id text, p_changes jsonb)
  returns jsonb
  language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := private.my_organization();
  v_role public.member_role := private.my_role();
  v_change jsonb;
  v_result jsonb;
  v_results jsonb := '[]'::jsonb;
begin
  if v_org is null then
    raise exception 'not a member of an organization' using errcode = '42501';
  end if;
  if jsonb_typeof(p_changes) <> 'array' then
    raise exception 'changes must be a JSON array' using errcode = '22023';
  end if;
  if jsonb_array_length(p_changes) > 500 then
    raise exception 'at most 500 changes per call' using errcode = '54000';
  end if;

  update public.devices set last_seen_at = now()
   where id = p_device_id and organization_id = v_org;
  if not found then
    return (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', c -> 'id', 'status', 'rejected', 'reason', 'device_unknown')),
        '[]'::jsonb)
        from jsonb_array_elements(p_changes) c
    );
  end if;

  for v_change in select value from jsonb_array_elements(p_changes) loop
    begin
      v_result := private.apply_change(v_org, v_role, p_device_id, v_change);
    exception when others then
      -- The sub-transaction rolls back this entry's writes only.
      v_result := jsonb_build_object('id', v_change -> 'id',
        'status', 'rejected', 'reason', 'invalid', 'message', sqlerrm);
    end;
    v_results := v_results || jsonb_build_array(v_result);
  end loop;

  return v_results;
end;
$$;

revoke execute on function private.apply_change(uuid, public.member_role,
  text, jsonb) from public, anon, authenticated;
revoke execute on function public.push_changes(text, jsonb) from anon, public;
grant execute on function public.push_changes(text, jsonb) to authenticated;
