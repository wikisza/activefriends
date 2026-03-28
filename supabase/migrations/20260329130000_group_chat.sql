-- ============================================================
-- Group chat linked to events
-- ============================================================

-- Dodaj kolumny do conversations
ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS event_id uuid REFERENCES public.events(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS title    text;

-- Index szybkiego wyszukiwania czatu grupowego po event_id
CREATE INDEX IF NOT EXISTS idx_conversations_event ON public.conversations(event_id)
  WHERE event_id IS NOT NULL;

-- ============================================================
-- RPC: utwórz lub zwróć czat grupowy dla eventu
-- Może wywołać tylko uczestnik/organizator (sprawdzane przez RLS)
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
    -- Upewnij się, że wywołujący jest w czacie
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

  RETURN v_conv_id;
END;
$$;

-- ============================================================
-- RPC: usuń uczestnika z eventu i z czatu grupowego
-- Tylko organizator eventu może to wywołać
-- ============================================================
CREATE OR REPLACE FUNCTION public.remove_event_participant(
  p_event_id   uuid,
  p_profile_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_organizer_id uuid;
  v_conv_id      uuid;
BEGIN
  -- Sprawdź czy wywołujący jest organizatorem
  SELECT organizer_id INTO v_organizer_id FROM events WHERE id = p_event_id;
  IF v_organizer_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Tylko organizator może usuwać uczestników.';
  END IF;

  -- Nie pozwól usunąć samego siebie (organizatora)
  IF p_profile_id = auth.uid() THEN
    RAISE EXCEPTION 'Organizator nie może usunąć siebie z wydarzenia.';
  END IF;

  -- Usuń z eventu
  DELETE FROM event_participants
  WHERE event_id = p_event_id AND profile_id = p_profile_id;

  -- Usuń z czatu grupowego (jeśli istnieje)
  SELECT id INTO v_conv_id
  FROM conversations
  WHERE event_id = p_event_id AND is_direct = false
  LIMIT 1;

  IF v_conv_id IS NOT NULL THEN
    DELETE FROM conversation_members
    WHERE conversation_id = v_conv_id AND user_id = p_profile_id;
  END IF;
END;
$$;

-- ============================================================
-- Trigger: nowy uczestnik eventu → auto-dodaj do istniejącego czatu
-- ============================================================
CREATE OR REPLACE FUNCTION public.sync_participant_to_group_chat()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_conv_id uuid;
BEGIN
  SELECT id INTO v_conv_id
  FROM conversations
  WHERE event_id = NEW.event_id AND is_direct = false
  LIMIT 1;

  IF v_conv_id IS NOT NULL THEN
    INSERT INTO conversation_members(conversation_id, user_id)
    VALUES (v_conv_id, NEW.profile_id)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_participant_join
  AFTER INSERT ON public.event_participants
  FOR EACH ROW EXECUTE FUNCTION public.sync_participant_to_group_chat();
