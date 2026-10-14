-- Field rep booking calendar (AI Drew + Admin → Field reps).
-- Territories with a fixed capacity per interval, field reps with weekly rosters, and the
-- shared bookings setters make at the booking stage. Writes go through server functions.

create table if not exists public.territories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  timezone text not null default 'Australia/Brisbane',
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.territory_capacity (
  territory_id uuid not null references public.territories(id) on delete cascade,
  slot_time text not null check (slot_time in ('10:00', '14:00', '16:00', '18:00', '20:00')),
  capacity smallint not null default 4 check (capacity between 3 and 5),
  primary key (territory_id, slot_time)
);

create table if not exists public.field_reps (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  territory_id uuid not null references public.territories(id) on delete restrict,
  phone text,
  active boolean not null default true,
  -- {"mon":["10:00","14:00"],"tue":[...],...}: the intervals the rep works each day.
  schedule jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.field_bookings (
  id uuid primary key default gen_random_uuid(),
  field_rep_id uuid not null references public.field_reps(id) on delete cascade,
  territory_id uuid not null references public.territories(id) on delete cascade,
  slot_date date not null,
  slot_time text not null check (slot_time in ('10:00', '14:00', '16:00', '18:00', '20:00')),
  customer_name text,
  customer_address text,
  booked_by uuid references auth.users(id) on delete set null,
  booked_by_name text,
  status text not null default 'booked' check (status in ('booked', 'cancelled')),
  cancelled_by uuid references auth.users(id) on delete set null,
  cancelled_at timestamptz,
  created_at timestamptz not null default now()
);

-- One appointment per field rep per interval.
create unique index if not exists field_bookings_one_per_rep
  on public.field_bookings (field_rep_id, slot_date, slot_time)
  where status = 'booked';
create index if not exists field_bookings_slot
  on public.field_bookings (territory_id, slot_date, slot_time)
  where status = 'booked';

alter table public.territories enable row level security;
alter table public.territory_capacity enable row level security;
alter table public.field_reps enable row level security;
alter table public.field_bookings enable row level security;

drop policy if exists "Signed-in users read territories" on public.territories;
create policy "Signed-in users read territories"
  on public.territories for select to authenticated using (true);
drop policy if exists "Signed-in users read capacity" on public.territory_capacity;
create policy "Signed-in users read capacity"
  on public.territory_capacity for select to authenticated using (true);
drop policy if exists "Signed-in users read field reps" on public.field_reps;
create policy "Signed-in users read field reps"
  on public.field_reps for select to authenticated using (true);
-- Setters see their own bookings; management sees all. The calendar's counts come
-- from the server function, which hides other setters' customer details.
drop policy if exists "Own or management bookings" on public.field_bookings;
create policy "Own or management bookings"
  on public.field_bookings for select to authenticated
  using (booked_by = auth.uid() or public.has_management_access(auth.uid()));

-- Books one slot safely: a lock per territory/date/time stops two setters overbooking.
create or replace function public.book_field_slot(
  p_field_rep_id uuid,
  p_slot_date date,
  p_slot_time text,
  p_customer_name text,
  p_customer_address text,
  p_booked_by uuid,
  p_booked_by_name text
) returns public.field_bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  rep public.field_reps;
  cap smallint;
  taken integer;
  day_key text;
  booking public.field_bookings;
begin
  select * into rep from public.field_reps where id = p_field_rep_id and active;
  if not found then
    raise exception 'That field rep is not available.';
  end if;

  perform pg_advisory_xact_lock(hashtext(rep.territory_id::text || p_slot_date::text || p_slot_time));

  day_key := (array['mon','tue','wed','thu','fri','sat','sun'])[extract(isodow from p_slot_date)::int];
  if not coalesce(rep.schedule -> day_key ? p_slot_time, false) then
    raise exception '% is not rostered on at that time.', rep.full_name;
  end if;

  select coalesce(capacity, 4) into cap from public.territory_capacity
    where territory_id = rep.territory_id and slot_time = p_slot_time;
  cap := coalesce(cap, 4);
  select count(*) into taken from public.field_bookings
    where territory_id = rep.territory_id and slot_date = p_slot_date
      and slot_time = p_slot_time and status = 'booked';
  if taken >= cap then
    raise exception 'That slot is full (% of % booked).', taken, cap;
  end if;

  if exists (select 1 from public.field_bookings
             where field_rep_id = rep.id and slot_date = p_slot_date
               and slot_time = p_slot_time and status = 'booked') then
    raise exception '% already has an appointment at that time.', rep.full_name;
  end if;

  insert into public.field_bookings
    (field_rep_id, territory_id, slot_date, slot_time, customer_name, customer_address,
     booked_by, booked_by_name)
  values
    (rep.id, rep.territory_id, p_slot_date, p_slot_time, p_customer_name, p_customer_address,
     p_booked_by, p_booked_by_name)
  returning * into booking;
  return booking;
end;
$$;

revoke all on function public.book_field_slot(uuid, date, text, text, text, uuid, text) from public, anon, authenticated;
grant execute on function public.book_field_slot(uuid, date, text, text, text, uuid, text) to service_role;

-- Starting data (editable in Admin → Field reps).
insert into public.territories (name, timezone, sort_order) values
  ('SEQ', 'Australia/Brisbane', 1),
  ('WA', 'Australia/Perth', 2)
on conflict (name) do nothing;

insert into public.territory_capacity (territory_id, slot_time, capacity)
select t.id, s.slot_time, 4
from public.territories t
cross join (values ('10:00'), ('14:00'), ('16:00'), ('18:00'), ('20:00')) as s(slot_time)
on conflict do nothing;

insert into public.field_reps (full_name, territory_id, phone, schedule)
select v.full_name, t.id, v.phone, v.schedule::jsonb
from (values
  ('Ben Carter', 'SEQ', '0400 111 201',
   '{"mon":["10:00","14:00","16:00","18:00"],"tue":["10:00","14:00","16:00","18:00"],"wed":["14:00","16:00","18:00","20:00"],"thu":["10:00","14:00","16:00","18:00"],"fri":["10:00","14:00","16:00"],"sat":["10:00","14:00"]}'),
  ('Mia Thompson', 'SEQ', '0400 111 202',
   '{"mon":["14:00","16:00","18:00","20:00"],"tue":["14:00","16:00","18:00","20:00"],"wed":["10:00","14:00","16:00","18:00"],"thu":["14:00","16:00","18:00","20:00"],"fri":["14:00","16:00","18:00","20:00"],"sat":["10:00","14:00","16:00"]}'),
  ('Josh Nguyen', 'SEQ', '0400 111 203',
   '{"mon":["10:00","14:00","16:00"],"tue":["10:00","14:00","16:00","18:00","20:00"],"wed":["10:00","14:00","16:00"],"thu":["10:00","14:00","16:00","18:00","20:00"],"fri":["10:00","14:00","16:00","18:00"],"sat":["10:00","14:00","16:00"]}'),
  ('Hannah Walsh', 'WA', '0400 222 301',
   '{"mon":["10:00","14:00","16:00","18:00"],"tue":["10:00","14:00","16:00","18:00"],"wed":["10:00","14:00","16:00","18:00"],"thu":["14:00","16:00","18:00","20:00"],"fri":["10:00","14:00","16:00"],"sat":["10:00","14:00"]}'),
  ('Ryan Patel', 'WA', '0400 222 302',
   '{"mon":["14:00","16:00","18:00","20:00"],"tue":["10:00","14:00","16:00"],"wed":["14:00","16:00","18:00","20:00"],"thu":["10:00","14:00","16:00","18:00"],"fri":["14:00","16:00","18:00","20:00"],"sat":["10:00","14:00","16:00"]}')
) as v(full_name, territory, phone, schedule)
join public.territories t on t.name = v.territory
where not exists (select 1 from public.field_reps);
