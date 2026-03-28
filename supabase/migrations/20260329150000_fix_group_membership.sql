-- ============================================================
-- RPC: dołącz do czatu grupowego eventu (organizator lub uczestnik)
-- Wywołuje ChatThreadScreen przy każdym otwarciu czatu grupowego
-- ============================================================
CREATE OR REPLACE FUNCTION public.ensure_group_conversation_member(p_conversation_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_event_id uuid;
BEGIN
  SELECT event_id INTO v_event_id
  FROM conversations
  WHERE id = p_conversation_id AND is_direct = false;

  IF v_event_id IS NULL THEN
    RAISE EXCEPTION 'Nie znaleziono czatu grupowego.';
  END IF;

  -- Sprawdź czy wywołujący jest organizatorem lub uczestnikiem eventu
  IF NOT EXISTS (
    SELECT 1 FROM events WHERE id = v_event_id AND organizer_id = auth.uid()
    UNION ALL
    SELECT 1 FROM event_participants WHERE event_id = v_event_id AND profile_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Brak uprawnień do tego czatu grupowego.';
  END IF;

  -- Dodaj do conversation_members (ignoruj jeśli już jest)
  INSERT INTO conversation_members(conversation_id, user_id)
  VALUES (p_conversation_id, auth.uid())
  ON CONFLICT DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_group_conversation_member(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.ensure_group_conversation_member(uuid) TO authenticated;
