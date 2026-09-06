create extension if not exists postgis;
create extension if not exists "uuid-ossp";

create type public.activity_visibility as enum ('private', 'circle', 'public');
create type public.circle_role as enum ('owner', 'member');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Journey360 member',
  avatar_url text,
  is_vip boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.circles (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  invite_code text unique,
  created_at timestamptz not null default now()
);

create table public.circle_members (
  circle_id uuid not null references public.circles(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.circle_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);

create table public.places (
  id uuid primary key default uuid_generate_v4(),
  circle_id uuid not null references public.circles(id) on delete cascade,
  name text not null,
  center geography(point, 4326) not null,
  radius_m integer not null default 150 check (radius_m > 0),
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.user_locations (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  location geography(point, 4326) not null,
  accuracy_m double precision,
  speed_mps double precision,
  heading double precision,
  altitude_m double precision,
  battery_percent integer check (battery_percent between 0 and 100),
  is_sharing boolean not null default true,
  activity text,
  updated_at timestamptz not null default now()
);

create table public.activities (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  activity_type text not null default 'workout',
  route geography(linestring, 4326),
  distance_m double precision not null default 0,
  duration_seconds integer not null default 0,
  elevation_gain_m double precision not null default 0,
  visibility public.activity_visibility not null default 'circle',
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.segments (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  route geography(linestring, 4326) not null,
  distance_m double precision not null default 0,
  created_at timestamptz not null default now()
);

create table public.segment_efforts (
  id uuid primary key default uuid_generate_v4(),
  segment_id uuid not null references public.segments(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  elapsed_seconds integer not null,
  created_at timestamptz not null default now(),
  unique (segment_id, activity_id)
);

create index user_locations_location_idx on public.user_locations using gist (location);
create index activities_route_idx on public.activities using gist (route);
create index segments_route_idx on public.segments using gist (route);
create index circle_members_user_idx on public.circle_members (user_id);

create or replace function public.is_circle_member(target_circle uuid, target_user uuid default auth.uid())
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.circle_members
    where circle_id = target_circle and user_id = target_user
  );
$$;

create or replace function public.match_activity_segments(activity_id uuid)
returns table (segment_id uuid, segment_name text, elapsed_seconds integer)
language sql
security invoker
stable
as $$
  select s.id, s.name, coalesce(e.elapsed_seconds, 0)
  from public.segments s
  join public.activities a on a.id = activity_id
  left join public.segment_efforts e on e.segment_id = s.id and e.activity_id = a.id
  where a.ended_at is not null
    and a.route is not null
    and st_dwithin(a.route, s.route, 15)
  order by coalesce(e.elapsed_seconds, 0) asc, s.name;
$$;

alter table public.profiles enable row level security;
alter table public.circles enable row level security;
alter table public.circle_members enable row level security;
alter table public.places enable row level security;
alter table public.user_locations enable row level security;
alter table public.activities enable row level security;
alter table public.segments enable row level security;
alter table public.segment_efforts enable row level security;

create policy "profiles are visible to signed in users" on public.profiles for select to authenticated using (true);
create policy "users update their profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy "members can read circles" on public.circles for select to authenticated using (public.is_circle_member(id));
create policy "members can read membership" on public.circle_members for select to authenticated using (public.is_circle_member(circle_id));
create policy "owners manage circles" on public.circles for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "members can read places" on public.places for select to authenticated using (public.is_circle_member(circle_id));
create policy "members manage places" on public.places for all to authenticated using (public.is_circle_member(circle_id, auth.uid()));

create policy "circle members read shared locations" on public.user_locations for select to authenticated
using (
  user_id = auth.uid() or exists (
    select 1 from public.circle_members mine
    join public.circle_members theirs on theirs.circle_id = mine.circle_id
    where mine.user_id = auth.uid() and theirs.user_id = user_locations.user_id
  )
);
create policy "users write own location" on public.user_locations for insert to authenticated with check (user_id = auth.uid());
create policy "users update own location" on public.user_locations for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "activities visible by setting" on public.activities for select to authenticated
using (
  user_id = auth.uid()
  or visibility = 'public'
  or (visibility = 'circle' and exists (
    select 1 from public.circle_members mine
    join public.circle_members theirs on theirs.circle_id = mine.circle_id
    where mine.user_id = auth.uid() and theirs.user_id = activities.user_id
  ))
);
create policy "users create activities" on public.activities for insert to authenticated with check (user_id = auth.uid());
create policy "users update own activities" on public.activities for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "segments are readable" on public.segments for select to authenticated using (true);
create policy "visible efforts are readable" on public.segment_efforts for select to authenticated
using (exists (select 1 from public.activities a where a.id = activity_id));
create policy "users create efforts" on public.segment_efforts for insert to authenticated with check (user_id = auth.uid());

alter publication supabase_realtime add table public.user_locations;
