-- Czat 1:1: konwersacje, członkowie, wiadomości + RLS + Realtime.
-- Wymaga migracji core (profiles itd.) — users muszą istnieć w auth.users.

-- ---------------------------------------------------------------------------
-- Tabele
-- ---------------------------------------------------------------------------

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  is_direct boolean not null default true
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  primary key (conversation_id, user_id)
);

create index if not exists idx_conversation_members_user
  on public.conversation_members (user_id);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  constraint messages_body_len check (
    char_length(body) > 0 and char_length(body) <= 4000
  )
);

create index if not exists idx_messages_conversation_created
  on public.messages (conversation_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------

alter table public.messages replica identity full;

do $pub$
begin
  alter publication supabase_realtime add table public.messages;
exception
  when duplicate_object then
    null;
  when others then
    -- często: "already member of publication" — ignorujemy
    raise notice 'public.messages do supabase_realtime: %', sqlerrm;
end
$pub$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

-- Pomocnicza funkcja: odczyt conversation_members bez ponownego RLS (bez rekursji).
create or replace function public.user_is_conversation_participant(p_conversation_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.conversation_members m
    where m.conversation_id = p_conversation_id
      and m.user_id = (select auth.uid())
  );
$$;

revoke all on function public.user_is_conversation_participant(uuid) from public;
grant execute on function public.user_is_conversation_participant(uuid) to authenticated;
grant execute on function public.user_is_conversation_participant(uuid) to service_role;

drop policy if exists "conversation_members_select" on public.conversation_members;
create policy "conversation_members_select"
  on public.conversation_members
  for select
  using ( public.user_is_conversation_participant(conversation_id) );

drop policy if exists "conversations_select_member" on public.conversations;
create policy "conversations_select_member"
  on public.conversations
  for select
  using ( public.user_is_conversation_participant(id) );

drop policy if exists "messages_select_member" on public.messages;
create policy "messages_select_member"
  on public.messages
  for select
  using ( public.user_is_conversation_participant(conversation_id) );

drop policy if exists "messages_insert_member" on public.messages;
create policy "messages_insert_member"
  on public.messages
  for insert
  with check (
    sender_id = (select auth.uid())
    and public.user_is_conversation_participant(conversation_id)
  );

-- ---------------------------------------------------------------------------
-- RPC: utwórz / zwróć rozmowę 1:1
-- ---------------------------------------------------------------------------

create or replace function public.get_or_create_direct_conversation(p_other_user uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_conv uuid;
  v_cnt int;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;
  if p_other_user is null or p_other_user = v_me then
    raise exception 'invalid peer';
  end if;

  select c.id into v_conv
  from public.conversations c
  where c.is_direct = true
    and exists (
      select 1 from public.conversation_members m1
      where m1.conversation_id = c.id and m1.user_id = v_me
    )
    and exists (
      select 1 from public.conversation_members m2
      where m2.conversation_id = c.id and m2.user_id = p_other_user
    );

  if v_conv is not null then
    select count(*)::int into v_cnt
    from public.conversation_members m
    where m.conversation_id = v_conv;
    if v_cnt = 2 then
      return v_conv;
    end if;
  end if;

  insert into public.conversations (is_direct) values (true) returning id into v_conv;
  insert into public.conversation_members (conversation_id, user_id) values
    (v_conv, v_me),
    (v_conv, p_other_user);
  return v_conv;
end;
$$;

revoke all on function public.get_or_create_direct_conversation(uuid) from public;
grant execute on function public.get_or_create_direct_conversation(uuid) to authenticated;
