# Habitract

iOS app (SwiftUI, iOS 17+) for our Introduction to Programming group project. Full spec: [SPEC.md](SPEC.md). Rules for AI assistants: [AGENTS.md](AGENTS.md).

The app is called **Habitract**. The Xcode project, target and folders are still named `HabitUs` on purpose (renaming them would break every checkout).

## What Habitract is

Habitract (**habit** + **contract**) is an iPhone app for building a habit together with friends. A group agrees on one habit, for example "Gym, 3 times per week", and everyone signs a contract by hand. Every round (a day, a week or 28 days) each member proves every task with a **live photo** from the camera. The photos appear in the group chat, and the group itself decides: if more than half of the others press 👎, the photo does not count and has to be retaken before the round ends.

### Objectives

- **Accountability through friends:** not an app that trusts you, but a group that checks your proof.
- **Motivation through a fair game:** points for every task, a bonus for full rounds, a streak bonus, a podium and a leaderboard with grades A to D.
- **Flexible, but honest:** a pause with a reason for real exceptions (sick, travelling), which the group can reject within 48 hours.
- **Safe by design:** login with email code, access rules in the database (only members see a group), proof photos only from the live camera in a private storage.

### Main features

Sign up with email code and password rules, forgot password · create a habit with an emoji or picture and sign the contract · join with a 6 character invite code, also while a challenge runs (the newcomer gets the group average for the rounds before) · live photo check-ins · 👍/👎 votes in the chat and in a Tinder style vote deck · retake a rejected photo · pause with a reason · podium, leaderboard with a points chart, player profiles with grade and history · chat with text and GIFs · leave a group, delete a group, delete your account · light and dark mode.

Tech: Swift and SwiftUI (iOS 17+), Supabase (login, Postgres database with row level security, photo storage), the game rules as a tested Swift package (`HabitCore`, 100+ tests).

## Team

| Name | Student number |
|---|---|
| Vincent Kaya Göv | 80562 |
| Benedict Louis Fuchs | 78394 |
| Lennart Werner | 80487 |

### Who did what

Every feature was built on its own branch and merged through a pull request that a teammate reviewed (see the pull requests on GitHub and `docs/HANDOVER.md`, which logs every step with its branch).

| Member | Main contributions |
|---|---|
| Lennart Werner | Project setup, Supabase schema and access rules (migrations 001 to 007), the game rules in `HabitCore` with tests, login with email code, forgot password and password rules, creating and joining groups, contract with signature, chat with GIFs, profile and group pictures, joining a running challenge, "on hold" below 3 players, retake card, README and DECISIONS |
| Vincent Kaya Göv | Photo validation with 👍/👎 and the vote deck, pause with a reason and the 48 hour window, delete account (migration 008), Home sorted by newest activity, reviewing and merging the pull requests |
| Benedict Louis Fuchs | Interface redesign (onboarding, login, habit setup, group cards, chat, leaderboard) with light and dark mode, presentation handover |

Our decisions and why: [DECISIONS.md](DECISIONS.md). What was built step by step: [docs/HANDOVER.md](docs/HANDOVER.md).

## For the teaching team: run the app in 10 minutes

Habitract is a native iPhone app, so it has no public URL. We demo it live on our phones. To try it yourself you need a Mac with **Xcode 16 or newer** (we use Xcode 27). No Apple developer account is needed for the simulator.

1. **Get the code**
   ```
   git clone https://github.com/lennyesterday/HabitUs.git
   cd HabitUs
   ```
2. **Connect it to our server.** The app needs two values: the address of our Supabase project and its public (anon) key. They are not in the repo on purpose; you find them in our Moodle submission. Then:
   ```
   cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
   open -e Config/Secrets.xcconfig
   ```
   Replace the two placeholders and save. Keep the odd `/$()/` in the URL, because `//` starts a comment in this file type:
   ```
   SUPABASE_URL = https:/$()/<project-id>.supabase.co
   SUPABASE_ANON_KEY = <anon key from the submission>
   ```
   `GIPHY_API_KEY` is optional. Without it everything works except the GIF search in the chat.
3. **Open and run.** Double click `HabitUs.xcodeproj`. Wait until Xcode has loaded the Swift package (`supabase-swift`, a few seconds). Next to the ▶ button at the top pick an **iPhone simulator** (for example iPhone 17), then press **▶**.
4. **Try it.** The easiest way: log in with the **professor account** from our Moodle submission. It is already a member of a running group that we prepared, so you can see check-ins, votes, the leaderboard and the chat right away. You can also sign up with your own email address (you get a 6 digit code by email, check spam), but a new habit only starts with **3 members**.
   - The simulator has no camera. There the camera offers a generated test photo instead, only in simulator builds.
5. **Run the tests** (the game rules, no phone or internet needed):
   ```
   cd HabitCore && swift test
   ```

**Alternative: your own server.** Create a free project on supabase.com, run the files `supabase/migrations/001` to `008` in order in its SQL editor (see "Supabase setup" below), and put that project's URL and anon key into `Config/Secrets.xcconfig` instead.

**On a real iPhone** (optional): plug it in, turn on Settings → Privacy & Security → Developer Mode, pick your Apple ID under Target → Signing & Capabilities, and press ▶. With a free Apple ID the app runs for 7 days.

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
   - `004_leave_delete_signature.sql`: leave and delete groups, hand-drawn signatures
   - `005_icons_and_pictures.sql`: group icon, profile and group pictures
   - `006_leave_messages.sql`: "X left the group" in the chat, on hold below 3 players
   - `007_late_join.sql`: join a running challenge
   - `008_delete_account.sql`: delete your own account
2. Emails: our project sends the sign up and password reset codes through Resend (custom SMTP, see `docs/HANDOVER.md` step 31). For a quick test project without email, turn off Authentication → Sign In / Providers → Email → "Confirm email".

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
