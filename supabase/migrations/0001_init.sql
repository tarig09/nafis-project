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

-- ───────── دوال مساعدة ─────────
create function is_admin() returns boolean language sql stable security definer as
$$ select exists (select 1 from admins where user_id = auth.uid()) $$;

-- إنشاء profile تلقائياً عند أول دخول بجوجل
create function handle_new_user() returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, display_name, photo_url)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), new.raw_user_meta_data->>'avatar_url');
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- منع الروابط وأرقام الهواتف (نصوص الدردشة والمنشورات)
create function violates_contact_rule(t text) returns boolean language sql immutable as $$
  select t ~* '(https?://|www\.|[a-z0-9-]+\.(com|net|org|io|me|sd|app)\b|wa\.me|t\.me)'
      or regexp_replace(translate(t,'٠١٢٣٤٥٦٧٨٩','0123456789'),'[\s\-\.\(\)\+]','','g') ~ '[0-9]{7,}'
$$;

create function guard_message() returns trigger language plpgsql as $$
begin
  if new.kind = 'text' and violates_contact_rule(new.body) then
    raise exception 'ممنوع إرسال روابط أو أرقام هواتف في الدردشة';
  end if;
  update conversations set last_message_at = now() where id = new.conversation_id;
  return new;
end $$;
create trigger trg_guard_message before insert on messages
  for each row execute function guard_message();

create function guard_post() returns trigger language plpgsql as $$
declare me profiles;
begin
  select * into me from profiles where id = new.author_id;
  if me.status = 'banned' then raise exception 'الحساب محظور'; end if;
  if new.type = 'request' and me.role <> 'client' then raise exception 'منشورات الطلب للعملاء فقط'; end if;
  if new.type = 'offer'   and me.role <> 'freelancer' then raise exception 'منشورات التقديم للمستقلين فقط'; end if;
  if new.type = 'awareness' and not is_admin() then raise exception 'للإدارة فقط'; end if;
  if violates_contact_rule(new.body) then raise exception 'ممنوع الروابط وأرقام الهواتف في المنشور'; end if;
  if new.type = 'awareness' then new.pinned_until := now() + interval '24 hours'; end if;
  return new;
end $$;
create trigger trg_guard_post before insert on posts
  for each row execute function guard_post();

-- ───────── الخلاصة والبحث ─────────
create function get_feed(p_limit int default 20, p_offset int default 0)
returns setof posts language sql stable as $$
  select p.* from posts p
  where p.status = 'published'
    and (p.created_at > now() - interval '7 days' or p.pinned_until > now())
  order by (p.pinned_until > now()) desc nulls last,
           exists (select 1 from follows f where f.follower_id = auth.uid() and f.followee_id = p.author_id) desc,
           p.created_at desc
  limit p_limit offset p_offset
$$;

create function search_posts(q text, p_limit int default 30, p_offset int default 0)
returns setof posts language sql stable as $$
  select p.* from posts p
  where p.status = 'published'
    and p.created_at > now() - interval '30 days'
    and (p.hashtags && string_to_array(lower(regexp_replace(q,'#','','g')),' ')
         or p.body ilike '%' || q || '%')
  order by p.created_at desc
  limit p_limit offset p_offset
$$;

create function start_conversation(other uuid) returns uuid language plpgsql security definer as $$
declare a uuid := least(auth.uid(), other); b uuid := greatest(auth.uid(), other); cid uuid;
begin
  insert into conversations (user_a, user_b) values (a,b)
  on conflict (user_a, user_b) do update set last_message_at = now()
  returning id into cid;
  return cid;
end $$;

-- ───────── الطلبات (كل الانتقالات هنا) ─────────
create function notify(uid uuid, t text, b text, d jsonb default null) returns void
language sql security definer as $$
  insert into notifications (user_id, title, body, data) values (uid, t, b, d)
$$;

create function create_order(p_freelancer uuid, p_conv uuid, p_type text, p_desc text,
                             p_price numeric, p_days int) returns uuid
language plpgsql security definer as $$
declare me profiles; fee numeric(12,2); oid uuid;
begin
  select * into me from profiles where id = auth.uid();
  if me.role <> 'client' or me.status = 'banned' then raise exception 'غير مسموح'; end if;
  fee := round(p_price * 0.05, 2);
  insert into orders (client_id, freelancer_id, conversation_id, service_type, description, price,
                      duration_days, fee_client, fee_freelancer, client_total, freelancer_net)
  values (auth.uid(), p_freelancer, p_conv, p_type, p_desc, p_price, p_days,
          fee, fee, p_price + fee, p_price - fee)
  returning id into oid;
  return oid;
