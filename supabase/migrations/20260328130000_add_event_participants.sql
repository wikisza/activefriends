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

alter table public.event_participants enable row level security;

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
