CREATE POLICY "module_media_read_authenticated"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'module-media');

CREATE POLICY "module_media_admin_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'module-media' AND public.has_role(auth.uid(), 'super_admin'));

CREATE POLICY "module_media_admin_update"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'module-media' AND public.has_role(auth.uid(), 'super_admin'))
  WITH CHECK (bucket_id = 'module-media' AND public.has_role(auth.uid(), 'super_admin'));

CREATE POLICY "module_media_admin_delete"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'module-media' AND public.has_role(auth.uid(), 'super_admin'));