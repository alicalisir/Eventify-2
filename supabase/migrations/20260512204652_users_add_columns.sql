alter table public.users
  add column if not exists interests           text[]      not null default '{}',
  add column if not exists consent_given_at   timestamptz,
  add column if not exists persona_json       jsonb,
  add column if not exists persona_updated_at timestamptz;

comment on column public.users.interests           is 'Interest categories selected during onboarding';
comment on column public.users.consent_given_at    is 'GDPR/KVKK explicit consent timestamp. NULL means consent not yet given.';
comment on column public.users.persona_json        is 'Persona JSON produced by the CatBoost model';
comment on column public.users.persona_updated_at  is 'Last update timestamp for persona_json';
