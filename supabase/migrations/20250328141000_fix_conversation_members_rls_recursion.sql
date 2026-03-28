-- Naprawa błędu: "infinite recursion detected in policy for relation conversation_members"
-- Uruchom w SQL Editor, jeśli wcześniej wgrałeś starą wersję 20250328140000 bez funkcji pomocniczej.

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
