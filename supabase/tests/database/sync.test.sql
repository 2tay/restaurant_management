-- The sync server (SYNC_PLAN.md, Phase 3, step 3.8).
--
-- Run with `supabase test db` against the local stack. Everything happens in
-- one transaction that is rolled back at the end.
--
-- Three people: A owns "Resto A", B owns "Resto B", C is a manager at
-- "Resto A". Payloads are written the way the app's outbox writes them:
-- JSON text, local dates with a " +02:00" offset, UTC stamps ending in "Z",
-- booleans as 0 / 1.

begin;
create extension if not exists pgtap with schema extensions;
select plan(34);

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@example.be'),
  ('22222222-2222-2222-2222-222222222222', 'b@example.be'),
  ('33333333-3333-3333-3333-333333333333', 'c@example.be');

create schema tests;
grant usage on schema tests to authenticated;

-- One outbox entry, payload as JSON text like the app sends it.
create function tests.entry(p_id int, p_table text, p_payload jsonb)
  returns jsonb language sql immutable as $$
  select jsonb_build_object('id', p_id, 'table', p_table,
    'row_key', coalesce(p_payload ->> 'id',
                        (p_payload ->> 'store_id') || '|' || (p_payload ->> 'day')),
    'store_id', coalesce(p_payload ->> 'store_id', p_payload ->> 'id'),
    'payload', p_payload::text)
$$;

create function tests.store(p_id text) returns jsonb language sql immutable as $$
  select jsonb_build_object(
    'updated_at', '2026-09-29T08:00:00.000Z', 'deleted_at', null,
    'id', p_id, 'name', 'Resto ' || p_id, 'address_line', 'Rue 1',
    'postal_code', '1000', 'city', 'Bruxelles', 'phone', '02',
    'created_at', '2026-01-10T09:00:00.000 +01:00',
    'vat_number', null, 'image_asset', null,
    'stale_partial_order_days', 7, 'max_break_minutes', 30,
    'notify_low_stock', 1, 'notify_price_change', 1,
    'notify_large_adjustment', 1, 'notify_deliveries', 0,
    'notify_busy_days', 1, 'busy_weekdays', '5,6,7', 'busy_reminder_days', 1,
    'business_day_auto_open_minutes', 300,
    'notify_clock_in', 0, 'notify_clock_out', 0)
$$;

create function tests.category(p_id text, p_store text, p_name text,
  p_deleted text default null) returns jsonb language sql immutable as $$
  select jsonb_build_object('updated_at', '2026-09-29T08:00:00.000Z',
    'deleted_at', p_deleted, 'id', p_id, 'store_id', p_store, 'name', p_name)
$$;

create function tests.order_row(p_id text, p_store text, p_status text)
  returns jsonb language sql immutable as $$
  select jsonb_build_object('updated_at', '2026-09-29T08:00:00.000Z',
    'deleted_at', null, 'id', p_id, 'store_id', p_store,
    'supplier_id', 'sup-1', 'reference', 'CMD-' || p_id, 'status', p_status,
    'created_at', '2026-09-28T10:00:00.000 +02:00', 'sent_at', null,
    'closed_at', null, 'note', null)
$$;

create function tests.payroll(p_id text, p_store text, p_status text,
  p_paid_by text) returns jsonb language sql immutable as $$
  select jsonb_build_object('updated_at', '2026-09-29T08:00:00.000Z',
    'deleted_at', null, 'id', p_id, 'employee_id', 'emp-1',
    'store_id', p_store, 'start_date', '2026-09-01T00:00:00.000 +02:00',
    'end_date', '2026-09-30T00:00:00.000 +02:00', 'worked_days', 20,
    'total_worked_hours', 152.5, 'applied_rate', 15, 'computed_amount', 2287.5,
    'status', p_status, 'paid_by_employee_id', p_paid_by,
    'paid_at', case when p_status = 'paid'
                    then '2026-09-30T18:00:00.000 +02:00' end,
    'created_at', '2026-09-30T17:00:00.000 +02:00')
$$;

grant execute on all functions in schema tests to authenticated;

