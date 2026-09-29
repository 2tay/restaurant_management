-- Accounts: who owns which restaurant data (SYNC_PLAN.md, Phase 3, step 3.1).
--
-- An organization is one restaurant business. It owns stores (the `stores`
-- table, next migration) and has members: people with a real login (Supabase
-- auth), each an owner or a manager. A device is one installation of the app,
-- identified by the id it made for itself on first launch (`MetaKeys.deviceId`).
--
-- Employees are not members. They sign in with their PIN on a device a member
-- has already signed in on, exactly as today.
--
-- Clients read these tables through row level security and change them only
-- through the functions below, which check who is asking.

create schema if not exists private;

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now()
);

create type public.member_role as enum ('owner', 'manager');

-- One organization per person. A second restaurant business would be a second
-- login; allowing several would make "which organization is this device in"
-- a question every call has to answer.
create table public.members (
  user_id uuid primary key references auth.users (id) on delete cascade,
  organization_id uuid not null references public.organizations (id)
    on delete cascade,
  role public.member_role not null,
  created_at timestamptz not null default now()
);
create index members_organization on public.members (organization_id);

create table public.devices (
  id text primary key check (length(id) between 1 and 64),
  organization_id uuid not null references public.organizations (id)
    on delete cascade,
  name text not null default '',
  registered_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz
);
create index devices_organization on public.devices (organization_id);

-- ---------------------------------------------------------------------------
-- Helpers. `security definer` so they can read `members` whatever the
-- caller's own row level security says, and `stable` so a policy calling
-- them per row is cheap.
-- ---------------------------------------------------------------------------

-- The caller's organization, or null for a user who has not created or joined
-- one yet.
create function private.my_organization() returns uuid
  language sql stable security definer set search_path = ''
as $$
  select organization_id from public.members where user_id = auth.uid()
$$;

-- The caller's role in their organization, or null.
create function private.my_role() returns public.member_role
  language sql stable security definer set search_path = ''
as $$
  select role from public.members where user_id = auth.uid()
$$;

-- ---------------------------------------------------------------------------
-- Row level security: members see their own organization, nothing else.
-- No insert / update / delete policies: those go through the functions.
-- ---------------------------------------------------------------------------

alter table public.organizations enable row level security;
alter table public.members enable row level security;
alter table public.devices enable row level security;

create policy organizations_read on public.organizations
  for select to authenticated
  using (id = private.my_organization());

create policy members_read on public.members
  for select to authenticated
  using (organization_id = private.my_organization());

create policy devices_read on public.devices
  for select to authenticated
  using (organization_id = private.my_organization());

revoke insert, update, delete on public.organizations, public.members,
  public.devices from anon, authenticated;
revoke all on public.organizations, public.members, public.devices from anon;

-- ---------------------------------------------------------------------------
-- Functions the app calls.
-- ---------------------------------------------------------------------------

-- Signs the caller up as the owner of a new organization. Refuses a caller who
-- already belongs to one.
create function public.create_organization(p_name text) returns uuid
  language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  if private.my_organization() is not null then
    raise exception 'already a member of an organization'
      using errcode = '23505';
  end if;

  insert into public.organizations (name) values (trim(p_name))
    returning id into v_org;
  insert into public.members (user_id, organization_id, role)
    values (auth.uid(), v_org, 'owner');
  return v_org;
end;
$$;

-- Registers this installation with the caller's organization, or refreshes
-- its name and last-seen time. A device already registered to another
-- organization is refused: its data belongs there.
create function public.register_device(p_device_id text, p_name text default '')
  returns void
  language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := private.my_organization();
  v_existing uuid;
begin
  if v_org is null then
    raise exception 'not a member of an organization' using errcode = '42501';
  end if;

  select organization_id into v_existing
    from public.devices where id = p_device_id;
  if v_existing is not null and v_existing <> v_org then
    raise exception 'device belongs to another organization'
      using errcode = '42501';
  end if;

  insert into public.devices (id, organization_id, name, registered_by,
    last_seen_at)
  values (p_device_id, v_org, coalesce(p_name, ''), auth.uid(), now())
  on conflict (id) do update set
    name = case when excluded.name = '' then public.devices.name
                else excluded.name end,
    last_seen_at = now();
end;
$$;

revoke execute on function public.create_organization(text) from anon, public;
revoke execute on function public.register_device(text, text) from anon, public;
grant execute on function public.create_organization(text) to authenticated;
grant execute on function public.register_device(text, text) to authenticated;