end $$;

create function submit_payment_proof(p_order uuid, p_path text) returns void
language plpgsql security definer as $$
begin
  update orders set payment_proof_path = p_path, state = 'payment_review'
  where id = p_order and client_id = auth.uid() and state in ('awaiting_payment','payment_review');
  if not found then raise exception 'طلب غير صالح'; end if;
end $$;

create function admin_review_payment(p_order uuid, p_ok boolean) returns void
language plpgsql security definer as $$
declare o orders;
begin
  if not is_admin() then raise exception 'للإدارة فقط'; end if;
  select * into o from orders where id = p_order and state = 'payment_review' for update;
  if not found then raise exception 'الطلب ليس قيد المراجعة'; end if;
  if p_ok then
    update orders set state='pending_accept', payment_confirmed_at=now() where id=p_order;
    insert into ledger_entries (order_id, kind, amount) values (p_order,'payment_in',o.client_total);
    perform notify(o.freelancer_id,'طلب مشروع جديد','لديك طلب جديد بانتظار موافقتك',jsonb_build_object('order',p_order));
  else
    update orders set state='awaiting_payment', payment_proof_path=null where id=p_order;
    perform notify(o.client_id,'تعذر تأكيد الدفع','يرجى رفع إثبات صحيح',jsonb_build_object('order',p_order));
  end if;
end $$;

create function freelancer_respond(p_order uuid, p_accept boolean) returns void
language plpgsql security definer as $$
declare o orders;
begin
  select * into o from orders where id=p_order and freelancer_id=auth.uid() and state='pending_accept' for update;
  if not found then raise exception 'غير مسموح'; end if;
  if p_accept then
    update orders set state='in_progress', accepted_at=now(),
           due_at = now() + make_interval(days => duration_days) where id=p_order;
    perform notify(o.freelancer_id,'ابدأ العمل','تم تأكيد الدفع وقبول الطلب',jsonb_build_object('order',p_order));
    perform notify(o.client_id,'تم قبول طلبك','بدأ مقدم الخدمة العمل',jsonb_build_object('order',p_order));
  else
    update orders set state='refunded', completed_at=now() where id=p_order;
    insert into ledger_entries (order_id, kind, amount, note) values (p_order,'refund',o.client_total,'رفض المستقل');
    perform notify(o.client_id,'اعتذار عن الطلب','اعتذر مقدم الخدمة وسيُعاد مبلغك كاملاً',jsonb_build_object('order',p_order));
  end if;
end $$;

create function deliver_order(p_order uuid, p_desc text, p_links text[], p_files text[]) returns void
language plpgsql security definer as $$
begin
  update orders set state='delivered', delivered_at=now(), auto_release_at=now()+interval '24 hours'
  where id=p_order and freelancer_id=auth.uid() and state='in_progress';
  if not found then raise exception 'غير مسموح'; end if;
  insert into deliveries (order_id, description, links, files) values (p_order,p_desc,p_links,p_files);
end $$;

create function _release(p_order uuid) returns void language plpgsql as $$
declare o orders;
begin
  select * into o from orders where id=p_order;
  update orders set state='completed', completed_at=now() where id=p_order;
  insert into ledger_entries (order_id, kind, amount) values
    (p_order,'release',o.freelancer_net),(p_order,'platform_fee',o.fee_client+o.fee_freelancer);
  perform notify(o.freelancer_id,'تم تحويل مستحقاتك','اكتمل الطلب',jsonb_build_object('order',p_order));
end $$;

create function client_accept_delivery(p_order uuid) returns void
language plpgsql security definer as $$
begin
  perform 1 from orders where id=p_order and client_id=auth.uid() and state='delivered' for update;
  if not found then raise exception 'غير مسموح'; end if;
  perform _release(p_order);
end $$;

create function open_dispute(p_order uuid, p_reason text) returns void
language plpgsql security definer as $$
begin
  update orders set state='disputed', auto_release_at=null
  where id=p_order and client_id=auth.uid() and state='delivered';
  if not found then raise exception 'غير مسموح'; end if;
  insert into disputes (order_id, opened_by, reason) values (p_order, auth.uid(), p_reason);
  insert into reports (reporter_id, target_id, category, details)
    select client_id, freelancer_id, 'delivery', p_reason from orders where id=p_order;
end $$;