-- ---------------------------------------------------------------------------
-- Accounts
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to
  '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select isnt(public.create_organization('Resto A'), null,
  'A creates an organization');
select throws_ok($$ select public.create_organization('Encore') $$, '23505',
  null, 'one organization per person');
select lives_ok($$ select public.register_device('dev-a', 'Tablette cuisine') $$,
  'A registers a device');

set local request.jwt.claims to
  '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select isnt(public.create_organization('Resto B'), null,
  'B creates another organization');
select lives_ok($$ select public.register_device('dev-b') $$,
  'B registers a device');
select throws_ok($$ select public.register_device('dev-a') $$, '42501', null,
  'B cannot take over a device of A');
select is((select count(*)::int from public.organizations), 1,
  'B sees only its own organization');

-- C joins Resto A as a manager (the invitation flow is Phase 4).
reset role;
insert into public.members (user_id, organization_id, role)
  select '33333333-3333-3333-3333-333333333333', organization_id, 'manager'
    from public.members
   where user_id = '11111111-1111-1111-1111-111111111111';

-- ---------------------------------------------------------------------------
-- Pushing
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to
  '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

select is(
  public.push_changes('dev-a', jsonb_build_array(
    tests.entry(1, 'stores', tests.store('s-a')),
    tests.entry(2, 'categories', tests.category('c-1', 's-a', 'Légumes')),
    tests.entry(3, 'purchase_order_lines', jsonb_build_object(
      'updated_at', '2026-09-29T08:00:00.000Z', 'deleted_at', null,
      'id', 'l-1', 'store_id', 's-a', 'order_id', 'o-1', 'item_id', 'i-1',
      'quantity_ordered', 4, 'quantity_received', 0, 'unit_price', 2.5,
      'closed_short', 0, 'position', 0)),
    tests.entry(4, 'busy_dates', jsonb_build_object(
      'updated_at', '2026-09-29T08:00:00.000Z', 'deleted_at', null,
      'store_id', 's-a', 'day', '2026-12-24'))
  )) @? '$[*] ? (@.status != "accepted")',
  false,
  'an owner creates a store and its rows in one batch');

select is((select organization_id from public.stores where id = 's-a'),
  (select organization_id from public.members
    where user_id = '11111111-1111-1111-1111-111111111111'),
  'a new store joins the pusher''s organization');
select is((select created_at from public.stores where id = 's-a'),
  '2026-01-10T08:00:00Z'::timestamptz,
  'a local date with its offset is read as the right instant');
select is((select closed_short from public.purchase_order_lines where id = 'l-1'),
  false, 'a 0 from SQLite is read as false');
select is((select notify_low_stock from public.stores where id = 's-a'),
  true, 'a 1 from SQLite is read as true');
select is((select updated_by_device from public.categories where id = 'c-1'),
  'dev-a', 'the server records which device sent the change');

select is(
  public.push_changes('dev-a', jsonb_build_array(
    tests.entry(5, 'categories', tests.category('c-1', 's-a', 'Légumes frais'))
  )) -> 0 ->> 'status', 'accepted', 'the same row again is an update');
select is((select count(*)::int from public.categories where id = 'c-1'), 1,
  'still one row');
select is((select name from public.categories where id = 'c-1'),
  'Légumes frais', 'with the newer values');

select is(
  public.push_changes('dev-a', jsonb_build_array(
    tests.entry(6, 'categories', jsonb_build_object('id', 'c-bad',
      'store_id', 's-a')),
    tests.entry(7, 'categories', tests.category('c-2', 's-a', 'Viandes'))
  )) -> 0 ->> 'reason', 'invalid', 'a row missing required columns is refused');
select is((select count(*)::int from public.categories where id = 'c-2'), 1,
  'and the rest of the batch still lands');

select is(
  public.push_changes('dev-a', jsonb_build_array(
    tests.entry(8, 'meta', jsonb_build_object('id', 'x', 'store_id', 's-a'))
  )) -> 0 ->> 'reason', 'unknown_table', 'only synced tables are accepted');

select is(
  public.push_changes('dev-unknown', jsonb_build_array(
    tests.entry(9, 'categories', tests.category('c-3', 's-a', 'X'))
  )) -> 0 ->> 'reason', 'device_unknown', 'an unregistered device is refused');

