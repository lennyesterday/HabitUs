-- 002_profiles_and_join_preview.sql: run after 001_schema.sql.
-- 1. Every new account gets its profile row automatically (name and avatar from sign up).
-- 2. A joiner can read the contract of a lobby group by its code before signing (R5).

-- ============================================================
-- 1. Profile for every new account
-- The app sends display_name and avatar as user metadata when signing up. This trigger
-- copies them into profiles in the same step, so there is never an account without a profile.
-- ============================================================

create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
    name text := trim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
begin
    if char_length(name) not between 2 and 20 then
        name := 'Player';
    end if;
    insert into profiles (id, display_name, avatar)
    values (new.id, name, coalesce(nullif(new.raw_user_meta_data ->> 'avatar', ''), '🙂'));
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function handle_new_user();

-- ============================================================
-- 2. Contract preview by invite code (R5)
-- RLS hides groups from people who are not members yet. This function returns only the
-- contract fields, and only while the group is in the lobby. It does not create anything.
-- ============================================================

create function preview_group_by_code(code text)
returns table (name text, habit text, target int, period_days int, end_on date, rules_text text)
language sql stable security definer set search_path = public as $$
    select g.name, g.habit, g.target, g.period_days, g.end_on, g.rules_text
    from groups g
    where g.invite_code = upper(trim(code)) and g.started_on is null and g.ended_early_at is null;
$$;

revoke execute on function preview_group_by_code(text) from public, anon;
grant execute on function preview_group_by_code(text) to authenticated;
