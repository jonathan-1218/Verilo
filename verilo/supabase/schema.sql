-- Verilo backend schema. Run once in the Supabase SQL editor (Dashboard -> SQL Editor -> New query).
-- Mirrors lib/core/database.dart (drift/local cache) with owner_id scoping + RLS
-- so each authenticated user only ever sees their own rows.

create table if not exists public.projects (
  id bigint generated always as identity primary key,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 200),
  category text not null,
  location text not null,
  district text not null,
  state text not null,
  lat double precision,
  lng double precision,
  geofence_meters double precision not null default 500,
  sdg_tags text not null default '', -- JSON array, same encoding as drift column
  description text not null default '',
  budget_cents bigint not null default 0,
  start_date timestamptz,
  end_date timestamptz,
  review_interval text not null default 'Quarterly',
  status text not null default 'Active',
  implementing_agency text not null default '', -- '' = implemented directly
  csr_registration_no text not null default '',
  beneficiaries integer not null default 0,
  created_at timestamptz not null default now()
);

-- Migration for databases created before the CSR columns existed. Safe to
-- re-run; no-ops once the columns are present.
alter table public.projects add column if not exists implementing_agency text not null default '';
alter table public.projects add column if not exists csr_registration_no text not null default '';
alter table public.projects add column if not exists beneficiaries integer not null default 0;

create table if not exists public.visits (
  id bigint generated always as identity primary key,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  project_id bigint not null references public.projects (id) on delete cascade,
  officer_name text not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  start_lat double precision,
  start_lng double precision,
  gps_accuracy_meters double precision,
  notes text not null default '',
  status text not null default 'active', -- active | complete
  report_hash text,
  report_signature text -- "keyId:hmac" device seal of report_hash
);

-- idempotent upgrade for databases created before report_signature existed
alter table public.visits add column if not exists report_signature text;

create table if not exists public.photos (
  id bigint generated always as identity primary key,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  visit_id bigint not null references public.visits (id) on delete cascade,
  storage_path text, -- path in the "visit-media" storage bucket; null until uploaded
  lat double precision,
  lng double precision,
  accuracy_meters double precision,
  captured_at timestamptz not null default now()
);

create table if not exists public.voice_clips (
  id bigint generated always as identity primary key,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  visit_id bigint not null references public.visits (id) on delete cascade,
  storage_path text, -- path in the "visit-media" storage bucket; null until uploaded
  duration_seconds int not null default 0,
  transcript text not null default '',
  recorded_at timestamptz not null default now()
);

create table if not exists public.checklist_items (
  id bigint generated always as identity primary key,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  visit_id bigint not null references public.visits (id) on delete cascade,
  label text not null,
  completed boolean not null default false
);

-- ── Row level security: every user only sees/writes their own rows ──────────

alter table public.projects enable row level security;
alter table public.visits enable row level security;
alter table public.photos enable row level security;
alter table public.voice_clips enable row level security;
alter table public.checklist_items enable row level security;

-- Child tables also verify the parent row belongs to the caller. Plain FK
-- checks bypass RLS, so without this a hostile client could attach rows to
-- another user's project/visit ids (and use FK errors to enumerate which ids
-- exist).

drop policy if exists "owner_all" on public.projects;
create policy "owner_all" on public.projects for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists "owner_all" on public.visits;
create policy "owner_all" on public.visits for all
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    and project_id in (select id from public.projects where owner_id = auth.uid())
  );

drop policy if exists "owner_all" on public.photos;
create policy "owner_all" on public.photos for all
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    and visit_id in (select id from public.visits where owner_id = auth.uid())
  );

drop policy if exists "owner_all" on public.voice_clips;
create policy "owner_all" on public.voice_clips for all
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    and visit_id in (select id from public.visits where owner_id = auth.uid())
  );

drop policy if exists "owner_all" on public.checklist_items;
create policy "owner_all" on public.checklist_items for all
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    and visit_id in (select id from public.visits where owner_id = auth.uid())
  );

-- ── Storage bucket for photos + voice clips ──────────────────────────────────
-- Uploading the actual media files is not wired yet (app currently syncs
-- structured data only; media stays device-local). Bucket + policy left ready
-- for when that's built.

insert into storage.buckets (id, name, public)
values ('visit-media', 'visit-media', false)
on conflict (id) do nothing;

drop policy if exists "owner_media" on storage.objects;
create policy "owner_media" on storage.objects for all
  using (bucket_id = 'visit-media' and owner = auth.uid())
  with check (bucket_id = 'visit-media' and owner = auth.uid());
