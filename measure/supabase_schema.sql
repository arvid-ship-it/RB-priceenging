-- Rose & Born · MTM Body Measurements · Supabase schema
-- Paste the whole file into Supabase → SQL Editor → Run. Safe to run again (idempotent).

create extension if not exists pgcrypto;

-- One row per customer
create table if not exists public.customers (
  id          uuid primary key default gen_random_uuid(),
  first_name  text not null default '',
  last_name   text not null default '',
  email       text,
  phone       text,
  store       text,                      -- Stockholm / Zürich / New York
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  created_by  uuid references auth.users(id),
  updated_by  uuid references auth.users(id)
);

-- One row per measuring session (a customer can have many over the years)
create table if not exists public.measurement_sets (
  id           uuid primary key default gen_random_uuid(),
  customer_id  uuid not null references public.customers(id) on delete cascade,
  measured_at  date not null default current_date,
  measured_by  text,
  reference    text,
  height_cm    numeric,
  weight_kg    numeric,
  age          integer,
  profile      jsonb not null default '{}'::jsonb,   -- fits, body / stomach / back / shoulder / rear type
  measures     jsonb not null default '{}'::jsonb,   -- the 16 measurements in cm
  sizes        jsonb not null default '{}'::jsonb,   -- off-the-rack sizes
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  created_by   uuid references auth.users(id),
  updated_by   uuid references auth.users(id)
);

create index if not exists customers_name_idx on public.customers (lower(last_name), lower(first_name));
create index if not exists customers_updated_idx on public.customers (updated_at desc);
create index if not exists sets_customer_idx on public.measurement_sets (customer_id, measured_at desc);

-- Keep updated_at current
create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists customers_set_updated_at on public.customers;
create trigger customers_set_updated_at before update on public.customers
  for each row execute function public.set_updated_at();

drop trigger if exists sets_set_updated_at on public.measurement_sets;
create trigger sets_set_updated_at before update on public.measurement_sets
  for each row execute function public.set_updated_at();

-- Row Level Security: only signed-in staff, and all staff see all customers (one company)
alter table public.customers enable row level security;
alter table public.measurement_sets enable row level security;

drop policy if exists "staff select customers" on public.customers;
drop policy if exists "staff insert customers" on public.customers;
drop policy if exists "staff update customers" on public.customers;
drop policy if exists "staff delete customers" on public.customers;
create policy "staff select customers" on public.customers for select to authenticated using (true);
create policy "staff insert customers" on public.customers for insert to authenticated with check (true);
create policy "staff update customers" on public.customers for update to authenticated using (true) with check (true);
create policy "staff delete customers" on public.customers for delete to authenticated using (true);

drop policy if exists "staff select sets" on public.measurement_sets;
drop policy if exists "staff insert sets" on public.measurement_sets;
drop policy if exists "staff update sets" on public.measurement_sets;
drop policy if exists "staff delete sets" on public.measurement_sets;
create policy "staff select sets" on public.measurement_sets for select to authenticated using (true);
create policy "staff insert sets" on public.measurement_sets for insert to authenticated with check (true);
create policy "staff update sets" on public.measurement_sets for update to authenticated using (true) with check (true);
create policy "staff delete sets" on public.measurement_sets for delete to authenticated using (true);

-- Latest measuring session per customer, used by the customer list
create or replace view public.customers_overview
with (security_invoker = true) as
select c.*,
       s.measured_at as last_measured_at,
       s.measured_by as last_measured_by,
       (select count(*) from public.measurement_sets x where x.customer_id = c.id) as set_count
from public.customers c
left join lateral (
  select measured_at, measured_by from public.measurement_sets m
  where m.customer_id = c.id order by measured_at desc, created_at desc limit 1
) s on true;

grant select on public.customers_overview to authenticated;
