-- 005_icons_and_pictures.sql: group icon (one emoji), profile and group pictures. Run after 004.
-- The old profiles.avatar column stays (the sign up trigger still fills it with 🙂) but the app
-- no longer shows it.

alter table profiles add column photo_path text;

alter table groups add column icon text not null default '🎯' check (char_length(icon) between 1 and 16);
alter table groups add column photo_path text;

-- ============================================================
-- Private bucket "pictures"
--   users/<user id>/<random uuid>.jpg   profile picture
--   groups/<group id>/<random uuid>.jpg group picture
-- A new random file name for every change, so phones never show an old cached picture.
-- ============================================================

insert into storage.buckets (id, name, public) values ('pictures', 'pictures', false);

-- Profile pictures: every logged-in user can see them, like names in profiles.
-- Only you can upload or delete in your own folder.
create policy "pictures read users" on storage.objects for select to authenticated using (
    bucket_id = 'pictures' and (storage.foldername(name))[1] = 'users'
);
create policy "pictures upload own" on storage.objects for insert to authenticated with check (
    bucket_id = 'pictures' and (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = auth.uid()::text
);
create policy "pictures delete own" on storage.objects for delete to authenticated using (
    bucket_id = 'pictures' and (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = auth.uid()::text
);

-- Group pictures: everyone with a membership row can see them (also pending, like the contract).
-- Only the owner can upload or delete.
create policy "pictures read groups" on storage.objects for select to authenticated using (
    bucket_id = 'pictures' and (storage.foldername(name))[1] = 'groups'
    and exists (select 1 from memberships m
                where m.group_id::text = (storage.foldername(name))[2] and m.user_id = auth.uid())
);
create policy "pictures upload by owner" on storage.objects for insert to authenticated with check (
    bucket_id = 'pictures' and (storage.foldername(name))[1] = 'groups'
    and is_owner(((storage.foldername(name))[2])::uuid)
);
create policy "pictures delete by owner" on storage.objects for delete to authenticated using (
    bucket_id = 'pictures' and (storage.foldername(name))[1] = 'groups'
    and is_owner(((storage.foldername(name))[2])::uuid)
);

-- The contract preview before joining now also shows the group icon.
drop function preview_group_by_code(text);
create function preview_group_by_code(code text)
returns table (name text, habit text, icon text, target int, period_days int, end_on date, rules_text text)
language sql stable security definer set search_path = public as $$
    select g.name, g.habit, g.icon, g.target, g.period_days, g.end_on, g.rules_text
    from groups g
    where g.invite_code = upper(trim(code)) and g.started_on is null and g.ended_early_at is null;
$$;
revoke execute on function preview_group_by_code(text) from public, anon;
grant execute on function preview_group_by_code(text) to authenticated;
