-- 004_leave_delete_signature.sql: leave and delete groups, drawn signatures. Run after 003.
--
-- Leave: every member can leave at any time, also while the session runs. The group then
--   disappears for them. Their check-ins stay in the feed but no longer count.
-- Owner leaves: the member who joined first becomes the new owner. If nobody is left,
--   the group is deleted.
-- Delete: only the owner, for everyone. Deletes members, check-ins, reactions and messages.
--   The app deletes the photos in storage first (Supabase only allows that through its API).
-- Signature: now a hand-drawn PNG, stored as text "data:image/png;base64,...".

-- ============================================================
-- Leave a group (also withdraws a pending request or removes a declined one)
-- Runs as one step in the database, so two people leaving at the same time cannot
-- leave a group without owner.
-- ============================================================

create function leave_group(gid uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
    was_owner boolean;
    next_owner uuid;
begin
    if auth.uid() is null then
        raise exception 'Not logged in';
    end if;

    -- "for update" locks the group row until this function is done.
    select owner_id = auth.uid() into was_owner from groups where id = gid for update;
    if was_owner is null then
        raise exception 'This group does not exist any more';
    end if;

    delete from memberships where group_id = gid and user_id = auth.uid();
    if not found then
        raise exception 'You are not in this group';
    end if;

    if was_owner then
        select user_id into next_owner from memberships
        where group_id = gid and status = 'accepted'
        order by signed_at
        limit 1;

        if next_owner is null then
            delete from groups where id = gid;   -- cascades to everything of the group
        else
            update groups set owner_id = next_owner where id = gid;
        end if;
    end if;
end;
$$;

revoke execute on function leave_group(uuid) from public, anon;
grant execute on function leave_group(uuid) to authenticated;

-- ============================================================
-- Delete a group: owner only (R28). "on delete cascade" removes all rows of the group.
-- ============================================================

create policy "groups delete by owner" on groups for delete to authenticated using (is_owner(id));

-- The owner may delete the photos of the group, so nothing is left in storage.
create policy "proofs delete by owner" on storage.objects for delete to authenticated using (
    bucket_id = 'proofs' and is_owner(((storage.foldername(name))[1])::uuid)
);

-- ============================================================
-- Drawn signatures: a PNG of at most 40 KB is about 54 000 characters as base64.
-- ============================================================

alter table memberships add constraint memberships_signature_check
    check (char_length(signature) between 1 and 60000);
