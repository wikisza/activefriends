-- Active Friends: profil użytkownika, wydarzenia na mapie, odznaki.
-- Uruchomienie: supabase db push  (po supabase link)  albo wklej w SQL Editor.
-- Kolejność: przed migracją czatu (20250328140000_direct_chat.sql).

-- ---------------------------------------------------------------------------
-- profiles (1:1 z auth.users; aplikacja robi też upsert z klienta)
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default 'Użytkownik',
  verification_level integer not null default 1
    check (verification_level >= 1 and verification_level <= 3),
  avatar_url text,
  subscribed_topics text[] not null default '{}'::text[],
  created_at timestamptz not null default now()
);

comment on table public.profiles is 'Publiczny profil; id = auth.users.id';

-- Opcjonalnie: wiersz profilu przy rejestracji (aplikacja i tak robi upsert po zalogowaniu)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, verification_level)
  values (
    new.id,
    coalesce(
      nullif(trim(coalesce(new.raw_user_meta_data->>'display_name', '')), ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Użytkownik'
    ),
    1
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- events (mapa; scenario/status jak w Dart: bikeRide, emergency, social / open…)
-- ---------------------------------------------------------------------------

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text,
  description text,
  scenario text not null,
  status text not null default 'open',
  organizer_id uuid not null references auth.users (id) on delete restrict,
  lat double precision,
  lng double precision,
  city text not null default '',
  starts_at timestamptz,
  ends_at timestamptz,
  photo_url text,
  created_at timestamptz not null default now()
);

create index if not exists idx_events_created_at on public.events (created_at desc);
create index if not exists idx_events_organizer on public.events (organizer_id);

-- ---------------------------------------------------------------------------
-- event_badges
-- ---------------------------------------------------------------------------

create table if not exists public.event_badges (
  event_id uuid not null references public.events (id) on delete cascade,
  badge_code text not null,
  badge_label text not null,
  primary key (event_id, badge_code)
);

create index if not exists idx_event_badges_event on public.event_badges (event_id);

-- ---------------------------------------------------------------------------
-- event_participants
-- ---------------------------------------------------------------------------

create table if not exists public.event_participants (
  event_id uuid not null references public.events (id) on delete cascade,
  profile_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member'
    check (role in ('member', 'organizer', 'helper')),
  joined_at timestamptz not null default now(),
  primary key (event_id, profile_id)
);

create index if not exists idx_event_participants_profile
  on public.event_participants (profile_id);

create index if not exists idx_event_participants_event
  on public.event_participants (event_id);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.events enable row level security;
alter table public.event_badges enable row level security;
alter table public.event_participants enable row level security;

drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
  on public.profiles
  for select
  to authenticated
  using (true);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles
  for insert
  to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Upsert z klienta wymaga conflict na UPDATE — polityka update_own wystarczy;
-- insert tylko gdy id = ja.

drop policy if exists "events_select_authenticated" on public.events;
create policy "events_select_authenticated"
  on public.events
  for select
  to authenticated
  using (true);

drop policy if exists "events_insert_as_organizer" on public.events;
create policy "events_insert_as_organizer"
  on public.events
  for insert
  to authenticated
  with check ((select auth.uid()) = organizer_id);

drop policy if exists "events_update_own" on public.events;
create policy "events_update_own"
  on public.events
  for update
  to authenticated
  using ((select auth.uid()) = organizer_id)
  with check ((select auth.uid()) = organizer_id);

drop policy if exists "events_delete_own" on public.events;
create policy "events_delete_own"
  on public.events
  for delete
  to authenticated
  using ((select auth.uid()) = organizer_id);

drop policy if exists "event_badges_select_authenticated" on public.event_badges;
create policy "event_badges_select_authenticated"
  on public.event_badges
  for select
  to authenticated
  using (true);

drop policy if exists "event_badges_insert_organizer" on public.event_badges;
create policy "event_badges_insert_organizer"
  on public.event_badges
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.events e
      where e.id = event_badges.event_id
        and e.organizer_id = (select auth.uid())
    )
  );

drop policy if exists "event_participants_select_authenticated" on public.event_participants;
create policy "event_participants_select_authenticated"
  on public.event_participants
  for select
  to authenticated
  using (true);

drop policy if exists "event_participants_insert_own" on public.event_participants;
create policy "event_participants_insert_own"
  on public.event_participants
  for insert
  to authenticated
  with check (
    (
      (select auth.uid()) = profile_id
      and role in ('member', 'helper')
    )
    or exists (
      select 1
      from public.events e
      where e.id = event_participants.event_id
        and e.organizer_id = (select auth.uid())
        and event_participants.profile_id = (select auth.uid())
        and event_participants.role = 'organizer'
    )
  );

drop policy if exists "event_participants_update_own" on public.event_participants;
create policy "event_participants_update_own"
  on public.event_participants
  for update
  to authenticated
  using ((select auth.uid()) = profile_id)
  with check ((select auth.uid()) = profile_id);

drop policy if exists "event_participants_delete_own" on public.event_participants;
create policy "event_participants_delete_own"
  on public.event_participants
  for delete
  to authenticated
  using ((select auth.uid()) = profile_id);
