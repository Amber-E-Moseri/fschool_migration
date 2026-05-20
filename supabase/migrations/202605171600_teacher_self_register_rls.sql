-- Allow unauthenticated users to self-register as a teacher.
-- Only PENDING/inactive rows are permitted this way; all active teachers are
-- created by admins using the direct-create flow.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'teachers'
      and policyname = 'allow public teacher self registration'
  ) then
    create policy "allow public teacher self registration"
      on public.teachers
      for insert
      to anon, authenticated
      with check (
        status = 'PENDING'
        and active = false
      );
  end if;
end
$$;
