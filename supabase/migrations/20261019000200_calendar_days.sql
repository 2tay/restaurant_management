-- Calendar days at midnight UTC.
--
-- A day of pointage, a journée de service and a pay period's bounds are
-- calendar days, not moments. Tablets used to send them as midnight in their
-- own time zone (2026-10-03 00:00+02:00, kept here as 2026-10-02 22:00 UTC),
-- so a tablet in another time zone read them back at 01:00, or on the day
-- before. From now on tablets send a day as midnight UTC of its date, and read
-- midnight UTC back as their own midnight of that date.
--
-- This puts the days already here on the same footing: each one moves to
-- midnight UTC of the nearest date, which is the day the tablet meant for any
-- time zone up to twelve hours away. The update gives the rows a new
-- server_seq, so every tablet receives them again, now on the right day.

create function private.calendar_day(p_moment timestamptz)
  returns timestamptz
  language sql immutable set search_path = ''
as $$
  select date_trunc('day', (p_moment at time zone 'UTC') + interval '12 hours')
         at time zone 'UTC'
$$;

update public.attendances
   set date = private.calendar_day(date)
 where date is distinct from private.calendar_day(date);

update public.business_days
   set date = private.calendar_day(date)
 where date is distinct from private.calendar_day(date);

update public.payroll_periods
   set start_date = private.calendar_day(start_date),
       end_date = private.calendar_day(end_date)
 where start_date is distinct from private.calendar_day(start_date)
    or end_date is distinct from private.calendar_day(end_date);
