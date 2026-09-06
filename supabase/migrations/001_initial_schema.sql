create extension if not exists pgcrypto;

create type public.circle_type as enum ('permanent', 'temporary');
create type public.member_role as enum ('owner', 'member');
create type public.trip_status as enum ('active', 'paused', 'completed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Journey member',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.circles (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type public.circle_type not null,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  description text,
  invite_code text not null unique,
  expires_at timestamptz,
  allow_sos boolean not null default true,
  allow_location_history boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.circle_members (
  circle_id uuid not null references public.circles(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  display_name text not null default 'Member',
  role public.member_role not null default 'member',
  current_lat double precision,
  current_lng double precision,
  current_address text,
  battery_level int check (battery_level between 0 and 100),
  is_sharing_location boolean not null default false,
  is_on_trip boolean not null default false,
  last_seen_at timestamptz,
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  circle_id uuid references public.circles(id) on delete set null,
  name text not null,
  status public.trip_status not null default 'active',
  start_time timestamptz not null default now(),
  end_time timestamptz,
  start_address text,
  end_address text,
  total_distance_km numeric(10, 3) not null default 0,
  duration_seconds int not null default 0,
  moving_time_seconds int not null default 0,
  stopped_time_seconds int not null default 0,
  avg_speed_kmh numeric(8, 2),
  max_speed_kmh numeric(8, 2),
  elevation_gain_m numeric(8, 2),
  elevation_loss_m numeric(8, 2),
  journey_score int check (journey_score between 0 and 100),
  score_consistency int check (score_consistency between 0 and 100),
  score_efficiency int check (score_efficiency between 0 and 100),
  score_safety int check (score_safety between 0 and 100),
  invite_code text unique,
  notes text,
  is_public boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.trip_route_points (
  id bigint generated always as identity primary key,
  trip_id uuid not null references public.trips(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  speed_kmh numeric(8, 2),
  elevation_m numeric(8, 2),
  recorded_at timestamptz not null default now()
);

create table public.sos_alerts (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  circle_id uuid not null references public.circles(id) on delete cascade,
  lat double precision,
  lng double precision,
  address text,
  message text not null default 'Emergency! I need help.',
  status text not null default 'active' check (status in ('active', 'resolved')),
  acknowledged_by uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.achievements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  description text,
  icon text,
  earned_at timestamptz not null default now(),
  trip_id uuid references public.trips(id) on delete set null
);

create index circle_members_circle_id_idx on public.circle_members(circle_id);
create index trips_user_id_start_time_idx on public.trips(user_id, start_time desc);
create index trip_route_points_trip_id_idx on public.trip_route_points(trip_id, recorded_at);
create index sos_alerts_circle_id_status_idx on public.sos_alerts(circle_id, status);

alter table public.profiles enable row level security;
alter table public.circles enable row level security;
alter table public.circle_members enable row level security;
alter table public.trips enable row level security;
alter table public.trip_route_points enable row level security;
alter table public.sos_alerts enable row level security;
alter table public.achievements enable row level security;

create or replace function public.is_circle_member(target_circle_id uuid) returns boolean
language sql security definer set search_path = public as $$
  select exists (select 1 from public.circle_members where circle_id = target_circle_id and user_id = auth.uid());
$$;

create policy "profiles are visible to signed-in users" on public.profiles for select to authenticated using (true);
create policy "users update their profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
create policy "circle members can read circles" on public.circles for select to authenticated using (public.is_circle_member(id));
create policy "owners create circles" on public.circles for insert to authenticated with check (owner_id = auth.uid());
create policy "owners update circles" on public.circles for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "members read membership" on public.circle_members for select to authenticated using (user_id = auth.uid() or public.is_circle_member(circle_id));
create policy "users update their location" on public.circle_members for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "trip owners manage trips" on public.trips for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "trip participants read routes" on public.trip_route_points for select to authenticated using (exists (select 1 from public.trips t where t.id = trip_id and t.user_id = auth.uid()));
create policy "trip owners write routes" on public.trip_route_points for insert to authenticated with check (exists (select 1 from public.trips t where t.id = trip_id and t.user_id = auth.uid()));
create policy "circle members read sos" on public.sos_alerts for select to authenticated using (sender_id = auth.uid() or exists (select 1 from public.circle_members m where m.circle_id = circle_id and m.user_id = auth.uid()));
create policy "users send sos" on public.sos_alerts for insert to authenticated with check (sender_id = auth.uid());
create policy "senders resolve sos" on public.sos_alerts for update to authenticated using (sender_id = auth.uid()) with check (sender_id = auth.uid());
create policy "users read achievements" on public.achievements for select to authenticated using (user_id = auth.uid());

insert into storage.buckets (id, name, public) values ('avatars', 'avatars', false) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('trip-exports', 'trip-exports', false) on conflict (id) do nothing;
create policy "users manage their avatar files" on storage.objects for all to authenticated using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text) with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "users read their trip exports" on storage.objects for select to authenticated using (bucket_id = 'trip-exports' and (storage.foldername(name))[1] = auth.uid()::text);

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name) values (new.id, coalesce(new.raw_user_meta_data->>'full_name', 'Journey member'));
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

alter publication supabase_realtime add table public.circle_members;
alter publication supabase_realtime add table public.sos_alerts;
