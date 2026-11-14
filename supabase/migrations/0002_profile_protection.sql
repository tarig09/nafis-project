-- حماية الحقول الحساسة في profiles وحقول المنشورات من التلاعب من التطبيق.
-- الدوال security definer تعمل بدور postgres، أما التطبيق فيعمل بدور authenticated.

create function protect_profile_columns() returns trigger language plpgsql as $$
begin
  if current_user = 'authenticated' and not is_admin() then
    if old.role is not null and new.role is distinct from old.role then
      raise exception 'لا يمكن تغيير نوع الحساب بعد اختياره';
    end if;
    new.status := old.status;
    new.verification := old.verification;
    new.rating_avg := old.rating_avg;
    new.rating_count := old.rating_count;
    new.portfolio_approved := old.portfolio_approved;
    new.created_at := old.created_at;
    if new.portfolio_url is distinct from old.portfolio_url then
      new.portfolio_approved := false;   -- أي تغيير للرابط يحتاج موافقة جديدة
    end if;
  end if;
  return new;
end $$;

create trigger trg_protect_profile before update on profiles
  for each row execute function protect_profile_columns();

create function post_defaults() returns trigger language plpgsql as $$
begin
  if not is_admin() then
    new.pinned_until := null;
    new.status := 'published';
  end if;
  return new;
end $$;

create trigger trg_post_defaults before insert on posts
  for each row execute function post_defaults();
