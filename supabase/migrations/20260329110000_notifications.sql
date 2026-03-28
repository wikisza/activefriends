-- ============================================================
-- Notifications table + database triggers
-- ============================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type       text        NOT NULL CHECK (type IN ('new_message','event_join','forum_like','forum_reply')),
  title      text        NOT NULL,
  body       text,
  payload    jsonb       NOT NULL DEFAULT '{}',
  is_read    boolean     NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications(user_id, created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

CREATE POLICY "notifications_select" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "notifications_update" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);
-- Inserts come from SECURITY DEFINER triggers (bypass RLS), but allow user inserts too for safety
CREATE POLICY "notifications_insert" ON public.notifications FOR INSERT WITH CHECK (auth.uid() = user_id);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'notifications') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;

-- ============================================================
-- Trigger 1: nowa wiadomość → powiadom drugą osobę w rozmowie
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_on_new_message()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_sender_name text;
  v_recipient   uuid;
BEGIN
  SELECT display_name INTO v_sender_name FROM public.profiles WHERE id = NEW.sender_id;

  FOR v_recipient IN
    SELECT user_id FROM public.conversation_members
    WHERE conversation_id = NEW.conversation_id AND user_id <> NEW.sender_id
  LOOP
    INSERT INTO public.notifications(user_id, type, title, body, payload)
    VALUES (
      v_recipient, 'new_message',
      coalesce(v_sender_name, 'Ktoś') || ' wysłał(a) wiadomość',
      left(NEW.body, 100),
      jsonb_build_object('conversation_id', NEW.conversation_id, 'sender_id', NEW.sender_id, 'message_id', NEW.id)
    );
  END LOOP;
  RETURN NEW;
END; $$;

CREATE TRIGGER trg_notify_new_message
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_message();

-- ============================================================
-- Trigger 2: dołączenie do eventu → powiadom organizatora
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_on_event_join()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_joiner_name  text;
  v_event_title  text;
  v_organizer_id uuid;
BEGIN
  IF NEW.role = 'organizer' THEN RETURN NEW; END IF;

  SELECT display_name INTO v_joiner_name FROM public.profiles WHERE id = NEW.profile_id;
  SELECT title, organizer_id INTO v_event_title, v_organizer_id FROM public.events WHERE id = NEW.event_id;

  IF NEW.profile_id = v_organizer_id THEN RETURN NEW; END IF;

  INSERT INTO public.notifications(user_id, type, title, body, payload)
  VALUES (
    v_organizer_id, 'event_join',
    coalesce(v_joiner_name, 'Ktoś') || ' dołączył(a) do Twojego wydarzenia',
    coalesce(v_event_title, ''),
    jsonb_build_object('event_id', NEW.event_id, 'joiner_id', NEW.profile_id, 'role', NEW.role)
  );
  RETURN NEW;
END; $$;

CREATE TRIGGER trg_notify_event_join
  AFTER INSERT ON public.event_participants
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_event_join();

-- ============================================================
-- Trigger 3: lajk na forum → powiadom autora komentarza
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_on_forum_like()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_liker_name    text;
  v_comment_author uuid;
  v_preview       text;
BEGIN
  IF NEW.vote <> 1 THEN RETURN NEW; END IF;

  SELECT display_name INTO v_liker_name FROM public.profiles WHERE id = NEW.user_id;
  SELECT author_id, left(content, 60) INTO v_comment_author, v_preview
    FROM public.forum_comments WHERE id = NEW.comment_id;

  IF NEW.user_id = v_comment_author THEN RETURN NEW; END IF;

  INSERT INTO public.notifications(user_id, type, title, body, payload)
  VALUES (
    v_comment_author, 'forum_like',
    coalesce(v_liker_name, 'Ktoś') || ' polubił(a) Twój komentarz',
    coalesce(v_preview, ''),
    jsonb_build_object('comment_id', NEW.comment_id, 'voter_id', NEW.user_id)
  );
  RETURN NEW;
END; $$;

CREATE TRIGGER trg_notify_forum_like
  AFTER INSERT ON public.forum_comment_votes
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_forum_like();

-- ============================================================
-- Trigger 4: odpowiedź na forum → powiadom autora wątku
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_on_forum_reply()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_author_name  text;
  v_topic_author uuid;
  v_topic_title  text;
BEGIN
  SELECT display_name INTO v_author_name FROM public.profiles WHERE id = NEW.author_id;
  SELECT author_id, title INTO v_topic_author, v_topic_title FROM public.forum_topics WHERE id = NEW.topic_id;

  IF NEW.author_id = v_topic_author THEN RETURN NEW; END IF;

  INSERT INTO public.notifications(user_id, type, title, body, payload)
  VALUES (
    v_topic_author, 'forum_reply',
    coalesce(v_author_name, 'Ktoś') || ' odpowiedział(a) w Twoim wątku',
    coalesce(v_topic_title, ''),
    jsonb_build_object('topic_id', NEW.topic_id, 'comment_id', NEW.id, 'author_id', NEW.author_id)
  );
  RETURN NEW;
END; $$;

CREATE TRIGGER trg_notify_forum_reply
  AFTER INSERT ON public.forum_comments
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_forum_reply();
