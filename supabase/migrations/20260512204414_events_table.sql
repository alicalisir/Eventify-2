create table public.events (
  id               uuid        primary key default gen_random_uuid(),
  source           text        not null check (source in ('curated', 'places', 'scraped')),
  external_id      text,
  title            text        not null,
  description      text,
  category         text        not null check (category in ('music', 'sports', 'culture', 'food', 'outdoor', 'workshop', 'family')),
  subcategory      text,
  venue_name       text,
  address          text,
  city             text,
  lat              double precision,
  lng              double precision,
  starts_at        timestamptz,
  ends_at          timestamptz,
  is_recurring     boolean     not null default false,
  recurrence_rule  text,
  is_ticketed      boolean     not null default false,
  price_min        numeric,
  price_max        numeric,
  currency         text        not null default 'TRY',
  ticket_url       text,
  image_url        text,
  tags             text[],
  language         text        not null default 'tr',
  popularity_score real        not null default 0,
  embedding        extensions.vector(1024),
  embedding_model_version text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  expires_at       timestamptz
);

create index events_city_starts_at_idx on public.events (city, starts_at);
create index events_category_idx       on public.events (category);
create index events_city_category_idx  on public.events (city, category);
create index events_expires_at_idx     on public.events (expires_at) where expires_at is not null;

alter table public.events enable row level security;

create policy "events_read_all"
  on public.events for select
  using (true);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger events_set_updated_at
  before update on public.events
  for each row execute function public.set_updated_at();
