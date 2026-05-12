alter table public.users
  add column if not exists interests           text[]      not null default '{}',
  add column if not exists consent_given_at   timestamptz,
  add column if not exists persona_json       jsonb,
  add column if not exists persona_updated_at timestamptz;

comment on column public.users.interests           is 'Kullanıcının onboarding''de seçtiği ilgi alanları';
comment on column public.users.consent_given_at    is 'KVKK açık rıza onay tarihi. NULL ise rıza verilmemiş.';
comment on column public.users.persona_json        is 'CatBoost modelinin ürettiği persona JSON';
comment on column public.users.persona_updated_at  is 'persona_json son güncellenme tarihi';
