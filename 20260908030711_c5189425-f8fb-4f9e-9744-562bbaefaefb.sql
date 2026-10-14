CREATE TABLE public.module_content (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  module_key text NOT NULL UNIQUE,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT ON public.module_content TO authenticated;
GRANT ALL ON public.module_content TO service_role;

ALTER TABLE public.module_content ENABLE ROW LEVEL SECURITY;

CREATE POLICY module_content_read_authenticated ON public.module_content
  FOR SELECT TO authenticated USING (true);

CREATE POLICY module_content_super_admin_all ON public.module_content
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::app_role));

CREATE TRIGGER module_content_touch
  BEFORE UPDATE ON public.module_content
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();