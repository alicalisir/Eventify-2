-- Unique index on external_id so the scraper can upsert without duplicates.
-- Uses a partial index (WHERE external_id IS NOT NULL) to skip curated/manual rows.
create unique index if not exists events_external_id_uidx
  on public.events (external_id)
  where external_id is not null;
