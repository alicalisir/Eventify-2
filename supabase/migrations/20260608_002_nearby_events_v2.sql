-- Fix 1: Normalise city names stored with Turkish İ so they match ASCII lookup
update public.events
set city = 'Istanbul'
where lower(city) in ('istanbul', 'i̇stanbul');

update public.events
set city = 'Ankara'
where lower(city) = 'ankara';

update public.events
set city = 'Izmir'
where lower(city) in ('izmir', 'i̇zmir');

update public.events
set city = 'Bursa'
where lower(city) = 'bursa';

update public.events
set city = 'Antalya'
where lower(city) = 'antalya';

update public.events
set city = 'Kocaeli'
where lower(city) = 'kocaeli';

-- Fix 2: Replace nearby_events RPC
-- - city comparison is now case-insensitive
-- - recurring events (ongoing exhibitions, parks) always visible even without starts_at
-- - non-recurring events must have a starts_at within the next 72h
-- - events without starts_at AND is_recurring=false are excluded (scraped junk)
create or replace function public.nearby_events(
  p_city      text,
  p_interests text[],
  p_limit     int default 15
)
returns table (
  event_id    uuid,
  title       text,
  category    text,
  venue_name  text,
  address     text,
  distance_m  int,
  starts_at   timestamptz,
  is_ticketed boolean,
  price_min   numeric,
  price_max   numeric,
  currency    text
)
language sql stable security definer
as $$
  select
    id                            as event_id,
    title,
    category,
    venue_name,
    address,
    0                             as distance_m,
    starts_at,
    is_ticketed,
    price_min,
    price_max,
    currency
  from public.events
  where
    lower(city) = lower(p_city)
    and (expires_at is null or expires_at > now())
    and (
      is_recurring = true
      or (starts_at is not null
          and starts_at between now() and now() + interval '72 hours')
    )
  order by
    case when category = any(p_interests) then 0 else 1 end,
    popularity_score desc,
    starts_at asc nulls last
  limit p_limit;
$$;

comment on function public.nearby_events is
  'Returns upcoming events for a city. Recurring/ongoing events always included;
   non-recurring events must start within 72h. city comparison is case-insensitive.';
