-- ملفات التسليم: صور حتى 5 ميغا، المسار {freelancer_uid}/{order_id}/اسم.
-- الرفع للمستقل في مجلده، والقراءة للمستقل وللعميل صاحب الطلب وللإدارة.
update storage.buckets
set file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg','image/png','image/webp']
where id = 'deliveries';

drop policy if exists dl_insert on storage.objects;
create policy dl_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'deliveries' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists dl_select on storage.objects;
create policy dl_select on storage.objects for select to authenticated
  using (bucket_id = 'deliveries' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or is_admin()
    or exists (select 1 from public.orders o
               where o.id::text = (storage.foldername(name))[2] and o.client_id = auth.uid())));
