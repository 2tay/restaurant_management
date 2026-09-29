-- Photo storage (SYNC_PLAN.md, Phase 3, step 3.7).
--
-- One private bucket, one folder per store: `<store_id>/items/<file>` and
-- `<store_id>/employees/<file>`. The same rule as the tables: a member can
-- read and write the folders of their organization's stores, nothing else.
-- The app starts using it in Phase 8.

insert into storage.buckets (id, name, public, file_size_limit,
  allowed_mime_types)
values ('photos', 'photos', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp']);

create policy photos_read on storage.objects for select to authenticated
  using (bucket_id = 'photos'
         and private.can_access_store((storage.foldername(name))[1]));

create policy photos_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'photos'
              and private.can_access_store((storage.foldername(name))[1]));

create policy photos_update on storage.objects for update to authenticated
  using (bucket_id = 'photos'
         and private.can_access_store((storage.foldername(name))[1]));

create policy photos_delete on storage.objects for delete to authenticated
  using (bucket_id = 'photos'
         and private.can_access_store((storage.foldername(name))[1]));
