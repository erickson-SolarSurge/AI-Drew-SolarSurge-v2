CREATE POLICY "live_sessions_management_delete_stale"
ON public.live_roleplay_sessions
FOR DELETE
TO authenticated
USING (
  public.has_management_access(auth.uid())
  AND last_seen_at < now() - interval '2 minutes'
);