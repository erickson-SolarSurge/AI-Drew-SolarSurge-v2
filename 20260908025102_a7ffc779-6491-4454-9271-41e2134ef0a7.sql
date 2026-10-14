ALTER TABLE public.training_modules
  ADD COLUMN IF NOT EXISTS module_key text,
  ADD COLUMN IF NOT EXISTS sort_order integer NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS cover_image_url text NOT NULL DEFAULT '';

CREATE UNIQUE INDEX IF NOT EXISTS training_modules_module_key_uidx
  ON public.training_modules (module_key) WHERE module_key IS NOT NULL;

INSERT INTO public.training_modules (module_key, title, description, estimated_minutes, content_html, status, sort_order)
VALUES
  ('mission', 'Mission Brief', 'Value props and the talk tracks that win on the QLD desk.', 15, '', 'published', 1),
  ('calling', 'Cold Calling Masterclass', 'Pattern interrupts, lead filter and the rebuttal engine.', 25, '', 'published', 2),
  ('roof', 'QLD Satellite Roof Inspector', 'Satellite recon, panel sandbox and system sizing HUD.', 20, '', 'published', 3),
  ('roleplay', 'Live Roleplay Cockpit', 'Practice calls with the AI customer and live script assist.', 30, '', 'published', 4),
  ('nesting', 'Nesting Roadmap', 'Your first three days on the live outbound desk.', 15, '', 'published', 5),
  ('exam', 'Certification Exam', 'Five questions between you and the floor.', 10, '', 'published', 6)
ON CONFLICT DO NOTHING;