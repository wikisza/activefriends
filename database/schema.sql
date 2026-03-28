-- PostgreSQL schema proposal for ActiveFriends.
-- Recommended deployment: Supabase (managed PostgreSQL + auth + storage + realtime).

create extension if not exists pgcrypto;

create table if not exists profiles (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  verification_level smallint not null default 1 check (verification_level between 1 and 3),
  avatar_url text,
  subscribed_topics text[] not null default '{}'::text[],
  created_at timestamptz not null default now()
);

create table if not exists topics (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label text not null,
  icon_name text not null,
  created_at timestamptz not null default now()
);

create table if not exists events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text,
  description text,
  scenario text not null check (scenario in ('bikeRide', 'emergency', 'social')),
  status text not null default 'open' check (status in ('open', 'closed', 'cancelled')),
  organizer_id uuid not null references profiles(id) on delete restrict,
  lat double precision not null,
  lng double precision not null,
  city text not null default 'Bydgoszcz',
  starts_at timestamptz,
  ends_at timestamptz,
  photo_url text,
  created_at timestamptz not null default now()
);

create index if not exists idx_events_city on events(city);
create index if not exists idx_events_scenario on events(scenario);
create index if not exists idx_events_status on events(status);
create index if not exists idx_events_coordinates on events(lat, lng);

create table if not exists event_topics (
  event_id uuid not null references events(id) on delete cascade,
  topic_id uuid not null references topics(id) on delete cascade,
  primary key(event_id, topic_id)
);

create table if not exists event_badges (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events(id) on delete cascade,
  badge_code text not null,
  badge_label text not null,
  created_at timestamptz not null default now()
);

create table if not exists event_routes (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events(id) on delete cascade,
  provider text not null default 'osrm',
  geometry_geojson jsonb not null,
  distance_m integer,
  duration_s integer,
  created_at timestamptz not null default now()
);

create table if not exists event_participants (
  event_id uuid not null references events(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('member', 'organizer', 'helper')),
  joined_at timestamptz not null default now(),
  primary key(event_id, profile_id)
);

create table if not exists event_questions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events(id) on delete cascade,
  author_id uuid not null references profiles(id) on delete cascade,
  question text not null,
  answer text,
  created_at timestamptz not null default now()
);

create table if not exists local_reports (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events(id) on delete cascade,
  reporter_id uuid references profiles(id) on delete set null,
  reason text,
  created_at timestamptz not null default now()
);

create table if not exists forum_topics (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  author_id uuid not null references profiles(id) on delete cascade,
  category text,
  is_subscribed boolean not null default false,
  comment_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists forum_comments (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references forum_topics(id) on delete cascade,
  author_id uuid not null references profiles(id) on delete cascade,
  content text not null,
  parent_id uuid references forum_comments(id) on delete cascade,
  likes integer not null default 0,
  dislikes integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists forum_comment_votes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  comment_id uuid not null references forum_comments(id) on delete cascade,
  vote smallint not null check (vote in (-1, 1)), -- -1 dislike, 1 like
  created_at timestamptz not null default now(),
  unique(user_id, comment_id)
);

create index if not exists idx_forum_topics_author on forum_topics(author_id);
create index if not exists idx_forum_topics_created on forum_topics(created_at desc);
create index if not exists idx_forum_topics_category on forum_topics(category);
create index if not exists idx_forum_comments_topic on forum_comments(topic_id);
create index if not exists idx_forum_comments_parent on forum_comments(parent_id);
create index if not exists idx_forum_comment_votes on forum_comment_votes(comment_id);
