-- Platform role for training people
create type public.platform_role as enum ('Trainee','Trainer','Supervisor','Manager');
create type public.account_status as enum ('active','suspended');
create type public.module_status as enum ('draft','published');

-- Tenants
create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_at timestamptz not null default now()
);
grant select on public.tenants to authenticated;
grant insert, update, delete on public.tenants to authenticated;
grant all on public.tenants to service_role;
alter table public.tenants enable row level security;
create policy "tenants_read_authenticated" on public.tenants
  for select to authenticated using (true);
create policy "tenants_super_admin_write" on public.tenants
  for all to authenticated
  using (public.has_role(auth.uid(), 'super_admin'))
  with check (public.has_role(auth.uid(), 'super_admin'));

-- Profile extensions
alter table public.profiles
  add column if not exists first_name text not null default '',
  add column if not exists last_name text not null default '',
  add column if not exists email text,
  add column if not exists platform_role public.platform_role not null default 'Trainee',
  add column if not exists status public.account_status not null default 'active',
  add column if not exists archived_at timestamptz;

create policy "profiles_super_admin_all" on public.profiles
  for all to authenticated
  using (public.has_role(auth.uid(), 'super_admin'))
  with check (public.has_role(auth.uid(), 'super_admin'));

-- Tenant membership
create table public.user_tenants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, tenant_id)
);
grant select, insert, update, delete on public.user_tenants to authenticated;
grant all on public.user_tenants to service_role;
alter table public.user_tenants enable row level security;
create policy "user_tenants_read_own" on public.user_tenants
  for select to authenticated using (user_id = auth.uid());
create policy "user_tenants_super_admin_all" on public.user_tenants
  for all to authenticated
  using (public.has_role(auth.uid(), 'super_admin'))
  with check (public.has_role(auth.uid(), 'super_admin'));

-- Authored training modules
create table public.training_modules (
  id uuid primary key default gen_random_uuid(),
  title text not null default 'Untitled module',
  description text not null default '',
  estimated_minutes integer not null default 15,
  content_html text not null default '',
  attachments jsonb not null default '[]'::jsonb,
  status public.module_status not null default 'draft',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on public.training_modules to authenticated;
grant all on public.training_modules to service_role;
alter table public.training_modules enable row level security;
create policy "training_modules_read_published" on public.training_modules
  for select to authenticated using (status = 'published');
create policy "training_modules_super_admin_all" on public.training_modules
  for all to authenticated
  using (public.has_role(auth.uid(), 'super_admin'))
  with check (public.has_role(auth.uid(), 'super_admin'));

create table public.module_tenants (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references public.training_modules(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  unique (module_id, tenant_id)
);
grant select, insert, update, delete on public.module_tenants to authenticated;
grant all on public.module_tenants to service_role;
alter table public.module_tenants enable row level security;
create policy "module_tenants_read_authenticated" on public.module_tenants
  for select to authenticated using (true);
create policy "module_tenants_super_admin_all" on public.module_tenants
  for all to authenticated
  using (public.has_role(auth.uid(), 'super_admin'))
  with check (public.has_role(auth.uid(), 'super_admin'));

-- Audit trail
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references auth.users(id) on delete set null,
  admin_email text not null default '',
  action text not null,
  target text not null default '',
  tenant_id uuid references public.tenants(id) on delete set null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
grant select on public.audit_logs to authenticated;
grant all on public.audit_logs to service_role;
alter table public.audit_logs enable row level security;
create policy "audit_logs_super_admin_read" on public.audit_logs
  for select to authenticated using (public.has_role(auth.uid(), 'super_admin'));

create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
revoke all on function public.touch_updated_at() from public;
revoke all on function public.touch_updated_at() from anon;

create trigger training_modules_touch
before update on public.training_modules
for each row execute function public.touch_updated_at();

insert into public.tenants (name, slug) values
  ('Solar Surge QLD', 'solar-surge-qld'),
  ('Solar Surge NSW', 'solar-surge-nsw'),
  ('Partner Network', 'partner-network');