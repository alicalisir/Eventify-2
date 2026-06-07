-- Core data collection tables: gps_pings, app_sessions, screen_events
-- These tables receive telemetry from the Android app.

-- ─────────────────────────────────────────────────── gps_pings ───────────────

create table public.gps_pings (
  id              bigserial     primary key,
  user_id         uuid          not null references public.users(id) on delete cascade,
  timestamp       timestamptz   not null,
  latitude        double precision not null,
  longitude       double precision not null,
  accuracy        real,
  speed_mps       real          not null default 0.0,
  movement_state  text          check (movement_state in ('stationary', 'walking', 'cycling', 'transit', 'vehicle')),
  dwell_time_s    real          not null default 0.0,
  created_at      timestamptz   not null default now()
);

create index gps_pings_user_ts_idx on public.gps_pings (user_id, timestamp desc);

alter table public.gps_pings enable row level security;

create policy "gps_pings_own"
  on public.gps_pings for all
  using (auth.uid() = user_id);


-- ─────────────────────────────────────────────────── app_sessions ────────────

create table public.app_sessions (
  id            bigserial   primary key,
  user_id       uuid        not null references public.users(id) on delete cascade,
  timestamp     timestamptz not null,
  app_name      text        not null,
  category      text,
  duration_min  real        not null,
  state         text        not null default 'foreground',
  created_at    timestamptz not null default now(),
  constraint unique_user_app_timestamp unique (user_id, app_name, timestamp)
);

create index app_sessions_user_ts_idx on public.app_sessions (user_id, timestamp desc);

alter table public.app_sessions enable row level security;

create policy "app_sessions_own"
  on public.app_sessions for all
  using (auth.uid() = user_id);


-- ─────────────────────────────────────────────────── screen_events ───────────

create table public.screen_events (
  id          bigserial   primary key,
  user_id     uuid        not null references public.users(id) on delete cascade,
  timestamp   timestamptz not null,
  event_type  text        not null check (event_type in ('on', 'off', 'unlock')),
  created_at  timestamptz not null default now()
);

create index screen_events_user_ts_idx on public.screen_events (user_id, timestamp desc);

alter table public.screen_events enable row level security;

create policy "screen_events_own"
  on public.screen_events for all
  using (auth.uid() = user_id);