create function admin_resolve_dispute(p_order uuid, p_match int) returns void
language plpgsql security definer as $$
declare o orders;
begin
  if not is_admin() then raise exception 'للإدارة فقط'; end if;
  select * into o from orders where id=p_order and state='disputed' for update;
  if not found then raise exception 'ليس نزاعاً مفتوحاً'; end if;
  update disputes set match_percent=p_match, decided_by=auth.uid(), decided_at=now() where order_id=p_order;
  if p_match >= 70 then
    perform _release(p_order);
    update reports set status='dismissed' where target_id=o.freelancer_id and category='delivery' and status='open' and details is not distinct from (select reason from disputes where order_id=p_order);
  elsif p_match <= 50 then
    update orders set state='refunded', completed_at=now() where id=p_order;
    insert into ledger_entries (order_id, kind, amount, note) values (p_order,'refund',o.client_total,'نزاع');
    update reports set status='confirmed' where target_id=o.freelancer_id and category='delivery' and status='open' and details is not distinct from (select reason from disputes where order_id=p_order);
  else
    raise exception 'النطاق 51–69%% غير محدد بعد (docs/06-open-questions.md #1)';
  end if;
end $$;

-- تحويل تلقائي بعد 24 ساعة دون تفاعل
create function auto_release_orders() returns void language plpgsql security definer as $$
declare r record;
begin
  for r in select id from orders where state='delivered' and auto_release_at <= now() for update skip locked
  loop perform _release(r.id); end loop;
end $$;
select cron.schedule('nafis-auto-release','*/10 * * * *','select public.auto_release_orders()');

-- تنبيه اقتراب/انتهاء المدة
create function deadline_reminders() returns void language plpgsql security definer as $$
declare r record;
begin
  for r in select id, freelancer_id from orders where state='in_progress' and due_at <= now() + interval '6 hours'
           and not exists (select 1 from notifications n where n.user_id=freelancer_id and (n.data->>'deadline')=id::text)
  loop perform notify(r.freelancer_id,'اقترب موعد التسليم','انتهى الوقت أو اقترب، يرجى تسليم العمل',
                      jsonb_build_object('order',r.id,'deadline',r.id)); end loop;
end $$;
select cron.schedule('nafis-deadlines','*/30 * * * *','select public.deadline_reminders()');

-- ───────── التقييم والحظر ─────────
create function rate_order(p_order uuid, p_stars int) returns void
language plpgsql security definer as $$
declare o orders; created timestamptz;
begin
  select * into o from orders where id=p_order and client_id=auth.uid() and state='completed';
  if not found then raise exception 'لا يمكن التقييم'; end if;
  select created_at into created from profiles where id=auth.uid();
  if created > now() - interval '7 days' then raise exception 'يجب أن يمر 7 أيام على إنشاء الحساب'; end if;
  insert into ratings (order_id, client_id, freelancer_id, stars) values (p_order, auth.uid(), o.freelancer_id, p_stars);
end $$;

