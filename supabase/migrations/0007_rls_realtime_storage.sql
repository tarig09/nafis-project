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
