-- 1) نماذج التوثيق: صور فقط حتى 2 ميغا، داخل مجلد {uid}/، القراءة لصاحبها وللإدارة
update storage.buckets
set file_size_limit = 2097152,
    allowed_mime_types = array['image/jpeg','image/png','image/webp']
where id = 'verification-samples';

drop policy if exists vs_insert on storage.objects;
create policy vs_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'verification-samples' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists vs_select on storage.objects;
create policy vs_select on storage.objects for select to authenticated
  using (bucket_id = 'verification-samples'
         and ((storage.foldername(name))[1] = auth.uid()::text or is_admin()));

-- 2) تعديل نص المنشور (النص فقط، لصاحبه فقط، مع فلتر الروابط والأرقام)
create or replace function edit_post(p_post uuid, p_body text) returns void
language plpgsql security definer set search_path = public as $$
declare me profiles; pa uuid;
begin
  select author_id into pa from posts where id = p_post;
  if pa is null or pa <> auth.uid() then raise exception 'غير مسموح'; end if;
  select * into me from profiles where id = auth.uid();
  if me.status = 'banned' then raise exception 'الحساب محظور'; end if;
  if length(trim(coalesce(p_body,''))) = 0 then raise exception 'النص مطلوب'; end if;
  if violates_contact_rule(p_body) then
    raise exception 'ممنوع إضافة روابط أو أرقام هواتف في المنشورات';
  end if;
  update posts set body = trim(p_body) where id = p_post;
end $$;
revoke execute on function edit_post(uuid, text) from public, anon;
grant execute on function edit_post(uuid, text) to authenticated;

-- 3) رسالة التسليم الرسمية في الدردشة عند إنشاء تسليم
create or replace function delivery_chat_message() returns trigger
language plpgsql security definer set search_path = public as $$
declare o orders;
begin
  select * into o from orders where id = new.order_id;
  if o.conversation_id is not null then
    insert into messages (conversation_id, sender_id, kind, body)
    values (o.conversation_id, o.freelancer_id, 'delivery',
            'تم تسليم الطلب: ' || o.service_type);
  end if;
  return new;
end $$;
revoke execute on function delivery_chat_message() from public, anon, authenticated;

drop trigger if exists trg_delivery_chat on deliveries;
create trigger trg_delivery_chat after insert on deliveries
  for each row execute function delivery_chat_message();
