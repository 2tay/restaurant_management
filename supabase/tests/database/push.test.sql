-- Phone push for the owner (PUSH_NOTIFICATIONS.md).
--
-- O owns "Resto A" and has a phone and a tablet. M is a manager there. The
-- tablet files notifications through push_changes, as a real one does; the
-- Edge Function's side is claim_pushes and forget_push_token.

begin;
create extension if not exists pgtap with schema extensions;
select plan(29);

insert into auth.users (id, email) values
  ('bbbbbbbb-0000-0000-0000-000000000001', 'owner@example.be'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'manager@example.be');

create schema tests;
grant usage on schema tests to authenticated, service_role;

create function tests.entry(p_id int, p_table text, p_payload jsonb)
  returns jsonb language sql immutable as $$
  select jsonb_build_object('id', p_id, 'table', p_table,
    'row_key', p_payload ->> 'id',
    'store_id', coalesce(p_payload ->> 'store_id', p_payload ->> 'id'),
    'payload', p_payload::text)
$$;

create function tests.note(p_id text, p_kind text, p_title text,
  p_created timestamptz default now()) returns jsonb language sql stable as $$
  select jsonb_build_object('updated_at', now(), 'deleted_at', null,
    'id', p_id, 'store_id', 'store-a', 'kind', p_kind, 'title', p_title,
    'body', 'Détail.', 'created_at', p_created, 'is_read', 0,
    'related_item_id', null, 'related_supplier_id', null,
    'related_employee_id', null, 'related_target', null,
    'read_by_manager_at', null, 'read_by_owner_at', null)
$$;

create function tests.file(p_entry_id int, p_note jsonb) returns text
  language sql as $$
  select public.push_changes('tablet-1',
    jsonb_build_array(tests.entry(p_entry_id, 'notifications', p_note)))
    -> 0 ->> 'status'
$$;

-- Counted as the test, not as the app: nobody else may read the queue.
create function tests.pending() returns bigint language sql
  security definer as $$
  select count(*) from public.push_queue where claimed_at is null
$$;
grant execute on all functions in schema tests to authenticated, service_role;

set local role authenticated;

-- The owner sets up the restaurant, a tablet, a phone, and invites M.
set local request.jwt.claims to
  '{"sub": "bbbbbbbb-0000-0000-0000-000000000001", "role": "authenticated"}';
select public.create_organization('Resto A');
select public.register_device('tablet-1', 'Cuisine');
select public.register_device('phone-1', 'Téléphone');
create temporary table codes (code text) on commit drop;
grant all on codes to authenticated;
insert into codes select public.create_join_code();
select is(
  public.push_changes('tablet-1', jsonb_build_array(tests.entry(1, 'stores',
    jsonb_build_object(
      'updated_at', '2026-10-06T08:00:00.000Z', 'deleted_at', null,
      'id', 'store-a', 'name', 'Brasserie A', 'address_line', 'Rue 1',
      'postal_code', '1000', 'city', 'Bruxelles', 'phone', '02',
      'created_at', '2026-01-10T09:00:00.000Z', 'vat_number', null,
      'image_asset', null, 'stale_partial_order_days', 7,
      'max_break_minutes', 30, 'notify_low_stock', 1,
      'notify_price_change', 1, 'notify_large_adjustment', 1,
      'notify_deliveries', 0, 'notify_busy_days', 1,
      'notify_clock_in', 1, 'notify_clock_out', 1,
      'busy_weekdays', '5,6,7', 'busy_reminder_days', 1,
      'business_day_auto_open_minutes', 300)))) -> 0 ->> 'status',
  'accepted', 'the store reaches the server');

-- Registering.
select lives_ok($$ select public.register_push_device('phone-1', 'token-phone') $$,
  'the owner registers their phone');
select lives_ok($$ select public.register_push_device('phone-1', 'token-phone-2') $$,
  'and again with a new token');
select throws_ok($$ select public.register_push_device('nope', 'token-x') $$,
  'P0002', null, 'an unknown device is refused');
select throws_ok($$ select count(*) from public.push_devices $$, '42501', null,
  'nobody reads the tokens directly');

set local request.jwt.claims to
  '{"sub": "bbbbbbbb-0000-0000-0000-000000000002", "role": "authenticated"}';
