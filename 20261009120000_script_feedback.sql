-- Reps rate the playbook scripts they use ("Did this help?") and suggest changes.
-- Super admins review everything in the control centre to plan LMS updates.
CREATE TABLE public.script_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  -- A playbook objection id (e.g. "talk-to-partner"), or "step:<id>" for a call step.
  script_id text NOT NULL CHECK (length(script_id) BETWEEN 1 AND 80),
  surface text NOT NULL CHECK (surface IN ('dojo', 'finder', 'calling', 'practice')),
  helpful boolean,
  suggestion text CHECK (suggestion IS NULL OR length(suggestion) <= 1000),
  status text NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'reviewed', 'actioned')),
  admin_note text CHECK (admin_note IS NULL OR length(admin_note) <= 1000),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT script_feedback_has_content CHECK (helpful IS NOT NULL OR suggestion IS NOT NULL)
);

CREATE INDEX script_feedback_script_idx ON public.script_feedback (script_id, created_at DESC);

ALTER TABLE public.script_feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY "script_feedback_insert_own" ON public.script_feedback
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND status = 'new' AND admin_note IS NULL);

CREATE POLICY "script_feedback_select_own_or_admin" ON public.script_feedback
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'super_admin'));

CREATE POLICY "script_feedback_admin_update" ON public.script_feedback
  FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'));
