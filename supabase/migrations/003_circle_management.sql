-- Circle management policies for create, join, and owner removal.
-- Apply after 001_initial_schema.sql and 002_journey360_core.sql.

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
