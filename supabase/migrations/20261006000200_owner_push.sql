-- Phone push for the owner (PUSH_NOTIFICATIONS.md).
--
-- Three of the notifications the tablets file are worth a push to the
-- owner's phone: a rupture de stock, a stock faible, and the jours chargés
-- reminder. Everything else stays in the bell.
--
-- - `push_devices`: where to send. One row per device on which the owner is
--   signed in, holding its Firebase token. Written only through
--   `register_push_device` / `unregister_push_device`.
-- - `push_queue`: what to send. A trigger queues each of those three kinds
--   as the notification first reaches the server. A notification filed on
--   two tablets has one id (the situation's), so it is queued once.
-- - `claim_pushes`: what is due, grouped and worded, with the phones to send
--   it to. A rupture or a jours chargés goes at once; a stock faible waits
--   until the oldest one of its store is two minutes old, then every stock
--   faible of that store goes as one push.
-- - The `send-pushes` Edge Function claims and sends, every minute while the
--   queue is not empty (the cron job at the end).

-- ---------------------------------------------------------------------------
-- Where to send
-- ---------------------------------------------------------------------------

create table public.push_devices (
  device_id text primary key references public.devices (id) on delete cascade,
  organization_id uuid not null references public.organizations (id)
    on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null check (length(token) between 1 and 4096),
  updated_at timestamptz not null default now()
);
create index push_devices_organization on public.push_devices (organization_id);

-- A token is a secret of its phone: nobody reads this table but the
-- functions below.
alter table public.push_devices enable row level security;
revoke all on public.push_devices from anon, authenticated;

-- This device's token, for the owner signed in on it. The app calls it when
-- the owner signs in, and again when Firebase gives the phone a new token.
-- Owners only: a manager's phone gets no push.
create function public.register_push_device(p_device_id text, p_token text)
  returns void
  language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := private.my_organization();
begin
  if v_org is null or private.my_role() is distinct from 'owner' then
    raise exception 'only an owner receives pushes' using errcode = '42501';
  end if;
  if not exists (select 1 from public.devices
                  where id = p_device_id and organization_id = v_org) then
    raise exception 'unknown device' using errcode = 'P0002';
  end if;

  insert into public.push_devices (device_id, organization_id, user_id, token)
    values (p_device_id, v_org, auth.uid(), p_token)
  on conflict (device_id) do update set
    user_id = excluded.user_id,
    token = excluded.token,
    updated_at = now();
end;
$$;

-- Stops the pushes to this device: the owner signed out of it, or someone
-- else signed in. Any member may: whoever is at the tablet now. Returns
-- whether there was something to stop.
create function public.unregister_push_device(p_device_id text)
  returns boolean
  language plpgsql security definer set search_path = ''
as $$
declare
  v_found boolean;
begin
  delete from public.push_devices
   where device_id = p_device_id
     and organization_id = private.my_organization();
  get diagnostics v_found = row_count;
  return v_found;
end;
$$;

revoke execute on function public.register_push_device(text, text)
  from anon, public;
revoke execute on function public.unregister_push_device(text)
  from anon, public;
grant execute on function public.register_push_device(text, text)
  to authenticated;
grant execute on function public.unregister_push_device(text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- What to send
-- ---------------------------------------------------------------------------

create table public.push_queue (
  notification_id text primary key,
  store_id text not null references public.stores (id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null,
  related_item_id text,
  queued_at timestamptz not null default now(),
  claimed_at timestamptz
);
create index push_queue_pending on public.push_queue (store_id, kind)
  where claimed_at is null;

alter table public.push_queue enable row level security;
revoke all on public.push_queue from anon, authenticated;

-- Queues a notification worth a push, as it first reaches the server. Only
-- on insert: the same notification sent again by a second tablet is an
-- update here, and is not news. Nothing older than a day: a device sending
-- its old data for the first time must not wake the owner with last month.
create function private.queue_push() returns trigger
  language plpgsql security definer set search_path = ''
as $$
begin
  if new.kind in ('outOfStock', 'lowStock', 'busyDays')
     and new.deleted_at is null
     and new.created_at > now() - interval '1 day' then
    insert into public.push_queue
      (notification_id, store_id, kind, title, body, related_item_id)
    values
      (new.id, new.store_id, new.kind, new.title, new.body,
       new.related_item_id)
    on conflict (notification_id) do nothing;
  end if;
  return null;
end;
$$;

create trigger notifications_queue_push after insert on public.notifications
  for each row execute function private.queue_push();

-- ---------------------------------------------------------------------------
-- Claiming it
-- ---------------------------------------------------------------------------

-- What is due now, marked claimed, as a list of pushes:
-- `[{store_id, kind, title, body, tokens: [...]}]`. Called by the
-- `send-pushes` Edge Function only (service role).
--
-- A push is sent at most once: rows are claimed before the function sends
-- them, and two calls at once never claim the same row (the second finds
-- the lock taken and returns nothing). A push with no phone to go to is
-- claimed all the same, so the queue does not grow.
create function public.claim_pushes(
  p_low_stock_wait interval default interval '2 minutes'
) returns jsonb
  language plpgsql security definer set search_path = ''
as $$
declare
  v_pushes jsonb;
begin
  if not pg_try_advisory_xact_lock(hashtext('public.claim_pushes')) then
    return '[]'::jsonb;
  end if;

  -- Claimed rows are kept a week, for looking into a missing push.
  delete from public.push_queue where claimed_at < now() - interval '7 days';

  with due as (
    update public.push_queue q
       set claimed_at = now()
     where q.claimed_at is null
       and (q.kind <> 'lowStock'
            or exists (select 1 from public.push_queue o
                        where o.store_id = q.store_id
                          and o.kind = 'lowStock'
                          and o.claimed_at is null
                          and o.queued_at <= now() - p_low_stock_wait))
    returning q.*
  ),
  -- One push per rupture and per jours chargés; one per store for every
  -- stock faible together.
  grouped as (
    select store_id, kind, min(queued_at) as queued_at, count(*) as n,
           (array_agg(title order by queued_at, notification_id))[1] as title,
           (array_agg(body order by queued_at, notification_id))[1] as body,
           array_agg(
             coalesce(nullif(split_part(title, ' : ', 2), ''), title)
             order by queued_at, notification_id) as names
      from due
     group by store_id, kind,
              case when kind = 'lowStock' then '' else notification_id end
  ),
  worded as (
    select g.store_id, g.kind, g.queued_at,
           case when g.n = 1 then g.title
                else 'Stock faible : ' || g.n || ' produits' end as title,
           s.name || ' — ' ||
           case when g.n = 1 then g.body
                else array_to_string(g.names[1:3], ', ') ||
                     case when g.n > 3
                          then ' et ' || (g.n - 3) || ' autre' ||
                               case when g.n > 4 then 's' else '' end
                          else '' end || '.'
           end as body,
           s.organization_id
      from grouped g
      join public.stores s on s.id = g.store_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'store_id', w.store_id,
           'kind', w.kind,
           'title', w.title,
           'body', w.body,
           'tokens', (
             select coalesce(jsonb_agg(d.token order by d.device_id), '[]')
               from public.push_devices d
               join public.members m
                 on m.user_id = d.user_id
                and m.organization_id = d.organization_id
              where d.organization_id = w.organization_id
                and m.role = 'owner'))
           order by w.queued_at), '[]'::jsonb)
    into v_pushes
    from worded w;

  return v_pushes;
end;
$$;

-- A token Firebase says is gone (the app was uninstalled): stop sending to
-- it. Called by the `send-pushes` Edge Function only.
create function public.forget_push_token(p_token text) returns void
  language sql security definer set search_path = ''
as $$
  delete from public.push_devices where token = p_token
$$;

revoke execute on function public.claim_pushes(interval)
  from anon, authenticated, public;
revoke execute on function public.forget_push_token(text)
  from anon, authenticated, public;
grant execute on function public.claim_pushes(interval) to service_role;
grant execute on function public.forget_push_token(text) to service_role;

-- ---------------------------------------------------------------------------
-- Every minute, while there is something to send
-- ---------------------------------------------------------------------------

-- Calls the `send-pushes` Edge Function. Its address and the shared secret
-- it checks are read from the Vault, set once per project
-- (PUSH_NOTIFICATIONS.md): `project_url` and `push_cron_secret`. A project
-- without them (a local one) simply sends nothing.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

create function private.call_send_pushes() returns void
  language plpgsql security definer set search_path = ''
as $$
declare
  v_url text;
  v_secret text;
begin
  if not exists (select 1 from public.push_queue where claimed_at is null) then
    return;
  end if;
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'push_cron_secret';
  if v_url is null or v_secret is null then
    return;
  end if;
  perform net.http_post(
    url := rtrim(v_url, '/') || '/functions/v1/send-pushes',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret),
    body := '{}'::jsonb);
end;
$$;

select cron.schedule('send-owner-pushes', '* * * * *',
  'select private.call_send_pushes()');
