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
    city = p_city
    and (expires_at is null or expires_at > now())
    and (starts_at is null or starts_at between now() and now() + interval '48 hours')
  order by
    case when category = any(p_interests) then 0 else 1 end,
    popularity_score desc,
    starts_at asc nulls last
  limit p_limit;
$$;

comment on function public.nearby_events is
  'Returns upcoming events filtered by city and interest categories. distance_m will use pgvector in V2.';