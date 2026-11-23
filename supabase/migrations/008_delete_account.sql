-- 008_delete_account.sql: delete your own account (R31). Run after 007. Safe to run again.
--
-- The app cannot delete a login itself: that needs the service role key, which must never be
-- in the app. This function runs with the rights of its owner (security definer), but only
-- ever deletes the account of the person who calls it (auth.uid()).
--
-- What happens, in this order:
--   1. Leave every group with leave_group (006): the owner role goes to the member who joined
--      first, an empty group is deleted, the chat says "X left the group."
--   2. The "X left the group." notes stay: they are moved to the group's (new) owner,
--      because every message needs an author that still exists.
--   3. My own messages, reactions and check-ins are deleted everywhere.
--   4. The login is deleted. "on delete cascade" removes my profile row.
-- The app deletes my files in storage first (Supabase only allows that through its API).

-- My own proof photos, also in groups I do not own, so nothing of me is left in storage.
-- owner_id is set by Supabase Storage to the user who uploaded the file.
drop policy if exists "proofs delete own" on storage.objects;
create policy "proofs delete own" on storage.objects for delete to authenticated using (
    bucket_id = 'proofs' and owner_id = auth.uid()::text
);

create or replace function delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare
    me uuid := auth.uid();
    gid uuid;
begin
    if me is null then
        raise exception 'Not logged in';
    end if;

    -- 1. Leave every group, one after the other (also pending and declined requests).
    for gid in select group_id from memberships where user_id = me loop
        perform leave_group(gid);
    end loop;

    -- 2. Keep the system notes written in my name, under the group's owner.
    update messages m set user_id = g.owner_id
    from groups g
    where m.group_id = g.id and m.user_id = me and m.system;

    -- 3. Everything else of mine. Reactions of others on my check-ins go with them (cascade).
    delete from reactions where user_id = me;
    delete from checkins where user_id = me;
    delete from messages where user_id = me;
    -- A group I own without a membership row should not exist, but never block the deletion.
    delete from groups where owner_id = me;

    -- 4. The login itself. The profile row follows (on delete cascade).
    delete from auth.users where id = me;
end;
$$;

revoke execute on function delete_my_account() from public, anon;
grant execute on function delete_my_account() to authenticated;

-- The app calls this first, before it deletes any files. If this migration was not run yet,
-- the call fails and nothing at all is deleted.
create or replace function account_deletion_ready() returns boolean
language sql stable as $$ select true $$;

revoke execute on function account_deletion_ready() from public, anon;
grant execute on function account_deletion_ready() to authenticated;
