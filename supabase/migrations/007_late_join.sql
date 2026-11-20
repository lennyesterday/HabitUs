-- 007_late_join.sql: join a challenge that is already running (R29). Run after 006.
--
-- The invite code now works until the challenge is over. The owner accepts as in the lobby.
-- Someone accepted while the challenge runs plays from the next round. For the rounds before,
-- HabitCore gives them the average points of the others (leaderboard, R29).
-- The database sets first_round itself when the owner accepts, so no app can change it.

alter table memberships add column if not exists first_round int not null default 1
    check (first_round >= 1);

-- The round of today (Lisbon time), 1 on the start day. Same formula as currentRound in HabitCore.
create or replace function current_round(gid uuid) returns int
language sql stable security definer set search_path = public as $$
    select ((now() at time zone 'Europe/Lisbon')::date - g.started_on) / g.period_days + 1
    from groups g where g.id = gid and g.started_on is not null;
$$;

-- ============================================================
-- Accepting: first_round and the chat note
-- Runs before every update of a membership. Only the step pending → accepted may change
-- first_round; every other update keeps the old value.
-- ============================================================

create or replace function on_membership_update() returns trigger
language plpgsql security definer set search_path = public as $$
declare
    running boolean := is_active(new.group_id);
    name text;
    players int;
begin
    new.first_round := old.first_round;
    if not (old.status = 'pending' and new.status = 'accepted' and running) then
        return new;
    end if;

    new.first_round := current_round(new.group_id) + 1;

    select display_name into name from profiles where id = new.user_id;
    insert into messages (group_id, user_id, text, system)
    values (new.group_id, new.user_id,
            name || ' joined the group and starts in round ' || new.first_round || '.', true);

    -- "players" does not include the new member yet: this runs before the update.
    select count(*) + 1 into players from memberships
    where group_id = new.group_id and status = 'accepted';
    if players = 3 then
        insert into messages (group_id, user_id, text, system)
        values (new.group_id, new.user_id, 'There are 3 players again, the game goes on.', true);
    end if;
    return new;
end;
$$;

drop trigger if exists membership_update on memberships;
create trigger membership_update
    before update on memberships
    for each row execute function on_membership_update();

-- ============================================================
-- Join and preview: lobby or running, never after the end
-- ============================================================

create or replace function join_by_code(code text, signature text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
    gid uuid;
begin
    if auth.uid() is null then
        raise exception 'Not logged in';
    end if;
    if char_length(trim(signature)) = 0 then
        raise exception 'Please sign the contract';
    end if;

    select id into gid from groups g
    where g.invite_code = upper(trim(code)) and g.ended_early_at is null
      and (g.started_on is null or is_active(g.id));
    if gid is null then
        raise exception 'This invite code is not valid, or the challenge is over';
    end if;

    if exists (select 1 from memberships where group_id = gid and user_id = auth.uid()) then
        raise exception 'You already asked to join this group';
    end if;

    insert into memberships (group_id, user_id, status, signature)
    values (gid, auth.uid(), 'pending', trim(signature));
    return gid;
end;
$$;

-- The preview now also says whether the challenge already runs (started_on), so the
-- join screen can explain the next round and the average points.
drop function if exists preview_group_by_code(text);
create function preview_group_by_code(code text)
returns table (name text, habit text, icon text, target int, period_days int, end_on date,
               rules_text text, started_on date)
language sql stable security definer set search_path = public as $$
    select g.name, g.habit, g.icon, g.target, g.period_days, g.end_on, g.rules_text, g.started_on
    from groups g
    where g.invite_code = upper(trim(code)) and g.ended_early_at is null
      and (g.started_on is null or is_active(g.id));
$$;

revoke execute on function preview_group_by_code(text) from public, anon;
grant execute on function preview_group_by_code(text) to authenticated;
revoke execute on function current_round(uuid) from public, anon;
grant execute on function current_round(uuid) to authenticated;
