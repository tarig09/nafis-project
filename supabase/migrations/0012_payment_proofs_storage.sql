-- إثباتات الدفع: صور فقط، حتى 2 ميغا، داخل مجلد {uid}/ للعميل. القراءة لصاحبها وللإدارة.
update storage.buckets
set file_size_limit = 2097152,
    allowed_mime_types = array['image/jpeg','image/png','image/webp']
where id = 'payment-proofs';

drop policy if exists pp_insert on storage.objects;
create policy pp_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'payment-proofs' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists pp_update on storage.objects;
create policy pp_update on storage.objects for update to authenticated
  using (bucket_id = 'payment-proofs' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists pp_select on storage.objects;
create policy pp_select on storage.objects for select to authenticated
  using (bucket_id = 'payment-proofs'
         and ((storage.foldername(name))[1] = auth.uid()::text or is_admin()));
