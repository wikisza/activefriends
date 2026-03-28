alter table public.profiles
  add column if not exists subscribed_topics text[] not null default '{}'::text[];

comment on column public.profiles.subscribed_topics is
  'Lista tematow/hobby subskrybowanych przez uzytkownika; uzywana m.in. jako domyslny filtr mapy.';
