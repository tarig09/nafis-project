-- رفع صور المنشورات: صور فقط، حتى 2 ميغا، وكل مستخدم يرفع داخل مجلده {uid}/
update storage.buckets
set file_size_limit = 2097152,
    allowed_mime_types = array['image/jpeg','image/png','image/webp']
where id = 'post-images';

create policy post_images_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'post-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy post_images_delete on storage.objects for delete to authenticated
  using (bucket_id = 'post-images' and (storage.foldername(name))[1] = auth.uid()::text);
-- القراءة عامة لأن الحاوية Public.