select public.join_organization((select code from codes));
select throws_ok($$ select public.register_push_device('tablet-1', 'token-m') $$,
  '42501', null, 'a manager gets no push');
select is(public.unregister_push_device('tablet-1'), false,
  'unregistering a device with no token says so');

-- Queueing, as notifications arrive.
set local request.jwt.claims to
  '{"sub": "bbbbbbbb-0000-0000-0000-000000000001", "role": "authenticated"}';
select is(tests.file(2, tests.note('n-out', 'outOfStock',
  'Rupture de stock : Poulet')), 'accepted', 'a rupture arrives');
select is(tests.file(3, tests.note('n-low-1', 'lowStock',
  'Stock faible : Tomates')), 'accepted', 'a stock faible arrives');
select is(tests.file(4, tests.note('n-low-2', 'lowStock',
  'Stock faible : Oignons')), 'accepted', 'and another');
select is(tests.file(5, tests.note('n-price', 'priceChange',
  'Hausse de prix : Poulet')), 'accepted', 'a price change arrives');
select is(tests.file(6, tests.note('n-old', 'outOfStock',
  'Rupture de stock : Riz', now() - interval '3 days')), 'accepted',
  'an old rupture arrives');
select is(tests.file(7, tests.note('n-out', 'outOfStock',
  'Rupture de stock : Poulet')), 'accepted',
  'the same rupture arrives from a second tablet');
select is(tests.pending(), 3::bigint,
  'the rupture and the two stock faible are queued, once each; '
  'not the price change, not the old one');

-- Claiming.
reset role;
set local role service_role;
select is(jsonb_array_length(public.claim_pushes()), 1,
  'at first only the rupture is due: a stock faible waits for others');
select is(tests.pending(), 2::bigint, 'the two stock faible still wait');

create temporary table claimed (pushes jsonb) on commit drop;
insert into claimed select public.claim_pushes(interval '0 seconds');
select is(jsonb_array_length((select pushes from claimed)), 1,
  'once due, the stock faible of a store go as one push');
select is((select pushes -> 0 ->> 'title' from claimed),
  'Stock faible : 2 produits', 'counted in the title');
select is((select pushes -> 0 ->> 'body' from claimed),
  'Brasserie A — Tomates, Oignons.', 'named in the body, with the store');
select is((select pushes -> 0 -> 'tokens' from claimed),
  '["token-phone-2"]'::jsonb, 'to the owner''s phone, latest token');
select is(jsonb_array_length(public.claim_pushes(interval '0 seconds')), 0,
  'nothing is sent twice');

-- One rupture alone keeps its own words.
reset role;
insert into public.push_queue (notification_id, store_id, kind, title, body)
  values ('n-out-2', 'store-a', 'outOfStock', 'Rupture de stock : Lait',
          'Il ne reste plus de lait.');
set local role service_role;
select is(public.claim_pushes() -> 0 ->> 'body',
  'Brasserie A — Il ne reste plus de lait.', 'a single push keeps its words');

-- An arrivée and a départ: each its own push, at once.
reset role;
set local role authenticated;
set local request.jwt.claims to
  '{"sub": "bbbbbbbb-0000-0000-0000-000000000001", "role": "authenticated"}';
select is(tests.file(8, tests.note('n-in', 'clockIn',
  'Arrivée : Noah Van Damme')), 'accepted', 'an arrivée arrives');
select is(tests.file(9, tests.note('n-leave', 'clockOut',
  'Départ : Noah Van Damme')), 'accepted', 'a départ arrives');
reset role;
set local role service_role;
select is(tests.pending(), 2::bigint, 'both are queued');
select is(jsonb_array_length(public.claim_pushes()), 2,
  'each goes as its own push, without waiting');

-- A token Firebase says is gone.
select public.forget_push_token('token-phone-2');
reset role;
select is((select count(*) from public.push_devices), 0::bigint,
  'a dead token is forgotten');

-- Signing out of the phone.
set local role authenticated;
set local request.jwt.claims to
  '{"sub": "bbbbbbbb-0000-0000-0000-000000000001", "role": "authenticated"}';
select public.register_push_device('phone-1', 'token-phone-3');
select is(public.unregister_push_device('phone-1'), true,
  'signing out stops the pushes to the phone');

select throws_ok($$ select public.claim_pushes() $$, '42501', null,
  'an app cannot claim pushes');

select * from finish();
rollback;
