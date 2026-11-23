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

### A pilot, and where we want to take it

This version is a **pilot**. It shows that the idea works: friends sign a contract, prove their habit with live photos and keep each other honest with their votes. Points, streaks and the leaderboard make it a game, but nothing real is at stake yet.

In the future we want to turn Habitract into a **business**: friends play for real money by **putting some money on the line**. The model we have in mind (details in [DECISIONS.md](DECISIONS.md), "What we would do next"):

- Every member puts a small **stake per round** into the pot, for example 5 €.
- Whoever completes the round gets their stake back and **shares the stakes of those who did not**.
- Someone who joins later simply pays from their first round, so it stays fair.
- Habitract earns a **small fee** on every pot.
- First step without any payment handling: the app only shows who owes whom ("Vincent owes Lenny 5 €") and friends settle it with PayPal or MB Way. Real payments in the app (for example Stripe Connect) come later, once the legal side (licences, App Store rules for real money) is clear.

With money involved, the group votes become more important, so the business version would also need a way to appeal a 👎 and stronger proof checks.

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

## For the teaching team: how to open and try the app

Habitract is a native iPhone app, so it has no public URL. We demo it live on our phones. You can try it yourself in two ways:

- **A. On the Mac in the iPhone simulator** (easiest, about 10 minutes, no Apple developer account needed)
- **B. On your own iPhone** (about 20 minutes the first time, needs a cable and a free Apple ID)

Both need a Mac with **Xcode 16 or newer** (free in the Mac App Store, we use Xcode 27).

**All keys are already in the repo** (`Config/Public.xcconfig`), so the app connects to our server right after cloning. You do not need to type in any key. For reference:

| What | Value |
|---|---|
| Supabase project URL | `https://awcuknlajkywifxquhcq.supabase.co` |
| Supabase anon (publishable) key | `sb_publishable_VjjWWwc7HvycIXOV_xxhaQ_Xg2Wgy1L` |
| GIPHY API key (GIF search in the chat) | `pVndKDGjCWS89yKhuJfpFOTP8eTM9uqk` |

The Supabase anon key is public by design: it can only do what the access rules (row level security) in our database allow. Secret keys (Supabase service role, the email service) are never in the app or the repo.

**Login:** use the **professor account** from our Moodle submission (email and password are there, not here, because this repo is public). It is already a member of a demo group with a story we prepared, so all features have content right away. You can also sign up with your own email address: you get a 6 digit code by email (check spam).

### A. On the Mac (iPhone simulator)

1. Open the app **Terminal** and get the code:
   ```
   git clone https://github.com/lennyesterday/HabitUs.git
   cd HabitUs
   open HabitUs.xcodeproj
   ```
   (Or on GitHub: Code → Download ZIP, unzip, double click `HabitUs.xcodeproj`.)
2. Xcode opens and loads the Swift package `supabase-swift` (bottom left "Resolving packages", a few seconds up to a minute).
3. At the top of the window, next to the ▶ button, click the device name and pick an **iPhone simulator**, for example "iPhone 17". If there is none: Xcode → Settings → Components → download the iOS simulator.
4. Press **▶** (or ⌘R). The first build takes about a minute, then the simulator opens with Habitract.
5. Swipe through the introduction, choose **Log in** and enter the professor account.
6. The simulator has no camera. When you check in there, the camera offers a generated **test photo** instead.

### B. On your own iPhone

1. Do steps 1 and 2 from A.
2. Connect the iPhone to the Mac with a cable, unlock it and tap **Trust** ("Trust this computer?").
3. **Turn on Developer Mode on the iPhone:** Settings → Privacy & Security → scroll to the bottom → **Developer Mode** → on → **Restart**. After the restart the iPhone asks again: tap **Turn On** and enter your code. (If the menu is missing: keep the iPhone plugged in, open Xcode → Window → Devices and Simulators once, then look again.)
4. **Signing in Xcode:** Xcode → Settings → Accounts → **+** → Apple ID → sign in with your normal Apple ID (free). Then copy the signing file and give the app your own ID, so it does not clash with ours:
   ```
   cp Config/Local.example.xcconfig Config/Local.xcconfig
   open -e Config/Local.xcconfig
   ```
   Set `BUNDLE_ID_SUFFIX = .professor` and `DEVELOPMENT_TEAM` to your team ID. The easiest way to find the team ID: in Xcode click the blue **HabitUs** project at the top left → target **HabitUs** → **Signing & Capabilities** → Team: pick "(your name) (Personal Team)". You can also leave it there instead of using `Local.xcconfig`.
5. At the top next to ▶ pick **your iPhone** instead of a simulator and press **▶**. The first time Xcode prepares the iPhone ("Preparing device", "Copying shared cache symbols"): this can take 5 to 15 minutes, keep it plugged in and unlocked.
6. If the iPhone says **"Untrusted Developer"**: Settings → General → **VPN & Device Management** → your Apple ID → **Trust**. Then press ▶ again.
7. Habitract is now on the home screen and also works without the cable. With a free Apple ID it opens for **7 days**, after that press ▶ in Xcode again.
8. On the iPhone the check-in uses the real camera. The first time it asks for permission.

### What to look at

After logging in with the professor account, open the demo group on Home and try:

- **Group screen:** task card with countdown, podium, rankings, chat with photos, pauses, text and GIFs.
- **Vote on photos & pauses:** the 🗳️ deck, swipe or tap 👍/👎. If more than half of the others press 👎, a photo is invalid and its owner gets a red "Retake photo" card.
- **Check in:** "Do …" opens the camera (test photo in the simulator). **Pause:** "Can't today? Take a pause" with a reason; the others can reject it for 48 hours.
- **Leaderboard:** tap the podium. **Player profile with grade A to D:** tap a player. **Group info with invite code and contract:** tap the member pictures at the top.
- **Profile and settings:** the round picture at the top right of Home (profile photo, "How it works", log out, delete account). The app follows the iPhone's light or dark mode.

### Tests

The game rules run without phone or internet (in Terminal, inside the `HabitUs` folder):
```
cd HabitCore && swift test
```

**Alternative: your own server.** Create a free project on supabase.com, run `supabase/migrations/001` to `008` in order in its SQL editor (see "Supabase setup" below), and put that project's URL and anon key into `Config/Secrets.xcconfig` (copy it from `Config/Secrets.example.xcconfig`). It overrides `Config/Public.xcconfig`.

## Setup (once per Mac)

1. Clone: `git clone https://github.com/lennyesterday/HabitUs.git`
2. Open `HabitUs.xcodeproj` in Xcode.
3. Signing, so the app runs on your own iPhone:
   - Copy `Config/Local.example.xcconfig` to `Config/Local.xcconfig` (this file is ignored by Git).
   - Set `BUNDLE_ID_SUFFIX` to your name, e.g. `.vincent`.
   - Set `DEVELOPMENT_TEAM` to your team ID. Easiest way: in Xcode under Target → Signing & Capabilities pick your Apple ID as team, then run `git diff` and copy the `DEVELOPMENT_TEAM = XXXXXXXXXX` value into `Local.xcconfig`. Afterwards undo the project change with `git checkout HabitUs.xcodeproj`.
4. Supabase and GIPHY: nothing to do. `Config/Public.xcconfig` (committed) points to our demo server. Only for another server: copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` (ignored by Git) and fill in its URL and **anon** key. Never the service role key.
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
