-- Journey360 final backend hardening.
-- Apply after migrations 001 through 004.
-- Safe to rerun: all schema changes are additive and policies/functions replace
-- their named predecessors without deleting user data.

-- Ensure every feature column exists even when an older partial migration ran.
alter table public.profiles
  add column if not exists username text,
  add column if not exists is_vip boolean not null default true;

alter table public.user_settings
  add column if not exists theme_mode text not null default 'system',
  add column if not exists sharing_mode text not null default 'everyone',
  add column if not exists tracking_profile text not null default 'balanced',
  add column if not exists default_visibility text not null default 'private',
  add column if not exists journey_alerts boolean not null default true,
  add column if not exists circle_alerts boolean not null default true,
  add column if not exists social_alerts boolean not null default false,
  add column if not exists auto_pause_enabled boolean not null default true,
  add column if not exists low_battery_alerts boolean not null default true,
  add column if not exists safe_drive_alerts boolean not null default true,
  add column if not exists place_alerts boolean not null default true,
  add column if not exists updated_at timestamptz not null default now();

alter table public.user_locations
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists accuracy_m double precision,
  add column if not exists speed_mps double precision,
  add column if not exists heading double precision,
  add column if not exists altitude_m double precision,
  add column if not exists battery_percent integer,
  add column if not exists is_sharing boolean not null default true,
  add column if not exists activity text,
  add column if not exists updated_at timestamptz not null default now();

alter table public.activities
  add column if not exists activity_type text not null default 'workout',
  add column if not exists route jsonb,
  add column if not exists distance_m double precision not null default 0,
  add column if not exists duration_seconds integer not null default 0,
  add column if not exists elevation_gain_m double precision not null default 0,
  add column if not exists avg_speed_mps double precision not null default 0,
  add column if not exists max_speed_mps double precision not null default 0,
  add column if not exists visibility text not null default 'circle',
  add column if not exists started_at timestamptz not null default now(),
  add column if not exists ended_at timestamptz,
  add column if not exists created_at timestamptz not null default now();

-- Timestamp maintenance for rows written by clients.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute procedure public.touch_updated_at();

drop trigger if exists user_settings_touch_updated_at on public.user_settings;
create trigger user_settings_touch_updated_at
before update on public.user_settings
for each row execute procedure public.touch_updated_at();

drop trigger if exists user_locations_touch_updated_at on public.user_locations;
create trigger user_locations_touch_updated_at
before update on public.user_locations
for each row execute procedure public.touch_updated_at();

-- Keep new accounts complete even if the original auth trigger was missing.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, username, is_vip)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'full_name', ''), 'Journey360 member'),
    nullif(new.raw_user_meta_data->>'username', ''),
    true
  )
  on conflict (id) do update set
    display_name = coalesce(nullif(excluded.display_name, ''), profiles.display_name),
    username = coalesce(excluded.username, profiles.username);

  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  insert into public.locations (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

-- Notification inbox helpers. Events are server-created; users can only mark
-- their own events read or remove their own inbox rows.
create or replace function public.mark_notification_read(notification_id uuid)
returns void
language sql
security invoker
as $$
  update public.notification_events
  set read_at = coalesce(read_at, now())
  where id = notification_id and recipient_id = auth.uid();
$$;
revoke all on function public.mark_notification_read(uuid) from public;
grant execute on function public.mark_notification_read(uuid) to authenticated;

drop policy if exists "delete own notification events" on public.notification_events;
create policy "delete own notification events" on public.notification_events
for delete to authenticated using (recipient_id = auth.uid());

-- Useful indexes for all live and history screens.
create index if not exists user_locations_updated_idx
  on public.user_locations(updated_at desc);
create index if not exists activities_visibility_started_idx
  on public.activities(visibility, started_at desc);
create index if not exists places_created_idx
  on public.places(user_id, created_at desc);
create index if not exists notification_unread_idx
  on public.notification_events(recipient_id, created_at desc)
  where read_at is null;

-- Make sure all active realtime tables are present. Duplicate publication
-- entries are harmlessly ignored by the exception blocks.
do $$ begin
  alter publication supabase_realtime add table public.locations;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.user_locations;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.activities;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.notification_events;
exception when duplicate_object then null; end $$;
