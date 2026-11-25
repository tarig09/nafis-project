-- إعدادات عامة (بيانات التواصل): القراءة للجميع، الكتابة للإدارة فقط
create table if not exists app_settings (
  key text primary key,
  value text not null default '',
  updated_at timestamptz default now()
);
alter table app_settings enable row level security;
drop policy if exists settings_read on app_settings;
create policy settings_read on app_settings for select using (true);
drop policy if exists settings_admin on app_settings;
create policy settings_admin on app_settings for all using (is_admin()) with check (is_admin());

-- مراجعة طلب التوثيق
create or replace function admin_review_verification(p_req uuid, p_ok boolean) returns void
language plpgsql security definer set search_path = public as $$
declare r verification_requests;
begin
  if not is_admin() then raise exception 'للإدارة فقط'; end if;
  select * into r from verification_requests where id = p_req and status = 'pending' for update;
  if not found then raise exception 'الطلب غير موجود أو تمت مراجعته'; end if;
  update verification_requests set status = case when p_ok then 'approved' else 'rejected' end where id = p_req;
  update profiles set verification = case when p_ok then 'verified'::verif_status else 'unverified'::verif_status end
    where id = r.user_id;
end $$;
revoke execute on function admin_review_verification(uuid, boolean) from public, anon;
grant execute on function admin_review_verification(uuid, boolean) to authenticated;

-- مراجعة رابط معرض الأعمال
create or replace function admin_review_portfolio(p_uid uuid, p_ok boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'للإدارة فقط'; end if;
  if p_ok then
    update profiles set portfolio_approved = true where id = p_uid;
  else
    update profiles set portfolio_url = null, portfolio_approved = false where id = p_uid;
  end if;
end $$;
revoke execute on function admin_review_portfolio(uuid, boolean) from public, anon;
grant execute on function admin_review_portfolio(uuid, boolean) to authenticated;

-- إغلاق دوال الإدارة أمام المجهول (تتحقق من is_admin داخلياً أصلاً)
revoke execute on function admin_review_payment(uuid, boolean) from public, anon;
revoke execute on function admin_resolve_dispute(uuid, int) from public, anon;
revoke execute on function admin_set_status(uuid, account_status) from public, anon;
grant execute on function admin_review_payment(uuid, boolean) to authenticated;
grant execute on function admin_resolve_dispute(uuid, int) to authenticated;
grant execute on function admin_set_status(uuid, account_status) to authenticated;
