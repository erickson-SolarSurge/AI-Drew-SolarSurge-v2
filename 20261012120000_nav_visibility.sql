-- Module access by role: super admins hide menu items (AI Drew, training modules, QA…)
-- from chosen platform roles. One row per item; no row = visible to everyone.
create table if not exists public.nav_visibility (
  item_key text primary key,
  hidden_roles public.platform_role[] not null default '{}',
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

alter table public.nav_visibility enable row level security;

-- Everyone signed in needs to read it to build their menu. Writes go through the
-- super-admin server function with the service role.
drop policy if exists "Signed-in users read module access" on public.nav_visibility;
create policy "Signed-in users read module access"
  on public.nav_visibility for select
  to authenticated
  using (true);
