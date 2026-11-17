-- 001_schema.sql: tables, access rules (RLS), photo storage and the join function.
-- SPEC section 5. Run once in the Supabase SQL editor of a fresh project.
-- Every table has RLS turned on. Without a matching policy, nobody can read or write it.

-- ============================================================
-- Tables
-- ============================================================

create table profiles (
    id           uuid primary key references auth.users on delete cascade,
    display_name text not null check (char_length(display_name) between 2 and 20),
    avatar       text not null,
    created_at   timestamptz not null default now()
);

create table groups (
    id             uuid primary key default gen_random_uuid(),
    name           text not null,
    habit          text not null,
    target         int  not null check (target between 1 and 28),   -- limit per period (10, 7, 28) checked in HabitCore
    period_days    int  not null check (period_days in (1, 7, 28)), -- day, week, month
    end_on         date,                -- NULL for open end
    rules_text     text not null default '',
    invite_code    text not null unique,
    owner_id       uuid not null default auth.uid() references profiles(id),
    started_on     date,                -- NULL while in the lobby
    ended_early_at timestamptz,         -- set when the owner presses Finish challenge
    created_at     timestamptz not null default now()
);

create table memberships (
    id        uuid primary key default gen_random_uuid(),
    group_id  uuid not null references groups(id) on delete cascade,
    user_id   uuid not null default auth.uid() references profiles(id),
    status    text not null check (status in ('pending','accepted','declined')),
    signature text not null,            -- typed name
    signed_at timestamptz not null default now(),
    unique (group_id, user_id)
);

create table checkins (
    id         uuid primary key default gen_random_uuid(),
    group_id   uuid not null references groups(id) on delete cascade,
    user_id    uuid not null default auth.uid() references profiles(id),
    kind       text not null check (kind in ('photo','pause')),
    photo_path text,                    -- only for kind = 'photo', path in the storage bucket
    text       text not null default '' check (char_length(text) <= 200),  -- caption or pause reason
    day        date not null default (now() at time zone 'Europe/Lisbon')::date,
    created_at timestamptz not null default now()
);

create table reactions (
    checkin_id uuid not null references checkins(id) on delete cascade,
    user_id    uuid not null default auth.uid() references profiles(id),
    kind       text not null check (kind in ('like','x')),
    primary key (checkin_id, user_id)
);

create table messages (
    id         uuid primary key default gen_random_uuid(),
    group_id   uuid not null references groups(id) on delete cascade,
    user_id    uuid not null default auth.uid() references profiles(id),
    text       text not null check (char_length(text) between 1 and 500),
    created_at timestamptz not null default now()
);

-- ============================================================
-- Helper functions for the policies
-- "security definer" means they run with the rights of their creator and skip RLS.
-- That is needed because a policy on memberships cannot itself read memberships
-- through RLS without going in circles.
-- ============================================================

