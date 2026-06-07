create table public.user_feedback (
  id                  uuid        primary key default gen_random_uuid(),
  user_id             uuid        not null references public.users(id) on delete cascade,
  suggestion_id       text        not null,
  event_id            uuid        references public.events(id) on delete set null,
  action              text        not null check (action in (
                        'view', 'open', 'like', 'dislike',
                        'save', 'dismiss', 'external_click', 'visit_confirmed'
                      )),
  suggestion_snapshot jsonb       not null,
  context_snapshot    jsonb,
  llm_provider        text,
  created_at          timestamptz not null default now()
);

create index user_feedback_user_created_idx on public.user_feedback (user_id, created_at desc);
create index user_feedback_action_idx       on public.user_feedback (user_id, action, created_at desc);

alter table public.user_feedback enable row level security;

create policy "own_feedback_rw"
  on public.user_feedback for all
  using (auth.uid() = user_id);

comment on table  public.user_feedback                     is 'User interactions with recommendations (views, likes, dismissals, etc.)';
comment on column public.user_feedback.suggestion_snapshot is 'Full suggestion JSON at the moment of generation — preserved even if the suggestion is later deleted.';
comment on column public.user_feedback.context_snapshot    is 'Context at the time of suggestion generation (time, weather, location, movement).';
