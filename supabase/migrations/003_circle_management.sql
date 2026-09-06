-- Circle management policies for create, join, and owner removal.
-- Apply after 001_initial_schema.sql and 002_journey360_core.sql.

-- Replace the original insert policy with an explicit authenticated check.
-- The RPC below is the preferred path because circle creation and adding the
-- owner are one transaction.
drop policy if exists "owners create circles" on public.circles;
drop policy if exists "owners manage circles" on public.circles;
drop policy if exists "circle members can read circles" on public.circles;
drop policy if exists "authenticated owners create circles" on public.circles;
drop policy if exists "circle members read circles" on public.circles;
drop policy if exists "circle owners update circles" on public.circles;
create policy "authenticated owners create circles" on public.circles
  for insert to authenticated
  with check (auth.uid() is not null and owner_id = auth.uid());
create policy "circle members read circles" on public.circles
  for select to authenticated
  using (public.is_circle_member(id) or owner_id = auth.uid());
create policy "circle owners update circles" on public.circles
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists "users join circles" on public.circle_members;
create policy "users join circles" on public.circle_members
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "circle owners remove members" on public.circle_members;
create policy "circle owners remove members" on public.circle_members
  for delete to authenticated
  using (exists (
    select 1 from public.circles c
    where c.id = circle_members.circle_id
      and c.owner_id = auth.uid()
  ));

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

  code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
  insert into public.circles (name, type, owner_id, invite_code)
  values (trim(circle_name), circle_type, auth.uid(), code)
  returning * into created_circle;

  insert into public.circle_members (circle_id, user_id, display_name, role)
  select created_circle.id, auth.uid(), p.display_name, 'owner'
  from public.profiles p
  where p.id = auth.uid();

  return created_circle;
end;
$$;

revoke all on function public.create_circle(text, public.circle_type) from public;
grant execute on function public.create_circle(text, public.circle_type) to authenticated;
