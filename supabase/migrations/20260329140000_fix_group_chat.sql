-- ============================================================
-- Fix 1: Realtime dla conversation_members
-- ============================================================
ALTER TABLE public.conversation_members REPLICA IDENTITY FULL;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'conversation_members'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_members;
  END IF;
END $$;

-- Realtime też dla conversations (żeby lista odświeżała się przy nowym czacie)
ALTER TABLE public.conversations REPLICA IDENTITY FULL;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'conversations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
  END IF;
END $$;

-- ============================================================
-- Fix 2: RPC get_or_create_event_group_conversation
-- Dodaj wywołującego (auth.uid()) do czatu nawet przy tworzeniu nowego
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_or_create_event_group_conversation(p_event_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_conv_id      uuid;
  v_event_title  text;
  v_participant  uuid;
BEGIN
  -- Sprawdź czy czat grupowy już istnieje
  SELECT id INTO v_conv_id
  FROM conversations
  WHERE event_id = p_event_id AND is_direct = false
  LIMIT 1;

  IF v_conv_id IS NOT NULL THEN
    -- Upewnij się, że wywołujący jest w czacie (np. nowo dodany uczestnik)
    INSERT INTO conversation_members(conversation_id, user_id)
    VALUES (v_conv_id, auth.uid())
    ON CONFLICT DO NOTHING;
    RETURN v_conv_id;
  END IF;

  -- Pobierz tytuł eventu
  SELECT title INTO v_event_title FROM events WHERE id = p_event_id;

  -- Utwórz konwersację
  INSERT INTO conversations(is_direct, event_id, title)
  VALUES (false, p_event_id, v_event_title)
  RETURNING id INTO v_conv_id;

  -- Dodaj wszystkich uczestników eventu
  FOR v_participant IN
    SELECT profile_id FROM event_participants WHERE event_id = p_event_id
  LOOP
    INSERT INTO conversation_members(conversation_id, user_id)
    VALUES (v_conv_id, v_participant)
    ON CONFLICT DO NOTHING;
  END LOOP;

  -- Zawsze dodaj też wywołującego (organizator może nie być w event_participants)
  INSERT INTO conversation_members(conversation_id, user_id)
  VALUES (v_conv_id, auth.uid())
  ON CONFLICT DO NOTHING;

  RETURN v_conv_id;
END;
$$;
