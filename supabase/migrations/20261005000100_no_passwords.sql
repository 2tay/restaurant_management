-- No more login password (app schema v22).
--
-- A Gérant signs in on the tablet with their email and their PIN (the CIN),
-- both already on `employees`. The password table stops syncing and goes:
-- it leaves `private.sync_tables`, so an older app still sending one is told
-- `unknown_table`; `pull_changes` is redefined without it (as in
-- 20261003000100_personnel_audit.sql, minus that branch); then the table is
-- dropped, with its triggers, index and policy.

delete from private.sync_tables where name = 'employee_credentials';

-- Everything in one store that changed after `p_after`, oldest first, at
-- most `p_limit` rows. The caller saves `next_after` and asks again while
-- `has_more` is true. Deleted rows come back too (with `deleted_at` set):
-- that is how a device learns about a delete.
create or replace function public.pull_changes(
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
    select server_seq, 'stores'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' - 'organization_id' as row
      from public.stores t
     where id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'categories'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.categories t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'units'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.units t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'items'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.items t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'suppliers'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.suppliers t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'supplier_prices'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.supplier_prices t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'price_history'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.price_history t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'stock_movements'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.stock_movements t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'purchase_orders'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.purchase_orders t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'purchase_order_lines'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.purchase_order_lines t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'goods_receipts'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.goods_receipts t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'goods_receipt_lines'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.goods_receipt_lines t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'notifications'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.notifications t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'employees'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.employees t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'payroll_periods'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.payroll_periods t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'attendances'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.attendances t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'attendance_sessions'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.attendance_sessions t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'attendance_pauses'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.attendance_pauses t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'busy_dates'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.busy_dates t
     where store_id = p_store_id and server_seq > p_after
    union all
    select server_seq, 'business_days'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.business_days t
     where store_id = p_store_id and server_seq > p_after
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

drop table public.employee_credentials;
