-- Lead queue: admins load leads and assign them to reps; reps work them in AI Drew and
-- press "Wrap up & next lead". The outcome and call note of every attempt are kept.

create table if not exists public.lead_batches (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  call_role text not null default 'setter' check (call_role in ('setter', 'confirmer')),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.lead_batches (id) on delete cascade,
  assigned_to uuid references auth.users (id) on delete set null,
  position integer not null default 0,
  customer_name text not null,
  phone text not null default '',
  lead_details text not null default '',
  lead_source text check (lead_source is null or lead_source in ('cc', 'lead-ax', 'd2d')),
  -- The source exactly as the vendor wrote it (e.g. 'GB'), for admins.
  lead_source_raw text not null default '',
  territory text not null default '',
  address text not null default '',
  status text not null default 'queued'
    check (status in ('queued', 'in_progress', 'follow_up', 'done', 'archived')),
  attempts integer not null default 0,
  next_attempt_at timestamptz,
  outcome text,
  dq_reason text,
  note text,
  worked_by uuid references auth.users (id) on delete set null,
  wrapped_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists leads_queue_idx
  on public.leads (assigned_to, status, next_attempt_at, position);
create index if not exists leads_phone_idx on public.leads (phone);

create table if not exists public.lead_attempts (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.leads (id) on delete cascade,
  rep_id uuid references auth.users (id) on delete set null,
  outcome text not null,
  dq_reason text,
  note text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists lead_attempts_lead_idx on public.lead_attempts (lead_id, created_at);

alter table public.lead_batches enable row level security;
alter table public.leads enable row level security;
alter table public.lead_attempts enable row level security;

-- Reads only; every write goes through server functions (service role).
drop policy if exists "Management reads batches" on public.lead_batches;
create policy "Management reads batches"
  on public.lead_batches for select to authenticated
  using (public.has_management_access(auth.uid()));

drop policy if exists "Own or management leads" on public.leads;
create policy "Own or management leads"
  on public.leads for select to authenticated
  using (assigned_to = auth.uid() or public.has_management_access(auth.uid()));

drop policy if exists "Own or management attempts" on public.lead_attempts;
create policy "Own or management attempts"
  on public.lead_attempts for select to authenticated
  using (rep_id = auth.uid() or public.has_management_access(auth.uid()));

-- The rep's next lead, claimed atomically: a lead already in progress (resume), then a
-- follow-up that's due, then the next queued lead.
create or replace function public.claim_next_lead(_user_id uuid)
returns public.leads
language plpgsql
security definer
set search_path = public
as $$
declare
  picked public.leads;
begin
  select * into picked from public.leads
  where assigned_to = _user_id and status = 'in_progress'
  order by updated_at
  limit 1;
  if found then
    return picked;
  end if;

  select * into picked from public.leads
  where assigned_to = _user_id
    and (
      (status = 'follow_up' and next_attempt_at <= now())
      or status = 'queued'
    )
  order by
    case when status = 'follow_up' then 0 else 1 end,
    next_attempt_at nulls last,
    position,
    created_at
  limit 1
  for update skip locked;
  if not found then
    return null;
  end if;

  update public.leads
  set status = 'in_progress', updated_at = now()
  where id = picked.id
  returning * into picked;
  return picked;
end;
$$;

revoke all on function public.claim_next_lead(uuid) from public, anon, authenticated;
grant execute on function public.claim_next_lead(uuid) to service_role;
