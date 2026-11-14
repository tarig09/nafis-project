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
