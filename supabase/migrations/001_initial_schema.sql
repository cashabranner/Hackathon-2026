-- FuelWindow Supabase Schema
-- Run via: supabase db push (or paste into SQL Editor)

-- ─── Enable UUID extension ─────────────────────────────────────────────────
create extension if not exists "pgcrypto";

-- ─── Profiles ──────────────────────────────────────────────────────────────
create table if not exists profiles (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid references auth.users(id) on delete cascade,
  name          text not null default '',
  age_years     int  not null,
  sex           text not null check (sex in ('male','female')),
  height_cm     numeric not null,
  weight_kg     numeric not null,
  activity_baseline text not null check (
    activity_baseline in (
      'sedentary','lightlyActive','moderatelyActive','veryActive','extraActive'
    )
  ),
  allergies     text[] not null default '{}',
  uses_glp1     boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
alter table profiles enable row level security;
create policy "Users own their profile" on profiles
  for all using (auth.uid() = user_id);

-- ─── Food logs ─────────────────────────────────────────────────────────────
create table if not exists food_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade,
  raw_input   text not null,
  logged_at   timestamptz not null,
  source      text not null default 'local_fallback',
  -- Nutrition (flattened for query performance)
  food_name   text not null,
  grams       numeric not null,
  carbs_g     numeric not null,
  glucose_g   numeric not null,
  fructose_g  numeric not null,
  fiber_g     numeric not null,
  protein_g   numeric not null,
  fat_g       numeric not null,
  calories    numeric not null,
  -- Micros
  magnesium_mg  numeric default 0,
  potassium_mg  numeric default 0,
  sodium_mg     numeric default 0,
  iron_mg       numeric default 0,
  zinc_mg       numeric default 0,
  b12_mcg       numeric default 0,
  vitamin_d_iu  numeric default 0,
  -- Absorption flags
  is_high_fat   boolean default false,
  is_high_fiber boolean default false,
  created_at  timestamptz not null default now()
);
create index food_logs_user_day on food_logs (user_id, logged_at);
alter table food_logs enable row level security;
create policy "Users own their food logs" on food_logs
  for all using (auth.uid() = user_id);

-- ─── Training sessions ──────────────────────────────────────────────────────
create table if not exists training_sessions (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid references auth.users(id) on delete cascade,
  session_type      text not null,
  planned_at        timestamptz not null,
  duration_minutes  int not null,
  intensity         text not null check (
    intensity in ('low','moderate','high','maximal')
  ),
  notes             text,
  created_at        timestamptz not null default now()
);
create index sessions_user_time on training_sessions (user_id, planned_at);
alter table training_sessions enable row level security;
create policy "Users own their sessions" on training_sessions
  for all using (auth.uid() = user_id);

-- ─── Metabolic snapshots (cached state per sync) ────────────────────────────
create table if not exists metabolic_snapshots (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid references auth.users(id) on delete cascade,
  snapshot_at       timestamptz not null,
  liver_glycogen_g  numeric not null,
  muscle_glycogen_g numeric not null,
  blood_glucose_phase text not null,
  total_carbs_g     numeric not null default 0,
  total_protein_g   numeric not null default 0,
  total_fat_g       numeric not null default 0,
  total_calories    numeric not null default 0,
  total_fiber_g     numeric not null default 0,
  created_at        timestamptz not null default now()
);
create index snapshots_user_time on metabolic_snapshots (user_id, snapshot_at desc);
alter table metabolic_snapshots enable row level security;
create policy "Users own their snapshots" on metabolic_snapshots
  for all using (auth.uid() = user_id);

-- ─── Cached explanations (avoid re-running LLM for same scenario) ──────────
create table if not exists cached_explanations (
  id            uuid primary key default gen_random_uuid(),
  cache_key     text not null unique,   -- hash of (user_id, session_type, timing, liver_pct, muscle_pct)
  explanation   text not null,
  generated_at  timestamptz not null default now(),
  expires_at    timestamptz not null default now() + interval '7 days'
);
-- Public read for demo; in prod, scope to user
alter table cached_explanations enable row level security;
create policy "Anyone can read unexpired explanations" on cached_explanations
  for select using (expires_at > now());
