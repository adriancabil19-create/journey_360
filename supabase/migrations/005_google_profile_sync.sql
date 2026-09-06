-- Keep Google OAuth profile metadata synchronized with Journey360 profiles.
-- Apply after migrations 001 through 004.

create or replace function public.sync_auth_profile_metadata()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set display_name = coalesce(
        nullif(new.raw_user_meta_data->>'full_name', ''),
        nullif(new.raw_user_meta_data->>'name', ''),
        display_name
      ),
      username = coalesce(nullif(new.raw_user_meta_data->>'user_name', ''), username),
      avatar_url = coalesce(nullif(new.raw_user_meta_data->>'avatar_url', ''), avatar_url),
      updated_at = now()
  where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_metadata_updated on auth.users;
create trigger on_auth_user_metadata_updated
after update of raw_user_meta_data on auth.users
for each row execute procedure public.sync_auth_profile_metadata();

-- Make sure existing OAuth users receive their current provider metadata.
update public.profiles p
set display_name = coalesce(
      nullif(u.raw_user_meta_data->>'full_name', ''),
      nullif(u.raw_user_meta_data->>'name', ''),
      p.display_name
    ),
    username = coalesce(nullif(u.raw_user_meta_data->>'user_name', ''), p.username),
    avatar_url = coalesce(nullif(u.raw_user_meta_data->>'avatar_url', ''), p.avatar_url),
    updated_at = now()
from auth.users u
where u.id = p.id;
