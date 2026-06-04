-- SafeOne policies for the existing Supabase schema.
-- Run this after confirming the real table names and foreign keys.

alter table public.users enable row level security;
alter table public.reminders enable row level security;
alter table public.caregiver_assignments enable row level security;

drop policy if exists "users_select_own" on public.users;
create policy "users_select_own"
on public.users
for select
to authenticated
using (apple_user_id = auth.uid()::text or id = auth.uid());

drop policy if exists "users_insert_own" on public.users;
create policy "users_insert_own"
on public.users
for insert
to authenticated
with check (apple_user_id = auth.uid()::text or id = auth.uid());

drop policy if exists "users_update_own" on public.users;
create policy "users_update_own"
on public.users
for update
to authenticated
using (apple_user_id = auth.uid()::text or id = auth.uid())
with check (apple_user_id = auth.uid()::text or id = auth.uid());

drop policy if exists "reminders_select_accessible" on public.reminders;
create policy "reminders_select_accessible"
on public.reminders
for select
to authenticated
using (
  created_by = auth.uid()
  or elder_id = auth.uid()
  or exists (
    select 1
    from public.caregiver_assignments ca
    where ca.child_id = auth.uid()
      and ca.elder_id = elder_id
  )
);

drop policy if exists "reminders_insert_accessible" on public.reminders;
create policy "reminders_insert_accessible"
on public.reminders
for insert
to authenticated
with check (
  created_by = auth.uid()
  or exists (
    select 1
    from public.caregiver_assignments ca
    where ca.child_id = auth.uid()
      and ca.elder_id = elder_id
  )
);

drop policy if exists "reminders_update_accessible" on public.reminders;
create policy "reminders_update_accessible"
on public.reminders
for update
to authenticated
using (
  created_by = auth.uid()
  or exists (
    select 1
    from public.caregiver_assignments ca
    where ca.child_id = auth.uid()
      and ca.elder_id = elder_id
  )
)
with check (
  created_by = auth.uid()
  or exists (
    select 1
    from public.caregiver_assignments ca
    where ca.child_id = auth.uid()
      and ca.elder_id = elder_id
  )
);

drop policy if exists "reminders_delete_accessible" on public.reminders;
create policy "reminders_delete_accessible"
on public.reminders
for delete
to authenticated
using (
  created_by = auth.uid()
  or exists (
    select 1
    from public.caregiver_assignments ca
    where ca.child_id = auth.uid()
      and ca.elder_id = elder_id
  )
);

drop policy if exists "assignments_select_own" on public.caregiver_assignments;
create policy "assignments_select_own"
on public.caregiver_assignments
for select
to authenticated
using (child_id = auth.uid() or elder_id = auth.uid());

drop policy if exists "assignments_insert_own" on public.caregiver_assignments;
create policy "assignments_insert_own"
on public.caregiver_assignments
for insert
to authenticated
with check (child_id = auth.uid());

drop policy if exists "assignments_delete_own" on public.caregiver_assignments;
create policy "assignments_delete_own"
on public.caregiver_assignments
for delete
to authenticated
using (child_id = auth.uid());
