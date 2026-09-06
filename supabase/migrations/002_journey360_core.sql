-- Journey360 core schema: unified journeys, live locations, places, settings and
-- a vehicles stub. Additive on top of 001_initial_schema.sql. Safe to re-run.
--
-- The legacy `trips` / `trip_route_points` tables from 001 remain in place but
-- are deprecated; the app now writes journeys here.

-- --- Enums ------------------------------------------------------------------

do $$ begin
  create type public.journey_type as enum
    ('walking', 'running', 'cycling', 'driving', 'other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.journey_visibility as enum
    ('private', 'circle', 'friends', 'public');
exception when duplicate_object then null; end $$;

-- --- User settings --------------------------------------------------------

create table if not exists public.user_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  theme_mode text not null default 'system',
  sharing_mode text not null default 'everyone',
  tracking_profile text not null default 'balanced',
  default_visibility public.journey_visibility not null default 'private',
  journey_alerts boolean not null default true,
  circle_alerts boolean not null default true,
  social_alerts boolean not null default false,
  auto_pause_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

-- --- Saved places (geofences) ------------------------------------------

create table if not exists public.places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  lat double precision not null,
  lng double precision not null,
  radius_m double precision not null default 150,
  created_at timestamptz not null default now()
);
create index if not exists places_user_id_idx on public.places(user_id);

-- --- Journeys ----------------------------------------------------------

create table if not exists public.journeys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  circle_id uuid references public.circles(id) on delete set null,
  type public.journey_type not null default 'other',
  title text,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  start_lat double precision,
  start_lng double precision,
  end_lat double precision,
  end_lng double precision,
  distance_m double precision not null default 0,
  duration_seconds integer not null default 0,
  moving_seconds integer not null default 0,
  avg_speed double precision not null default 0,
  max_speed double precision not null default 0,
  elevation_gain double precision not null default 0,
  calories double precision not null default 0,
  visibility public.journey_visibility not null default 'private',
  created_at timestamptz not null default now()
);
create index if not exists journeys_user_id_started_idx
  on public.journeys(user_id, started_at desc);
create index if not exists journeys_visibility_idx
  on public.journeys(visibility) where visibility <> 'private';

create table if not exists public.journey_points (
  id bigint generated always as identity primary key,
  journey_id uuid not null references public.journeys(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  altitude double precision,
  speed double precision,
  accuracy double precision,
  heading double precision,
  recorded_at timestamptz not null default now()
);
create index if not exists journey_points_journey_id_idx
  on public.journey_points(journey_id, recorded_at);

-- --- Live locations (one row per user) --------------------------------

create table if not exists public.locations (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  lat double precision,
  lng double precision,
  accuracy double precision,
  speed double precision,
  heading double precision,
  altitude double precision,
  battery_level integer check (battery_level between 0 and 100),
  is_sharing boolean not null default false,
  activity text,
  updated_at timestamptz not null default now()
);

-- --- Vehicles (stub for the next milestone) --------------------------

create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  type text,
  brand text,
  model text,
  year integer,
  license_plate text,
  image_url text,
  created_at timestamptz not null default now()
);
create index if not exists vehicles_user_id_idx on public.vehicles(user_id);

-- --- Row Level Security ---------------------------------------------

alter table public.user_settings enable row level security;
alter table public.places enable row level security;
alter table public.journeys enable row level security;
alter table public.journey_points enable row level security;
alter table public.locations enable row level security;
alter table public.vehicles enable row level security;

-- Helper already defined in 001: public.is_circle_member(uuid).

drop policy if exists "own settings" on public.user_settings;
create policy "own settings" on public.user_settings for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "own places" on public.places;
create policy "own places" on public.places for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "own vehicles" on public.vehicles;
create policy "own vehicles" on public.vehicles for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Journeys: owner has full control; others may read by visibility.
drop policy if exists "journey owner writes" on public.journeys;
create policy "journey owner writes" on public.journeys for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "journey visibility reads" on public.journeys;
create policy "journey visibility reads" on public.journeys for select to authenticated
  using (
    user_id = auth.uid()
    or visibility = 'public'
    or (visibility = 'circle' and circle_id is not null
        and public.is_circle_member(circle_id))
  );

drop policy if exists "journey points via parent" on public.journey_points;
create policy "journey points via parent" on public.journey_points for all to authenticated
  using (exists (
    select 1 from public.journeys j
    where j.id = journey_id and j.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.journeys j
    where j.id = journey_id and j.user_id = auth.uid()
  ));

-- Locations: you write your own row; circle co-members can read it.
drop policy if exists "own live location write" on public.locations;
create policy "own live location write" on public.locations for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "circle members read live location" on public.locations;
create policy "circle members read live location" on public.locations for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.circle_members me
      join public.circle_members them
        on them.circle_id = me.circle_id
      where me.user_id = auth.uid()
        and them.user_id = public.locations.user_id
    )
  );

-- --- New-user bootstrap: also seed settings + a locations row ---------

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', 'Journey member'))
  on conflict (id) do nothing;

  insert into public.user_settings (user_id) values (new.id)
  on conflict (user_id) do nothing;

  insert into public.locations (user_id) values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

-- Keep circle_members.display_name in step with the member's profile.
create or replace function public.sync_circle_member_name()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  select display_name into new.display_name
  from public.profiles where id = new.user_id;
  return new;
end;
$$;

drop trigger if exists circle_member_name on public.circle_members;
create trigger circle_member_name
  before insert on public.circle_members
  for each row execute procedure public.sync_circle_member_name();

-- --- Realtime -----------------------------------------------------

do $$ begin
  alter publication supabase_realtime add table public.journeys;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.locations;
exception when duplicate_object then null; end $$;

-- Backfill settings / locations for any existing users.
insert into public.user_settings (user_id)
  select id from public.profiles
  on conflict (user_id) do nothing;
insert into public.locations (user_id)
  select id from public.profiles
  on conflict (user_id) do nothing;
