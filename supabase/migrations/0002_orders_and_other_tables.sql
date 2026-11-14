create table orders (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references profiles,
  freelancer_id uuid not null references profiles,
  conversation_id uuid references conversations,
  service_type text not null,
  description text not null,
  price numeric(12,2) not null check (price > 0),
  duration_days int not null check (duration_days > 0),
  fee_client numeric(12,2) not null,
  fee_freelancer numeric(12,2) not null,
  client_total numeric(12,2) not null,
  freelancer_net numeric(12,2) not null,
  state order_state not null default 'awaiting_payment',
  payment_proof_path text,
  payment_confirmed_at timestamptz,
  accepted_at timestamptz,
  due_at timestamptz,
  delivered_at timestamptz,
  auto_release_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  check (client_id <> freelancer_id)
);

create table deliveries (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders on delete cascade,
  description text,
  links text[] not null default '{}',
  files text[] not null default '{}',
  created_at timestamptz default now()
);

create table disputes (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references orders,
  opened_by uuid not null references profiles,
  reason text,
  match_percent int check (match_percent between 0 and 100),
  decided_by uuid references profiles,
  decided_at timestamptz,
  created_at timestamptz default now()
);

create table ledger_entries (            -- سجل محاسبي لحركة الأموال اليدوية
  id bigint generated always as identity primary key,
  order_id uuid not null references orders,
  kind text not null check (kind in ('payment_in','release','refund','platform_fee')),
  amount numeric(12,2) not null,
  note text,
  created_at timestamptz default now()
);

create table ratings (
  order_id uuid primary key references orders,
  client_id uuid not null references profiles,
  freelancer_id uuid not null references profiles,
  stars smallint not null check (stars between 1 and 5),
  created_at timestamptz default now()
);

create table reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles,
  target_id uuid not null references profiles,
  category report_cat not null,
  details text,
  status report_status not null default 'open',
  created_at timestamptz default now()
);

create table verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles,
  samples text[] not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz default now()
);

create table feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles,
  kind text not null check (kind in ('complaint','suggestion')),
  body text not null,
  created_at timestamptz default now()
);

create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles on delete cascade,
  title text not null, body text, data jsonb,
  read_at timestamptz,
  created_at timestamptz default now()
);

create table device_tokens (
  user_id uuid references profiles on delete cascade,
  token text primary key,
  platform text
);
