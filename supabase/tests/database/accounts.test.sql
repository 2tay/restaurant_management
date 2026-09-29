-- Joining a restaurant and managing devices (SYNC_PLAN.md, Phase 4).
--
-- A owns "Resto A". M signs up and joins with a code. X is a stranger.

begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'owner@example.be'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'manager@example.be'),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'stranger@example.be');

set local role authenticated;

-- The owner.
set local request.jwt.claims to
  '{"sub": "aaaaaaaa-0000-0000-0000-000000000001", "role": "authenticated"}';
select is(public.my_account() ->> 'organization_id', null,
  'a new user belongs to no organization yet');
select isnt(public.create_organization('Resto A'), null, 'the owner signs up');
select is(public.my_account() ->> 'role', 'owner', 'my_account names the role');
select is(public.my_account() ->> 'organization_name', 'Resto A',
  'and the restaurant');
select is(public.my_account() ->> 'email', 'owner@example.be',
  'and the e-mail');

create temporary table codes (code text, organization_id uuid) on commit drop;
grant all on codes to authenticated;
insert into codes
  select public.create_join_code(), (public.my_account() ->> 'organization_id')::uuid;
select matches((select code from codes), '^[A-HJ-NP-Z2-9]{8}$',
  'a code is eight characters with no look-alikes');
select lives_ok($$ select public.register_device('tablet-1', 'Cuisine') $$,
  'the owner registers a device');

-- The manager joins, typing the code in lower case with a dash.
set local request.jwt.claims to
  '{"sub": "aaaaaaaa-0000-0000-0000-000000000002", "role": "authenticated"}';
select is(
  public.join_organization(
    lower(substr((select code from codes), 1, 4)) || '-' ||
    substr((select code from codes), 5)),
  (select organization_id from codes),
  'a manager joins with the code, typed loosely');
select is(public.my_account() ->> 'role', 'manager', 'as a manager');
select throws_ok($$ select public.create_join_code() $$, '42501', null,
  'a manager cannot invite');
select throws_ok($$ select public.remove_device('tablet-1') $$, '42501', null,
  'a manager cannot remove a device');

-- The stranger tries the same code.
set local request.jwt.claims to
  '{"sub": "aaaaaaaa-0000-0000-0000-000000000003", "role": "authenticated"}';
select throws_ok(
  format('select public.join_organization(%L)', (select code from codes)),
  'P0002', null, 'a code works once');
select throws_ok($$ select public.join_organization('NOPE2345') $$,
  'P0002', null, 'an unknown code is refused');

-- The owner removes the device; its pushes are refused from then on.
set local request.jwt.claims to
  '{"sub": "aaaaaaaa-0000-0000-0000-000000000001", "role": "authenticated"}';
select is(public.remove_device('tablet-1'), true, 'the owner removes a device');
select is(
  public.push_changes('tablet-1', '[{"id": 1, "table": "categories",
    "payload": {}}]'::jsonb) -> 0 ->> 'reason',
  'device_unknown', 'a removed device can no longer push');

select * from finish();
rollback;
