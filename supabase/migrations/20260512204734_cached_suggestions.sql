create table public.cached_suggestions (
  cache_key         text        primary key,
  user_id           uuid        references public.users(id) on delete cascade,
  payload           jsonb       not null,
  llm_provider      text,
  prompt_tokens     int,
  completion_tokens int,
  latency_ms        int,
  created_at        timestamptz not null default now(),
  expires_at        timestamptz not null
);

create index cached_sugg_user_expires_idx on public.cached_suggestions (user_id, expires_at);
create index cached_sugg_expires_idx      on public.cached_suggestions (expires_at);

alter table public.cached_suggestions enable row level security;

create policy "cached_sugg_read_own"
  on public.cached_suggestions for select
  using (auth.uid() = user_id);

comment on table  public.cached_suggestions              is '30 dk TTL LLM öneri cache. cache_key = sha256(user_id+persona_version+lat3+lng3+hour_block+weather+dow)';
comment on column public.cached_suggestions.llm_provider is 'mistral-nemo-12b | llama-3.3-8b | claude-sonnet-4-6';
