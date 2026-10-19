-- Device numbers: each tablet of a restaurant gets a short number — T1, T2…
--
-- A commande's reference is "the largest number this tablet has seen + 1",
-- so two tablets offline both made CMD-2026-018. The tablet's number goes
-- into the reference (CMD-2026-T2-018), which makes it unique and still easy
-- to read out on the phone.
--
-- The number comes from a counter per organization and is never reused: a
-- removed tablet's orders keep naming it, so a new tablet must not take it.

alter table public.organizations
  add column device_count integer not null default 0;

alter table public.devices add column number integer;

-- Devices registered before this migration, numbered in the order they came.
with numbered as (
  select id,
         row_number() over (partition by organization_id order by created_at, id)
           as number
    from public.devices
)
update public.devices d set number = n.number
  from numbered n where n.id = d.id;

update public.organizations o set device_count = coalesce(
  (select max(number) from public.devices d where d.organization_id = o.id), 0);

alter table public.devices alter column number set not null;
alter table public.devices
  add constraint devices_organization_number unique (organization_id, number);

-- register_device now answers with the device's number. Its return type
-- changes, so it is dropped and made again.
drop function public.register_device(text, text);

create function public.register_device(p_device_id text, p_name text default '')
  returns integer
  language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := private.my_organization();
  v_existing uuid;
  v_number integer;
begin
  if v_org is null then
    raise exception 'not a member of an organization' using errcode = '42501';
  end if;

  select organization_id, number into v_existing, v_number
    from public.devices where id = p_device_id;
  if v_existing is not null and v_existing <> v_org then
    raise exception 'device belongs to another organization'
      using errcode = '42501';
  end if;

  if v_existing is not null then
    update public.devices set
      name = case when coalesce(p_name, '') = '' then name else p_name end,
      last_seen_at = now()
     where id = p_device_id;
    return v_number;
  end if;

  -- The organization row is the lock: two tablets joining at once get two
  -- numbers.
  update public.organizations set device_count = device_count + 1
   where id = v_org
   returning device_count into v_number;

  insert into public.devices (id, organization_id, name, registered_by,
    last_seen_at, number)
  values (p_device_id, v_org, coalesce(p_name, ''), auth.uid(), now(),
    v_number);
  return v_number;
end;
$$;

revoke execute on function public.register_device(text, text) from anon, public;
grant execute on function public.register_device(text, text) to authenticated;