select throws_ok($$ insert into public.categories (updated_at, id, store_id,
    name, server_seq) values (now(), 'c-9', 's-a', 'Direct', 1) $$,
  '42501', null, 'nobody writes a table directly, only through push_changes');

-- ---------------------------------------------------------------------------
-- Conflict rules
-- ---------------------------------------------------------------------------

select is(
  public.push_changes('dev-a', jsonb_build_array(
    tests.entry(10, 'categories',
      tests.category('c-2', 's-a', 'Viandes', '2026-09-29T09:00:00.000Z')),
    tests.entry(11, 'categories', tests.category('c-2', 's-a', 'Viandes bis'))
  )) -> 1 ->> 'reason', 'deleted', 'delete wins over a later edit');

select is(
  public.push_changes('dev-a', jsonb_build_array(
    tests.entry(12, 'purchase_orders', tests.order_row('o-1', 's-a', 'received')),
    tests.entry(13, 'purchase_orders', tests.order_row('o-1', 's-a', 'sent')),
    tests.entry(14, 'purchase_orders', tests.order_row('o-2', 's-a', 'partial')),
    tests.entry(15, 'purchase_orders', tests.order_row('o-2', 's-a', 'sent'))
  )) -> 1 ->> 'reason', 'status_closed', 'a received commande stays received');
select is((select status from public.purchase_orders where id = 'o-2'),
  'partial', 'a commande''s status never moves back');

select is(
  public.push_changes('dev-a', jsonb_build_array(
    tests.entry(16, 'payroll_periods',
      tests.payroll('p-1', 's-a', 'paid', 'emp-boss')),
    tests.entry(17, 'payroll_periods',
      tests.payroll('p-1', 's-a', 'paid', 'emp-boss')),
    tests.entry(18, 'payroll_periods',
      tests.payroll('p-1', 's-a', 'paid', 'emp-other'))
  )) #>> '{2,reason}', 'already_paid', 'a pay period is paid only once');

-- ---------------------------------------------------------------------------
-- Pulling
-- ---------------------------------------------------------------------------

select is(
  (public.pull_changes('s-a', 0) -> 'changes') @?
    '$[*] ? (@.table == "stores" && @.row.id == "s-a")',
  true, 'a pull from zero returns the store itself');
select is(
  (select count(*)::int from jsonb_array_elements(
     public.pull_changes('s-a', 0) -> 'changes') c
    where c ->> 'table' = 'categories' and c -> 'row' ->> 'id' = 'c-1'),
  1, 'a row changed twice comes back once, as it is now');
select is(
  public.pull_changes('s-a', (public.pull_changes('s-a', 0) ->> 'next_after')::bigint)
    -> 'changes', '[]'::jsonb, 'nothing after the last change number');
select is(public.pull_changes('s-a', 0, 1) ->> 'has_more', 'true',
  'a small page says there is more');
select is(
  (select last_seq from public.store_changes where store_id = 's-a'),
  (public.pull_changes('s-a', 0, 1000) ->> 'next_after')::bigint,
  'store_changes holds the newest change number, for realtime');

-- ---------------------------------------------------------------------------
-- Other people
-- ---------------------------------------------------------------------------

set local request.jwt.claims to
  '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select throws_ok($$ select public.pull_changes('s-a', 0) $$, '42501', null,
  'B cannot pull A''s store');
select is((select count(*)::int from public.categories), 0,
  'B sees none of A''s rows');
select is(
  public.push_changes('dev-b', jsonb_build_array(
    tests.entry(20, 'categories', tests.category('c-b', 's-a', 'Intrus'))
  )) -> 0 ->> 'reason', 'no_access', 'B cannot write into A''s store');

set local request.jwt.claims to
  '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select is(
  public.push_changes('dev-a', jsonb_build_array(
    tests.entry(21, 'stores', tests.store('s-a')),
    tests.entry(22, 'categories', tests.category('c-m', 's-a', 'Poissons'))
  )) -> 0 ->> 'reason', 'owner_only',
  'a manager cannot change a store, but works in it');

select * from finish();
rollback;
