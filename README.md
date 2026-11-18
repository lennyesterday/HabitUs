# HabitUs

iOS app (SwiftUI, iOS 17+) for our Introduction to Programming group project. Full spec: [SPEC.md](SPEC.md). Rules for AI assistants: [AGENTS.md](AGENTS.md).

## Setup (once per Mac)

1. Clone: `git clone https://github.com/lennyesterday/HabitUs.git`
2. Open `HabitUs.xcodeproj` in Xcode.
3. Signing, so the app runs on your own iPhone:
   - Copy `Config/Local.example.xcconfig` to `Config/Local.xcconfig` (this file is ignored by Git).
   - Set `BUNDLE_ID_SUFFIX` to your name, e.g. `.vincent`.
   - Set `DEVELOPMENT_TEAM` to your team ID. Easiest way: in Xcode under Target → Signing & Capabilities pick your Apple ID as team, then run `git diff` and copy the `DEVELOPMENT_TEAM = XXXXXXXXXX` value into `Local.xcconfig`. Afterwards undo the project change with `git checkout HabitUs.xcodeproj`.
4. Supabase access:
   - Copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` (also ignored by Git).
   - Fill in the project URL and the **anon** key from the Supabase dashboard (Project Settings → API). Never the service role key.
   - Optional, for GIFs in the chat: create a free app on developers.giphy.com and put its API key into `GIPHY_API_KEY`.
5. Pick an iPhone simulator next to the play button and press ▶.

## Supabase setup (once per project)

1. Run the files in `supabase/migrations/` in order in the SQL editor of a fresh Supabase project:
   - `001_schema.sql`: tables, access rules (RLS), the private `proofs` photo bucket, `join_by_code`
   - `002_profiles_and_join_preview.sql`: creates the profile for every new account, contract preview by invite code
   - `003_chat_gifs.sql`: GIFs from GIPHY in the chat
2. Turn off email confirmation: Authentication → Sign In / Providers → Email → "Confirm email" off. We have no email verification (SPEC section 11, known limits).

The simulator has no camera. There the camera sheet offers a generated test photo, only in simulator builds.

## Tests

The game rules live in the `HabitCore` package and run without phone or internet:

```
cd HabitCore && swift test
```

## Where things are

- `HabitUs/Views/` screens, `HabitUs/Services/` the only code that talks to Supabase
- `HabitCore/` the rules from SPEC section 3, `HabitCore/Tests/` their tests
- `supabase/migrations/` the database structure

## How we work

- `main` always builds. Nobody pushes to `main` directly.
- Per task: pull `main` → new branch (`a/login`) → code → commit → push → pull request → a teammate reviews and merges.
- New files go into the `HabitUs/` folder. Xcode picks them up by itself (synchronized folder), so the project file rarely changes.
