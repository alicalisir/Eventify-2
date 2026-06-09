-- Spread non-recurring curated events evenly across the next 7 days.
-- Safe to run multiple times (only touches rows whose starts_at is already past).
with numbered as (
  select id, row_number() over (order by id) as rn
  from public.events
  where source = 'curated'
    and is_recurring = false
    and (starts_at is null or starts_at < now() + interval '1 day')
)
update public.events e
set
  starts_at  = now() + ((n.rn % 7) || ' days')::interval + interval '19 hours',
  ends_at    = now() + ((n.rn % 7) || ' days')::interval + interval '22 hours',
  expires_at = now() + ((n.rn % 7) || ' days')::interval + interval '22 hours'
from numbered n
where e.id = n.id;
