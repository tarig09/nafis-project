-- Nafis — الهيكل الأولي لقاعدة البيانات (Supabase / Postgres)
-- ملاحظة: المبالغ numeric(12,2). كل انتقالات الطلب تتم عبر دوال security definer فقط.

create extension if not exists pg_cron;   -- فعّلها من Dashboard إن لزم

-- ───────── الأنواع ─────────
create type user_role      as enum ('freelancer','client');
create type verif_status   as enum ('unverified','pending','verified');
create type account_status as enum ('active','warned','banned');
create type post_type      as enum ('general','request','offer','awareness');
create type post_status    as enum ('pending','published','rejected');
create type msg_kind       as enum ('text','delivery');
create type order_state    as enum ('awaiting_payment','payment_review','pending_accept',
                                    'in_progress','delivered','disputed','completed','refunded');
create type report_cat     as enum ('sexual','community','delivery');
create type report_status  as enum ('open','confirmed','dismissed');

-- ───────── الجداول ─────────
create table admins (user_id uuid primary key references auth.users on delete cascade);

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  role user_role,                                  -- يُختار عند أول دخول
  display_name text not null default '',
  photo_url text,
  bio text default '',
  verification verif_status not null default 'unverified',
  status account_status not null default 'active',
  rating_avg numeric(3,2) not null default 0,
  rating_count int not null default 0,
  portfolio_url text,
  portfolio_approved boolean not null default false,
  created_at timestamptz not null default now()
);

create table follows (
  follower_id uuid references profiles on delete cascade,
  followee_id uuid references profiles on delete cascade,
  created_at timestamptz default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

create table posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles on delete cascade,
  type post_type not null,
  body text not null,
  images text[] not null default '{}',
  hashtags text[] not null check (cardinality(hashtags) > 0),
  status post_status not null default 'published',
  pinned_until timestamptz,
  created_at timestamptz not null default now()
);
create index on posts (created_at desc);
create index on posts using gin (hashtags);

create table conversations (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references profiles on delete cascade,
  user_b uuid not null references profiles on delete cascade,
  last_message_at timestamptz default now(),
  check (user_a < user_b),
  unique (user_a, user_b)
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations on delete cascade,
  sender_id uuid not null references profiles,
  kind msg_kind not null default 'text',
  body text not null,
  seen_at timestamptz,
  notified_at timestamptz,
  created_at timestamptz not null default now()
);
create index on messages (conversation_id, created_at desc);
