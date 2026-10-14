-- AI Drew: the call script a rep uses by default (Setter or Confirmer), set by super admins.
-- Reps can still switch in AI Drew for the day (setters cover confirm calls when someone's away).
alter table public.profiles
  add column if not exists call_role text
  check (call_role is null or call_role in ('setter', 'confirmer'));

comment on column public.profiles.call_role is
  'Default AI Drew call script: setter or confirmer (null = rep picks). Set in Admin > People.';
