-- Storage buckets the app expects. On Lovable Cloud these were created outside the
-- migrations, so a fresh Supabase project needs them here. All are private: the app
-- hands out signed URLs, and the storage.objects policies in earlier migrations
-- decide who can read and write.
insert into storage.buckets (id, name, public, file_size_limit)
values
  ('call-recordings', 'call-recordings', false, 26214400), -- QA call uploads, 25 MB max
  ('campaign-docs', 'campaign-docs', false, null),
  ('module-media', 'module-media', false, null)
on conflict (id) do nothing;
