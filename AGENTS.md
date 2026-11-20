# Rules for AI assistants (Claude, Codex, ...)

## Git
- **Never push to `main`.** Always work on a branch (`a/login`, `b/x-rule`, `c/leaderboard`) and open a pull request.
- Pull `main` before starting. Small commits with clear messages.
- Never commit `Config/Local.xcconfig`, `Secrets.xcconfig`, `xcuserdata/` or `DerivedData/`.
- Do not change `DEVELOPMENT_TEAM` or the bundle ID in `HabitUs.xcodeproj`. Personal signing values live in `Config/Local.xcconfig`.

## How to work
- Read `SPEC.md` first. Build only what the current task names. Do not build other features or fix other things you notice.
- Keep the layers: no Supabase calls in `Views/`, no SwiftUI or Supabase in `HabitCore`.
- Every rule from SPEC section 3 goes into `HabitCore` with a test. Tests first. Never weaken, skip or delete a test to get green.
- Never put the service role key into the app or the repo. Only the anon key, and only in `Secrets.xcconfig`.
- The database is the team's Supabase project. Inspect it read only by default. Do not change or delete tables or rows unless the task says so. Save every change to the data structure as a SQL file in `supabase/migrations/`. Tests never use the Supabase project.
- Every new table gets RLS turned on and a policy in `schema.sql` in the same change.
- Small changes. Show the diff and explain it in plain words. We are beginners and need to understand roughly what each part does.
- Stay inside the files of the area you are working in.
- New Swift files go into the `HabitUs/` folder. It is a synchronized folder, so Xcode picks them up without editing the project file.

## Handover log
- After every change (feature, fix, migration, design), add a numbered entry to `docs/HANDOVER.md` section 14 "Step-by-step log": what, why, files, how to check. Use the template at the end of that section.
- Also update the other sections of `docs/HANDOVER.md` that the change makes out of date (status, file tables, test count, SPEC deviations, known limits).
- Commit the HANDOVER update together with the code, on the same branch. Plain English for beginners, and say honestly what was not tested.