create function after_rating() returns trigger language plpgsql security definer as $$
declare avg_ numeric; cnt int;
begin
  select avg(stars), count(*) into avg_, cnt from ratings where freelancer_id = new.freelancer_id;
  update profiles set rating_avg = round(avg_,2), rating_count = cnt where id = new.freelancer_id;
  -- حد التقييم <= 2.0 (انظر السؤال #6 بخصوص حد أدنى لعدد التقييمات)
  if avg_ <= 2.0 then perform flag_for_ban(new.freelancer_id,'انخفاض التقييم'); end if;
  return new;
end $$;
create trigger trg_after_rating after insert on ratings for each row execute function after_rating();

-- تحذير رسمي أولاً؛ الحظر النهائي بيد الإدارة بعد طلب المراجعة
create function flag_for_ban(uid uuid, why text) returns void language plpgsql security definer as $$
begin
  update profiles set status='warned' where id=uid and status='active';
  if found then perform notify(uid,'تحذير رسمي', why || '. يمكنك طلب مراجعة يدوية من الإدارة'); end if;
end $$;

create function after_report_update() returns trigger language plpgsql security definer as $$
declare delivery_cnt int; other_cnt int;
begin
  if new.status = 'confirmed' then
    select count(*) filter (where category='delivery'), count(*) filter (where category<>'delivery')
      into delivery_cnt, other_cnt from reports where target_id=new.target_id and status='confirmed';
    if delivery_cnt >= 5 then perform flag_for_ban(new.target_id,'5 شكاوى تسليم مؤكدة');
    elsif other_cnt >= 10 then perform flag_for_ban(new.target_id,'10 بلاغات مؤكدة'); end if;
  end if;
  return new;
end $$;
create trigger trg_after_report after update on reports for each row execute function after_report_update();

create function admin_set_status(uid uuid, s account_status) returns void language plpgsql security definer as $$
begin
  if not is_admin() then raise exception 'للإدارة فقط'; end if;
  update profiles set status = s where id = uid;
end $$;

-- ───────── RLS ─────────
alter table profiles enable row level security;
alter table follows enable row level security;
alter table posts enable row level security;
alter table conversations enable row level security;
alter table messages enable row level security;
alter table orders enable row level security;
alter table deliveries enable row level security;
alter table disputes enable row level security;
alter table ledger_entries enable row level security;
alter table ratings enable row level security;
alter table reports enable row level security;
alter table verification_requests enable row level security;
alter table feedback enable row level security;
alter table notifications enable row level security;
alter table device_tokens enable row level security;
alter table admins enable row level security;

create policy profiles_read on profiles for select using (true);
-- المستخدم يعدّل بياناته الشخصية فقط؛ الحقول الحساسة عبر دوال/إدارة
create policy profiles_update_own on profiles for update using (id = auth.uid())
  with check (id = auth.uid()
    and status = (select status from profiles where id = auth.uid())
    and verification = (select verification from profiles where id = auth.uid())
    and rating_avg = (select rating_avg from profiles where id = auth.uid()));

create policy follows_read  on follows for select using (true);
create policy follows_write on follows for insert with check (follower_id = auth.uid());
create policy follows_del   on follows for delete using (follower_id = auth.uid());

create policy posts_read   on posts for select using (status='published' or author_id=auth.uid() or is_admin());
create policy posts_insert on posts for insert with check (author_id = auth.uid());
create policy posts_delete on posts for delete using (author_id = auth.uid() or is_admin());

create policy conv_read on conversations for select using (auth.uid() in (user_a,user_b));
create policy msg_read  on messages for select using (exists (select 1 from conversations c
  where c.id = conversation_id and auth.uid() in (c.user_a,c.user_b)));
create policy msg_insert on messages for insert with check (sender_id = auth.uid() and kind = 'text'
  and exists (select 1 from conversations c where c.id = conversation_id and auth.uid() in (c.user_a,c.user_b)));
create policy msg_seen on messages for update using (sender_id <> auth.uid() and exists (select 1 from conversations c
  where c.id = conversation_id and auth.uid() in (c.user_a,c.user_b)));

create policy orders_read on orders for select using (auth.uid() in (client_id,freelancer_id) or is_admin());
create policy deliveries_read on deliveries for select using (exists (select 1 from orders o
  where o.id = order_id and (auth.uid() in (o.client_id,o.freelancer_id) or is_admin())));
create policy disputes_read on disputes for select using (is_admin() or exists (select 1 from orders o
  where o.id = order_id and auth.uid() in (o.client_id,o.freelancer_id)));
create policy ledger_admin on ledger_entries for select using (is_admin());
create policy ratings_read on ratings for select using (true);   -- لا يُعرض تقييم لحساب عميل (لا يوجد تقييم للعملاء أصلاً)
create policy reports_insert on reports for insert with check (reporter_id = auth.uid());
create policy reports_admin on reports for all using (is_admin());
create policy verif_own on verification_requests for select using (user_id = auth.uid() or is_admin());
create policy verif_insert on verification_requests for insert with check (user_id = auth.uid());
create policy verif_admin on verification_requests for update using (is_admin());
create policy feedback_insert on feedback for insert with check (user_id = auth.uid());
create policy feedback_admin on feedback for select using (is_admin());
create policy notif_own on notifications for select using (user_id = auth.uid());
create policy notif_mark on notifications for update using (user_id = auth.uid());
create policy tokens_own on device_tokens for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- الدردشة: تفعيل Realtime
alter publication supabase_realtime add table messages, notifications;

-- ───────── Storage ─────────
insert into storage.buckets (id, name, public) values
  ('post-images', 'post-images', true),
  ('payment-proofs', 'payment-proofs', false),
  ('deliveries', 'deliveries', false),
  ('verification-samples', 'verification-samples', false)
on conflict do nothing;
-- سياسات Storage: ارفع داخل مجلد باسم uid (مثل: {uid}/file.png) وقيّد القراءة لصاحب المجلد/الإدارة.
-- تُضاف في migration لاحق بعد تحديد مسارات الملفات.
