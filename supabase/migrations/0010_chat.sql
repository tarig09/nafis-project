-- الدردشة: قائمة المحادثات، تعليم المقروء، تنبيه الرسائل غير المقروءة بعد 5 دقائق،
-- وإغلاق ثغرة: دوال داخلية كانت قابلة للاستدعاء من التطبيق.

create function my_conversations()
returns table (id uuid, other_id uuid, other_name text, other_photo text, other_role user_role,
               last_body text, last_at timestamptz, last_sender uuid, unread int)
language sql stable security definer set search_path = public as $$
  select c.id, o.id, o.display_name, o.photo_url, o.role,
         lm.body, lm.created_at, lm.sender_id,
         (select count(*)::int from messages m
           where m.conversation_id = c.id and m.sender_id <> auth.uid() and m.seen_at is null)
  from conversations c
  join profiles o on o.id = case when c.user_a = auth.uid() then c.user_b else c.user_a end
  join lateral (select m2.body, m2.created_at, m2.sender_id from messages m2
                where m2.conversation_id = c.id order by m2.created_at desc limit 1) lm on true
  where auth.uid() in (c.user_a, c.user_b)
  order by lm.created_at desc
$$;

create function mark_conversation_seen(p_conv uuid) returns void
language sql security definer set search_path = public as $$
  update messages m set seen_at = now()
  where m.conversation_id = p_conv and m.sender_id <> auth.uid() and m.seen_at is null
    and exists (select 1 from conversations c
                where c.id = p_conv and auth.uid() in (c.user_a, c.user_b))
$$;

-- لا تعديل مباشر على الرسائل من التطبيق (كان يسمح للمستلم بتعديل نص الرسالة)
drop policy if exists msg_seen on messages;

create function chat_unread_notifier() returns void
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  for r in
    select c.id as conv,
           case when c.user_a = m.sender_id then c.user_b else c.user_a end as recipient,
           array_agg(m.id) as ids
    from messages m join conversations c on c.id = m.conversation_id
    where m.kind = 'text' and m.seen_at is null and m.notified_at is null
      and m.created_at <= now() - interval '5 minutes'
    group by c.id, case when c.user_a = m.sender_id then c.user_b else c.user_a end
  loop
    perform notify(r.recipient, 'رسالة جديدة', 'لديك رسالة لم تُقرأ منذ 5 دقائق',
                   jsonb_build_object('conversation', r.conv));
    update messages set notified_at = now() where id = any(r.ids);
  end loop;
end $$;
select cron.schedule('nafis-chat-unread', '* * * * *', 'select public.chat_unread_notifier()');

-- منع استدعاء الدوال الداخلية من التطبيق (تعمل فقط من داخل دوال أخرى أو pg_cron)
revoke execute on function notify(uuid, text, text, jsonb) from public, anon, authenticated;
revoke execute on function flag_for_ban(uuid, text) from public, anon, authenticated;
revoke execute on function _release(uuid) from public, anon, authenticated;
revoke execute on function auto_release_orders() from public, anon, authenticated;
revoke execute on function deadline_reminders() from public, anon, authenticated;
revoke execute on function chat_unread_notifier() from public, anon, authenticated;
revoke execute on function my_conversations() from public, anon;
revoke execute on function mark_conversation_seen(uuid) from public, anon;
