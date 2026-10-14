-- Coaching forms now record which kind of rep was observed (Appointment Setter or
-- Confirmer: each is scored against its own official protocol) and the AI's
-- qualification result: a per-question checklist plus a Qualified / Not qualified verdict.
ALTER TABLE public.coaching_forms
  ADD COLUMN rep_type text NOT NULL DEFAULT 'setter'
    CHECK (rep_type IN ('setter', 'confirmer')),
  ADD COLUMN qualification jsonb;

-- Reps still may only acknowledge and comment; also protect the new columns.
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
     OR NEW.date_coached IS DISTINCT FROM OLD.date_coached
     OR NEW.rep_type IS DISTINCT FROM OLD.rep_type
     OR NEW.qualification IS DISTINCT FROM OLD.qualification THEN
    RAISE EXCEPTION 'Representatives may only acknowledge and comment on their coaching form';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.guard_rep_coaching_update() FROM anon, authenticated, public;
