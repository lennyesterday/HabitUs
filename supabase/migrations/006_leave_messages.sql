-- 006_leave_messages.sql: "Lenny left the group" in the chat. Run after 005.
-- Safe to run again (an earlier version of this file ended the challenge below 3 players;
-- running this one replaces it).
--
-- System messages: written only by the database (here and in 007), never by the app.
--   The insert policy refuses system = true, so nobody can fake one.
-- Below 3 players a running challenge is on hold (HabitCore isOnHold), it does not end.
--   People can join a running challenge since 007, so the group can go on later.

alter table messages add column if not exists system boolean not null default false;

drop policy if exists "messages insert" on messages;
create policy "messages insert" on messages for insert to authenticated
    with check (user_id = auth.uid() and is_accepted(group_id) and system = false);

-- Same as in 004, plus the system messages.
create or replace function leave_group(gid uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
    was_owner boolean;
    was_accepted boolean;
    was_running boolean;
    my_name text;
    next_owner uuid;
    players_left int;
begin
    if auth.uid() is null then
        raise exception 'Not logged in';
    end if;

    -- "for update" locks the group row until this function is done, so two people
    -- leaving at the same time are handled one after the other.
    select owner_id = auth.uid() into was_owner from groups where id = gid for update;
    if was_owner is null then
        raise exception 'This group does not exist any more';
    end if;
    was_running := is_active(gid);

    select m.status = 'accepted', p.display_name into was_accepted, my_name
    from memberships m join profiles p on p.id = m.user_id
    where m.group_id = gid and m.user_id = auth.uid();

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
            return;
        end if;
        update groups set owner_id = next_owner where id = gid;
    end if;

    -- A pending or declined request leaves quietly.
    if not was_accepted then
        return;
    end if;

    insert into messages (group_id, user_id, text, system)
    values (gid, auth.uid(), my_name || ' left the group.', true);

    select count(*) into players_left from memberships where group_id = gid and status = 'accepted';
    if was_running and players_left < 3 then
        insert into messages (group_id, user_id, text, system)
        values (gid, auth.uid(),
                'Only ' || players_left || case when players_left = 1 then ' player is' else ' players are' end
                || ' left, so the game is on hold. Invite someone with the code to go on.', true);
    end if;
end;
$$;

-- An earlier version of this file set ended_early_at below 3 players. Groups it ended
-- that way are not reopened automatically; the owner can delete them or start a new one.
