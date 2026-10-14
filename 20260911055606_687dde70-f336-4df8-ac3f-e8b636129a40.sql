CREATE TABLE public.live_roleplay_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rep_id uuid NOT NULL,
  rep_name text NOT NULL DEFAULT 'Representative',
  persona_id text NOT NULL,
  persona_name text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'ended')),
  started_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.live_roleplay_sessions TO authenticated;
GRANT ALL ON public.live_roleplay_sessions TO service_role;
ALTER TABLE public.live_roleplay_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "live_sessions_rep_own" ON public.live_roleplay_sessions
  FOR ALL TO authenticated
  USING (rep_id = auth.uid())
  WITH CHECK (rep_id = auth.uid());
CREATE POLICY "live_sessions_management_read" ON public.live_roleplay_sessions
  FOR SELECT TO authenticated
  USING (public.has_management_access(auth.uid()));

CREATE TABLE public.live_roleplay_signals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.live_roleplay_sessions(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL,
  recipient_id uuid NOT NULL,
  signal_type text NOT NULL CHECK (signal_type IN ('listen', 'offer', 'answer', 'ice', 'leave')),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, DELETE ON public.live_roleplay_signals TO authenticated;
GRANT ALL ON public.live_roleplay_signals TO service_role;
ALTER TABLE public.live_roleplay_signals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "live_signals_read_recipient" ON public.live_roleplay_signals
  FOR SELECT TO authenticated
  USING (recipient_id = auth.uid());
CREATE POLICY "live_signals_insert_participant" ON public.live_roleplay_signals
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND (
      public.has_management_access(auth.uid())
      OR EXISTS (
        SELECT 1 FROM public.live_roleplay_sessions session
        WHERE session.id = session_id AND session.rep_id = auth.uid()
      )
    )
  );
CREATE POLICY "live_signals_delete_own" ON public.live_roleplay_signals
  FOR DELETE TO authenticated
  USING (recipient_id = auth.uid() OR sender_id = auth.uid());

CREATE INDEX live_roleplay_sessions_status_seen_idx
  ON public.live_roleplay_sessions(status, last_seen_at DESC);
CREATE INDEX live_roleplay_signals_recipient_created_idx
  ON public.live_roleplay_signals(recipient_id, created_at);

ALTER PUBLICATION supabase_realtime ADD TABLE public.live_roleplay_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.live_roleplay_signals;