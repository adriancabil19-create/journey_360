-- Journey360 backend contract.
-- Apply after migrations 001, 002, and 003.
-- This migration is additive and safe to run on an existing project.

-- Profile capability flags used by the app and VIP product rules.
alter table public.profiles
  add column if not exists username text,
  add column if not exists is_vip boolean not null default true;

-- The dedicated engine uses this table for high-frequency workout presence.
create table if not exists public.user_locations (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  accuracy_m double precision,
  speed_mps double precision,
  heading double precision,
  altitude_m double precision,
  battery_percent integer check (battery_percent between 0 and 100),
  is_sharing boolean not null default true,
  activity text,
  updated_at timestamptz not null default now()
);

-- Active workout records written by the dual-rate tracking engine.
create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  activity_type text not null default 'workout',
  route jsonb,
  distance_m double precision not null default 0,
  duration_seconds integer not null default 0,
  elevation_gain_m double precision not null default 0,
  avg_speed_mps double precision not null default 0,
  max_speed_mps double precision not null default 0,
  visibility text not null default 'circle'
    check (visibility in ('private', 'circle', 'public')),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists activities_user_started_idx
  on public.activities(user_id, started_at desc);

create table if not exists public.segments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  route jsonb not null,
  distance_m double precision not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.segment_efforts (
  id uuid primary key default gen_random_uuid(),
  segment_id uuid not null references public.segments(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  elapsed_seconds integer not null check (elapsed_seconds >= 0),
  created_at timestamptz not null default now(),
  unique (segment_id, activity_id)
);
create index if not exists segment_efforts_leaderboard_idx
  on public.segment_efforts(segment_id, elapsed_seconds);

create table if not exists public.notification_events (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  circle_id uuid references public.circles(id) on delete cascade,
  event_type text not null,
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notification_events_recipient_idx
  on public.notification_events(recipient_id, created_at desc);

-- Secure invite-code join. A non-member must not need SELECT access to discover
-- the circle row before joining it.
create or replace function public.join_circle(join_code text)
returns public.circles
language plpgsql
security definer
set search_path = public
as $$
declare
  target public.circles;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to join a circle';
  end if;

  select * into target
  from public.circles
  where invite_code = upper(trim(join_code))
    and (expires_at is null or expires_at > now())
  limit 1;

  if target.id is null then
    raise exception 'That invite code was not found or has expired';
  end if;

  insert into public.circle_members (circle_id, user_id, display_name, role)
  select target.id, auth.uid(), p.display_name, 'member'
  from public.profiles p
  where p.id = auth.uid()
  on conflict (circle_id, user_id) do nothing;

  return target;
end;
$$;
revoke all on function public.join_circle(text) from public;
grant execute on function public.join_circle(text) to authenticated;

-- Atomic circle creation for clients. Keep this definition here too so a
-- project can repair an earlier incomplete 003 migration by applying 004.
create or replace function public.create_circle(
  circle_name text,
  circle_type public.circle_type default 'permanent'
)
returns public.circles
language plpgsql
security definer
set search_path = public
as $$
declare
  created_circle public.circles;
  code text;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to create a circle';
  end if;
  if length(trim(circle_name)) < 1 then
    raise exception 'Circle name is required';
  end if;

  code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
  insert into public.circles (name, type, owner_id, invite_code)
  values (trim(circle_name), circle_type, auth.uid(), code)
  returning * into created_circle;

  insert into public.circle_members (circle_id, user_id, display_name, role)
  select created_circle.id, auth.uid(), p.display_name, 'owner'
  from public.profiles p
  where p.id = auth.uid()
  on conflict (circle_id, user_id) do nothing;

  return created_circle;
end;
$$;
revoke all on function public.create_circle(text, public.circle_type) from public;
grant execute on function public.create_circle(text, public.circle_type) to authenticated;

-- RLS -----------------------------------------------------------------------
alter table public.user_locations enable row level security;
alter table public.activities enable row level security;
alter table public.segments enable row level security;
alter table public.segment_efforts enable row level security;
alter table public.notification_events enable row level security;

 drop policy if exists "own user locations" on public.user_locations;
create policy "own user locations" on public.user_locations
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "circle members read user locations" on public.user_locations;
create policy "circle members read user locations" on public.user_locations
  for select to authenticated
  using (
    user_id = auth.uid() or exists (
      select 1 from public.circle_members mine
      join public.circle_members theirs on theirs.circle_id = mine.circle_id
      where mine.user_id = auth.uid() and theirs.user_id = user_locations.user_id
    )
  );

drop policy if exists "activity owners write" on public.activities;
create policy "activity owners write" on public.activities
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "activity visibility read" on public.activities;
create policy "activity visibility read" on public.activities
  for select to authenticated
  using (
    user_id = auth.uid()
    or visibility = 'public'
    or (visibility = 'circle' and exists (
      select 1 from public.circle_members mine
      join public.circle_members theirs on theirs.circle_id = mine.circle_id
      where mine.user_id = auth.uid() and theirs.user_id = activities.user_id
    ))
  );

drop policy if exists "segments readable" on public.segments;
create policy "segments readable" on public.segments
  for select to authenticated using (true);

drop policy if exists "effort owners write" on public.segment_efforts;
create policy "effort owners write" on public.segment_efforts
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "efforts readable" on public.segment_efforts;
create policy "efforts readable" on public.segment_efforts
  for select to authenticated using (true);

drop policy if exists "own notification events" on public.notification_events;
create policy "own notification events" on public.notification_events
  for select to authenticated using (recipient_id = auth.uid());
drop policy if exists "mark own notifications read" on public.notification_events;
create policy "mark own notifications read" on public.notification_events
  for update to authenticated
  using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());

-- Leaderboard query used by Insights.
create or replace function public.segment_leaderboard(target_segment uuid, result_limit integer default 20)
returns table (
  user_id uuid,
  display_name text,
  elapsed_seconds integer,
  rank bigint
)
language sql
security invoker
stable
as $$
  select e.user_id,
         coalesce(p.display_name, 'Journey360 member'),
         e.elapsed_seconds,
         dense_rank() over (order by e.elapsed_seconds asc)
  from public.segment_efforts e
  join public.profiles p on p.id = e.user_id
  where e.segment_id = target_segment
  order by e.elapsed_seconds asc
  limit greatest(result_limit, 1);
$$;
revoke all on function public.segment_leaderboard(uuid, integer) from public;
grant execute on function public.segment_leaderboard(uuid, integer) to authenticated;

-- Realtime for live locations and notification inboxes.
do $$ begin
  alter publication supabase_realtime add table public.user_locations;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.activities;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.notification_events;
exception when duplicate_object then null; end $$;
