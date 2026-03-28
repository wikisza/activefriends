-- ============================================================
-- Forum: forum_topics, forum_comments, forum_comment_votes
-- ============================================================

CREATE TABLE IF NOT EXISTS public.forum_topics (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  title          text        NOT NULL CHECK (char_length(title) BETWEEN 1 AND 300),
  description    text,
  author_id      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category       text,
  is_subscribed  boolean     NOT NULL DEFAULT false,
  comment_count  int         NOT NULL DEFAULT 0,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.forum_comments (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id   uuid        NOT NULL REFERENCES public.forum_topics(id) ON DELETE CASCADE,
  author_id  uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content    text        NOT NULL CHECK (char_length(content) BETWEEN 1 AND 4000),
  parent_id  uuid        REFERENCES public.forum_comments(id) ON DELETE CASCADE,
  likes      int         NOT NULL DEFAULT 0,
  dislikes   int         NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.forum_comment_votes (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  comment_id uuid        NOT NULL REFERENCES public.forum_comments(id) ON DELETE CASCADE,
  vote       int         NOT NULL CHECK (vote IN (1, -1)),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, comment_id)
);

-- RLS
ALTER TABLE public.forum_topics        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_comments      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_comment_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "forum_topics_select"  ON public.forum_topics FOR SELECT USING (true);
CREATE POLICY "forum_topics_insert"  ON public.forum_topics FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "forum_topics_update"  ON public.forum_topics FOR UPDATE USING (auth.uid() = author_id);

CREATE POLICY "forum_comments_select" ON public.forum_comments FOR SELECT USING (true);
CREATE POLICY "forum_comments_insert" ON public.forum_comments FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "forum_comments_update" ON public.forum_comments FOR UPDATE USING (auth.uid() = author_id);
CREATE POLICY "forum_comments_delete" ON public.forum_comments FOR DELETE USING (auth.uid() = author_id);

CREATE POLICY "forum_votes_select" ON public.forum_comment_votes FOR SELECT USING (true);
CREATE POLICY "forum_votes_insert" ON public.forum_comment_votes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "forum_votes_update" ON public.forum_comment_votes FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "forum_votes_delete" ON public.forum_comment_votes FOR DELETE USING (auth.uid() = user_id);

-- updated_at trigger
CREATE OR REPLACE FUNCTION public.forum_topics_set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE TRIGGER forum_topics_updated_at
  BEFORE UPDATE ON public.forum_topics
  FOR EACH ROW EXECUTE FUNCTION public.forum_topics_set_updated_at();

-- RPC used by the app to increment comment count
CREATE OR REPLACE FUNCTION public.increment_comment_count(topic_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.forum_topics
  SET comment_count = comment_count + 1, updated_at = now()
  WHERE id = topic_id;
END; $$;

-- Realtime
ALTER TABLE public.forum_topics        REPLICA IDENTITY FULL;
ALTER TABLE public.forum_comments      REPLICA IDENTITY FULL;
ALTER TABLE public.forum_comment_votes REPLICA IDENTITY FULL;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'forum_topics') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.forum_topics;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'forum_comments') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.forum_comments;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'forum_comment_votes') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.forum_comment_votes;
  END IF;
END $$;
