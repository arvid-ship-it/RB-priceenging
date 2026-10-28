-- Rose & Born · MTM Body Measurements · customer photos
-- Paste into Supabase → SQL Editor → Run. Safe to run again.

-- 1. Metadata table (one row per photo)
create table if not exists public.customer_photos (
  id          uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  set_id      uuid references public.measurement_sets(id) on delete set null,
  order_id    uuid,                                  -- for later: orders
  path        text not null,                         -- object path in the customer-photos bucket
  tag         text,                                  -- Front / Side / Back / Fitting / Other
  taken_at    date not null default current_date,
  taken_by    text,
  created_at  timestamptz not null default now(),
  created_by  uuid references auth.users(id)
);
create index if not exists customer_photos_customer_idx on public.customer_photos (customer_id, taken_at desc);

alter table public.customer_photos enable row level security;
drop policy if exists "staff select photos" on public.customer_photos;
drop policy if exists "staff insert photos" on public.customer_photos;
drop policy if exists "staff update photos" on public.customer_photos;
drop policy if exists "staff delete photos" on public.customer_photos;
create policy "staff select photos" on public.customer_photos for select to authenticated using (true);
create policy "staff insert photos" on public.customer_photos for insert to authenticated with check (true);
create policy "staff update photos" on public.customer_photos for update to authenticated using (true) with check (true);
create policy "staff delete photos" on public.customer_photos for delete to authenticated using (true);

-- 2. Private storage bucket (files are only reachable through short-lived signed links)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('customer-photos', 'customer-photos', false, 10485760, array['image/jpeg','image/png','image/webp','image/heic'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- 3. Storage access: signed-in staff can read, add and remove files in this bucket
drop policy if exists "staff read customer photos" on storage.objects;
drop policy if exists "staff upload customer photos" on storage.objects;
drop policy if exists "staff update customer photos" on storage.objects;
drop policy if exists "staff delete customer photos" on storage.objects;
create policy "staff read customer photos"   on storage.objects for select to authenticated using (bucket_id = 'customer-photos');
create policy "staff upload customer photos" on storage.objects for insert to authenticated with check (bucket_id = 'customer-photos');
create policy "staff update customer photos" on storage.objects for update to authenticated using (bucket_id = 'customer-photos');
create policy "staff delete customer photos" on storage.objects for delete to authenticated using (bucket_id = 'customer-photos');
