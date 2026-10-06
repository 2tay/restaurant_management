-- A signalement is read per person (app schema v23).
--
-- `notification_reads`: one row per person who read one signalement, so one
-- manager reading it no longer hides it from another, nor from the owner.
-- Rows are only ever added, and the id is derived from the notification and
-- the person, so the same read sent by two tablets is one row. Mirrored like
-- every synced table, and `pull_changes` redefined to return it (as in
-- 20261005000100_no_passwords.sql, plus that branch).
--
-- `notifications.read_by_manager_at` / `read_by_owner_at` stay: a
-- signalement read by a role before this version still counts as read for
-- that role. Nothing writes them any more.

create table public.notification_reads (
  updated_at timestamptz not null,
  deleted_at timestamptz,
  id text not null,
  store_id text not null references public.stores (id),
  notification_id text not null,
  employee_id text not null,
  read_at timestamptz not null,
  server_seq bigint not null,
  updated_by_device text,
  primary key (id)
);
create index notification_reads_pull on public.notification_reads (store_id, server_seq);
create trigger notification_reads_seq before insert or update on public.notification_reads
  for each row execute function private.stamp_server_seq();
create trigger notification_reads_store_change after insert or update on public.notification_reads
  for each row execute function private.note_store_change('store_id');
alter table public.notification_reads enable row level security;
create policy notification_reads_read on public.notification_reads for select to authenticated
  using (private.can_access_store(store_id));
revoke insert, update, delete, truncate on public.notification_reads
  from anon, authenticated;
revoke all on public.notification_reads from anon;
insert into private.sync_tables (name, key_columns, store_column)
  values ('notification_reads', array['id'],
          'store_id');

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
    select server_seq, 'notification_reads'::text as tbl,
           to_jsonb(t) - 'server_seq' - 'updated_by_device' as row
      from public.notification_reads t
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
