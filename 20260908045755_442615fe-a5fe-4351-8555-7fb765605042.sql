-- 1. Roles / access
ALTER TYPE public.platform_role RENAME VALUE 'Trainee' TO 'Representative';

CREATE TYPE public.access_level AS ENUM ('View', 'Read', 'Write');
CREATE TYPE public.campaign AS ENUM ('Outbound', 'Inbound', 'Mix', 'Technical Support', 'Customer Chat Support');
CREATE TYPE public.doc_type AS ENUM ('Script', 'Rebuttal Sheet', 'QA Guidelines');
CREATE TYPE public.coaching_status AS ENUM ('Draft', 'Finalized', 'Sent', 'Acknowledged');
CREATE TYPE public.transcript_status AS ENUM ('pending', 'processing', 'ready', 'failed');

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS access_level public.access_level NOT NULL DEFAULT 'View',
  ADD COLUMN IF NOT EXISTS campaigns text[] NOT NULL DEFAULT '{}';

CREATE OR REPLACE FUNCTION public.has_management_access(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = 'super_admin'
  ) OR EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = _user_id AND platform_role IN ('Manager', 'Supervisor', 'Trainer')
  );
$$;

REVOKE EXECUTE ON FUNCTION public.has_management_access(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.has_management_access(uuid) TO authenticated, service_role;

-- 2. Campaign documents
CREATE TABLE public.campaign_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  campaign public.campaign NOT NULL,
  doc_type public.doc_type NOT NULL,
  storage_path text NOT NULL,
  file_name text NOT NULL DEFAULT '',
  extracted_text text NOT NULL DEFAULT '',
  uploaded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.campaign_documents TO authenticated;
GRANT ALL ON public.campaign_documents TO service_role;
ALTER TABLE public.campaign_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "docs_read_all_signed_in" ON public.campaign_documents
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "docs_write_management" ON public.campaign_documents
  FOR ALL TO authenticated
  USING (public.has_management_access(auth.uid()))
  WITH CHECK (public.has_management_access(auth.uid()));

CREATE TRIGGER campaign_documents_touch BEFORE UPDATE ON public.campaign_documents
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- 3. Call recordings
CREATE TABLE public.call_recordings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL DEFAULT '',
  agent_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  campaign public.campaign NOT NULL DEFAULT 'Outbound',
  storage_path text NOT NULL,
  file_name text NOT NULL DEFAULT '',
  duration_seconds integer NOT NULL DEFAULT 0,
  transcript jsonb NOT NULL DEFAULT '[]'::jsonb,
  transcript_status public.transcript_status NOT NULL DEFAULT 'pending',
  transcript_error text,
  uploaded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.call_recordings TO authenticated;
GRANT ALL ON public.call_recordings TO service_role;
ALTER TABLE public.call_recordings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "recordings_management_all" ON public.call_recordings
  FOR ALL TO authenticated
  USING (public.has_management_access(auth.uid()))
  WITH CHECK (public.has_management_access(auth.uid()));
CREATE POLICY "recordings_rep_read_own" ON public.call_recordings
  FOR SELECT TO authenticated USING (agent_id = auth.uid());

CREATE TRIGGER call_recordings_touch BEFORE UPDATE ON public.call_recordings
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- 4. Coaching forms
CREATE TABLE public.coaching_forms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recording_id uuid REFERENCES public.call_recordings(id) ON DELETE SET NULL,
  agent_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  supervisor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  manager_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  campaign public.campaign NOT NULL DEFAULT 'Outbound',
  date_observed date,
  date_coached date,
  qa_score integer NOT NULL DEFAULT 0,
  summary text NOT NULL DEFAULT '',
  successes text NOT NULL DEFAULT '',
  opportunities text NOT NULL DEFAULT '',
  actionable_steps text NOT NULL DEFAULT '',
  deviations jsonb NOT NULL DEFAULT '[]'::jsonb,
  status public.coaching_status NOT NULL DEFAULT 'Draft',
  acknowledged_at timestamptz,
  rep_comments text,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.coaching_forms TO authenticated;
GRANT ALL ON public.coaching_forms TO service_role;
ALTER TABLE public.coaching_forms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "forms_management_all" ON public.coaching_forms
  FOR ALL TO authenticated
  USING (public.has_management_access(auth.uid()))
  WITH CHECK (public.has_management_access(auth.uid()));
CREATE POLICY "forms_rep_read_own" ON public.coaching_forms
  FOR SELECT TO authenticated
  USING (agent_id = auth.uid() AND status IN ('Sent', 'Acknowledged'));
CREATE POLICY "forms_rep_sign_own" ON public.coaching_forms
  FOR UPDATE TO authenticated
  USING (agent_id = auth.uid() AND status IN ('Sent', 'Acknowledged'))
  WITH CHECK (agent_id = auth.uid() AND status IN ('Sent', 'Acknowledged'));

CREATE TRIGGER coaching_forms_touch BEFORE UPDATE ON public.coaching_forms
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Representatives may only alter their sign-off fields
CREATE OR REPLACE FUNCTION public.guard_rep_coaching_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.has_management_access(auth.uid()) OR auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.agent_id IS DISTINCT FROM OLD.agent_id
     OR NEW.recording_id IS DISTINCT FROM OLD.recording_id
     OR NEW.supervisor_id IS DISTINCT FROM OLD.supervisor_id
     OR NEW.manager_id IS DISTINCT FROM OLD.manager_id
     OR NEW.qa_score IS DISTINCT FROM OLD.qa_score
     OR NEW.summary IS DISTINCT FROM OLD.summary
     OR NEW.successes IS DISTINCT FROM OLD.successes
     OR NEW.opportunities IS DISTINCT FROM OLD.opportunities
     OR NEW.actionable_steps IS DISTINCT FROM OLD.actionable_steps
     OR NEW.deviations IS DISTINCT FROM OLD.deviations
     OR NEW.campaign IS DISTINCT FROM OLD.campaign
     OR NEW.date_observed IS DISTINCT FROM OLD.date_observed
     OR NEW.date_coached IS DISTINCT FROM OLD.date_coached THEN
    RAISE EXCEPTION 'Representatives may only acknowledge and comment on their coaching form';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER coaching_forms_rep_guard BEFORE UPDATE ON public.coaching_forms
  FOR EACH ROW EXECUTE FUNCTION public.guard_rep_coaching_update();

-- 5. Notifications
CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  message text NOT NULL DEFAULT '',
  link_url text NOT NULL DEFAULT '',
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX notifications_user_idx ON public.notifications (user_id, created_at DESC);

GRANT SELECT, UPDATE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_read_own" ON public.notifications
  FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "notifications_update_own" ON public.notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;