-- Is the logged-in user an accepted member of this group?
create function is_accepted(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
    select exists (
        select 1 from memberships
        where group_id = gid and user_id = auth.uid() and status = 'accepted'
    );
$$;

-- Is the logged-in user the owner of this group?
create function is_owner(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
    select exists (select 1 from groups where id = gid and owner_id = auth.uid());
$$;

-- Is the session running today (Lisbon time)? Started, not finished by the owner,
-- and today is before the end of the last full round that fits before end_on (R9).
create function is_active(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
    select exists (
        select 1 from groups g
        where g.id = gid
          and g.started_on is not null
          and g.ended_early_at is null
          and (
              g.end_on is null
              or (now() at time zone 'Europe/Lisbon')::date
                 < g.started_on + ((g.end_on - g.started_on + 1) / g.period_days) * g.period_days
          )
    );
$$;

-- ============================================================
-- Row Level Security
-- ============================================================

alter table profiles    enable row level security;
alter table groups      enable row level security;
alter table memberships enable row level security;
alter table checkins    enable row level security;
alter table reactions   enable row level security;
alter table messages    enable row level security;

-- profiles: any logged-in user can read (only name and avatar). Only your own row can be written.
create policy "profiles read" on profiles for select to authenticated using (true);
create policy "profiles insert own" on profiles for insert to authenticated with check (id = auth.uid());
create policy "profiles update own" on profiles for update to authenticated
    using (id = auth.uid()) with check (id = auth.uid());

-- groups: the owner and anyone with a membership row (a pending member sees the contract).
create policy "groups read" on groups for select to authenticated using (
    owner_id = auth.uid()
    or exists (select 1 from memberships m where m.group_id = groups.id and m.user_id = auth.uid())
);
create policy "groups insert as owner" on groups for insert to authenticated
    with check (owner_id = auth.uid());
-- Start and finish (R7, R8, R28).
create policy "groups update by owner" on groups for update to authenticated
    using (is_owner(id)) with check (is_owner(id));

-- memberships: accepted members see the group's members, everyone sees their own row (R27).
create policy "memberships read" on memberships for select to authenticated
    using (user_id = auth.uid() or is_accepted(group_id));
-- Direct insert only for the owner signing their own group. Joiners go through join_by_code.
create policy "memberships insert owner self" on memberships for insert to authenticated
    with check (user_id = auth.uid() and status = 'accepted' and is_owner(group_id));
-- Accept and decline (R6, R28).
create policy "memberships update by owner" on memberships for update to authenticated
    using (is_owner(group_id)) with check (is_owner(group_id));

-- checkins: accepted members read. You post as yourself, as an accepted member, while active.
create policy "checkins read" on checkins for select to authenticated using (is_accepted(group_id));
create policy "checkins insert" on checkins for insert to authenticated
    with check (user_id = auth.uid() and is_accepted(group_id) and is_active(group_id));

-- reactions: accepted members read. Your own reaction only, never on your own check-in (R15).
create policy "reactions read" on reactions for select to authenticated using (
    exists (select 1 from checkins c where c.id = reactions.checkin_id and is_accepted(c.group_id))
);
create policy "reactions insert" on reactions for insert to authenticated with check (
    user_id = auth.uid()
    and exists (select 1 from checkins c
                where c.id = reactions.checkin_id and c.user_id <> auth.uid() and is_accepted(c.group_id))
);
create policy "reactions update" on reactions for update to authenticated
    using (user_id = auth.uid())
    with check (
        user_id = auth.uid()
        and exists (select 1 from checkins c
                    where c.id = reactions.checkin_id and c.user_id <> auth.uid() and is_accepted(c.group_id))
    );
create policy "reactions delete" on reactions for delete to authenticated using (user_id = auth.uid());

-- messages: accepted members read and post as themselves.
create policy "messages read" on messages for select to authenticated using (is_accepted(group_id));
create policy "messages insert" on messages for insert to authenticated
    with check (user_id = auth.uid() and is_accepted(group_id));

-- ============================================================
-- Photo storage: private bucket "proofs", path <group_id>/<random uuid>.jpg
-- The first folder of the path is the group id, which decides who may see the photo.
-- ============================================================

insert into storage.buckets (id, name, public) values ('proofs', 'proofs', false);

create policy "proofs read" on storage.objects for select to authenticated using (
    bucket_id = 'proofs' and is_accepted(((storage.foldername(name))[1])::uuid)
);
create policy "proofs upload" on storage.objects for insert to authenticated with check (
    bucket_id = 'proofs' and is_accepted(((storage.foldername(name))[1])::uuid)
);

-- ============================================================
-- join_by_code: the one database function (R5, S9)
-- A joiner is not a member yet, so RLS hides the group from them. This function
-- looks up the code, checks the group is still in the lobby and creates a pending request.
-- ============================================================

create function join_by_code(code text, signature text) returns uuid
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

    select id into gid from groups
    where invite_code = upper(trim(code)) and started_on is null and ended_early_at is null;
    if gid is null then
        raise exception 'This invite code is not valid';
    end if;

    if exists (select 1 from memberships where group_id = gid and user_id = auth.uid()) then
        raise exception 'You already asked to join this group';
    end if;

    insert into memberships (group_id, user_id, status, signature)
    values (gid, auth.uid(), 'pending', trim(signature));
    return gid;
end;
$$;

revoke execute on function join_by_code(text, text) from public, anon;
grant execute on function join_by_code(text, text) to authenticated;
