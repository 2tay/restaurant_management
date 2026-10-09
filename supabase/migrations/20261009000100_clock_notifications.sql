-- Arrivée and départ notifications (schema v24).
--
-- - `stores.notify_clock_in` / `stores.notify_clock_out`: whether an
--   employee's Pointer and Fin de journée file a notification. Off by
--   default, like on the tablets; only the owner switches them on (and only
--   the owner may push a `stores` row at all, see `apply_change`).
-- - `queue_push`: the two new kinds, `clockIn` and `clockOut`, go to the
--   owner's phone as well. One push per pointage — no grouping, each one is
--   its own event and the switches are off unless the owner wants them.

alter table public.stores
  add column notify_clock_in boolean not null default false,
  add column notify_clock_out boolean not null default false;

create or replace function private.queue_push() returns trigger
  language plpgsql security definer set search_path = ''
as $$
begin
  if new.kind in ('outOfStock', 'lowStock', 'busyDays', 'clockIn', 'clockOut')
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
