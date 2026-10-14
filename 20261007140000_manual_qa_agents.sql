-- Agents added by QA staff by name only — people in the organisation who have
-- no email address and therefore no login. Recordings and coaching forms can be
-- assigned to one of these instead of a user account. Such agents can't sign in,
-- so their coaching forms are delivered offline (PDF) and are management-only.
CREATE TABLE public.qa_agents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name text NOT NULL CHECK (length(trim(full_name)) > 0),
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.qa_agents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "qa_agents_management_all" ON public.qa_agents
  FOR ALL TO authenticated
  USING (public.has_management_access(auth.uid()))
  WITH CHECK (public.has_management_access(auth.uid()));

-- A manual agent can't be deleted while recordings or forms still point at them.
ALTER TABLE public.call_recordings
  ADD COLUMN qa_agent_id uuid REFERENCES public.qa_agents(id) ON DELETE RESTRICT;

ALTER TABLE public.coaching_forms
  ADD COLUMN qa_agent_id uuid REFERENCES public.qa_agents(id) ON DELETE RESTRICT,
  ALTER COLUMN agent_id DROP NOT NULL,
  ADD CONSTRAINT coaching_forms_has_agent
    CHECK (agent_id IS NOT NULL OR qa_agent_id IS NOT NULL);

-- Reps still may only acknowledge and comment; also protect the new column.
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
     OR NEW.qa_agent_id IS DISTINCT FROM OLD.qa_agent_id
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
