-- Documents a QA reviewer attaches to one coaching form (e.g. a call-specific
-- script or customer note). The AI reads their text only when writing that
-- form's coaching. Files live in the private campaign-docs bucket, which only
-- management can access; reps never see these.
CREATE TABLE public.coaching_form_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id uuid NOT NULL REFERENCES public.coaching_forms(id) ON DELETE CASCADE,
  title text NOT NULL,
  file_name text NOT NULL DEFAULT '',
  storage_path text NOT NULL DEFAULT '',
  extracted_text text NOT NULL DEFAULT '',
  uploaded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX coaching_form_attachments_form_id_idx
  ON public.coaching_form_attachments (form_id);

ALTER TABLE public.coaching_form_attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "form_attachments_management_all" ON public.coaching_form_attachments
  FOR ALL TO authenticated
  USING (public.has_management_access(auth.uid()))
  WITH CHECK (public.has_management_access(auth.uid()));
