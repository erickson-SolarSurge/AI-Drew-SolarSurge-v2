CREATE POLICY "recordings_files_management" ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'call-recordings' AND public.has_management_access(auth.uid()))
  WITH CHECK (bucket_id = 'call-recordings' AND public.has_management_access(auth.uid()));

CREATE POLICY "recordings_files_rep_read_own" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'call-recordings'
    AND EXISTS (
      SELECT 1 FROM public.call_recordings r
      WHERE r.storage_path = storage.objects.name AND r.agent_id = auth.uid()
    )
  );

CREATE POLICY "campaign_docs_management" ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'campaign-docs' AND public.has_management_access(auth.uid()))
  WITH CHECK (bucket_id = 'campaign-docs' AND public.has_management_access(auth.uid()));