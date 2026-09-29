-- Adding people and devices (SYNC_PLAN.md, Phase 4).
--
-- A manager joins a restaurant with a short code the owner creates: simpler
-- than an e-mail invitation, and the owner can read it out across the
-- kitchen. A code works once and expires after seven days.
--
-- Also here: the account summary the app caches after signing in, the device
-- list, and removing a lost device (its pushes are refused from then on).

create table public.join_codes (
  code text primary key,
  organization_id uuid not null references public.organizations (id)
    on delete cascade,
  role public.member_role not null default 'manager',
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  used_by uuid references auth.users (id) on delete set null,
  used_at timestamptz
);
create index join_codes_organization on public.join_codes (organization_id);

alter table public.join_codes enable row level security;
create policy join_codes_read on public.join_codes for select to authenticated
  using (organization_id = private.my_organization()
         and private.my_role() = 'owner');
revoke insert, update, delete, truncate on public.join_codes
  from anon, authenticated;
revoke all on public.join_codes from anon;

-- What the app needs to know about the signed-in account, in one call. Null
-- fields for a user who has not created or joined an organization yet.
create function public.my_account() returns jsonb
  language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'user_id', auth.uid(),
    'email', (select email from auth.users where id = auth.uid()),
    'organization_id', m.organization_id,
    'organization_name', o.name,
    'role', m.role)
  from (select 1) one
  left join public.members m on m.user_id = auth.uid()
  left join public.organizations o on o.id = m.organization_id
$$;

-- A new code for a manager to join the caller's organization. Owners only.
-- Eight characters from an alphabet with no look-alikes (no 0/O, 1/I/L).
create function public.create_join_code() returns text
  language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_org uuid := private.my_organization();
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code text;
begin
  if v_org is null or private.my_role() is distinct from 'owner' then
    raise exception 'only an owner can invite' using errcode = '42501';
  end if;

  loop
    select string_agg(substr(v_alphabet,
             1 + floor(random() * length(v_alphabet))::int, 1), '')
      into v_code from generate_series(1, 8);
    begin
      insert into public.join_codes (code, organization_id, created_by)
        values (v_code, v_org, auth.uid());
      return v_code;
    exception when unique_violation then
      -- Astronomically unlikely; try another.
    end;
  end loop;
end;
$$;

-- Joins the organization behind a code, as the role the code carries.
-- Codes are compared without spaces or dashes and in capitals, so it can be
-- typed the way it was read out.
create function public.join_organization(p_code text) returns uuid
  language plpgsql security definer set search_path = ''
as $$
declare
  v_code public.join_codes;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  if private.my_organization() is not null then
    raise exception 'already a member of an organization'
      using errcode = '23505';
  end if;

  select * into v_code from public.join_codes
   where code = upper(regexp_replace(coalesce(p_code, ''), '[\s-]', '', 'g'))
     for update;
  if not found or v_code.used_at is not null or v_code.expires_at < now() then
    raise exception 'invalid or expired code' using errcode = 'P0002';
  end if;

  insert into public.members (user_id, organization_id, role)
    values (auth.uid(), v_code.organization_id, v_code.role);
  update public.join_codes set used_by = auth.uid(), used_at = now()
   where code = v_code.code;
  return v_code.organization_id;
end;
$$;

-- Unregisters a device of the caller's organization. Owners only. Its
-- pushes are refused from then on (`device_unknown`).
create function public.remove_device(p_device_id text) returns boolean
  language plpgsql security definer set search_path = ''
as $$
begin
  if private.my_role() is distinct from 'owner' then
    raise exception 'only an owner can remove a device' using errcode = '42501';
  end if;
  delete from public.devices
   where id = p_device_id and organization_id = private.my_organization();
  return found;
end;
$$;

revoke execute on function public.my_account() from anon, public;
revoke execute on function public.create_join_code() from anon, public;
revoke execute on function public.join_organization(text) from anon, public;
revoke execute on function public.remove_device(text) from anon, public;
grant execute on function public.my_account() to authenticated;
grant execute on function public.create_join_code() to authenticated;
grant execute on function public.join_organization(text) to authenticated;
grant execute on function public.remove_device(text) to authenticated;
