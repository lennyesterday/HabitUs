# Habitract (repo: HabitUs): what has been built so far

Presentation handover for Lenny, Bene and Vincent. The current overview was checked against `main`
at commit `311d53b` (23 Nov 2026), including PR #22. The numbered log in section 14 is a history:
later entries can replace earlier experiments. Section 15 is the short guide for the presentation.
Actual Supabase settings, applied migrations, real-device behavior and demo data were not independently
verified for this update. Where the code and `SPEC.md` disagree, section 8 lists the differences.

---

## 1. The app in one paragraph

Friends form a group around one habit ("Gym, 3 times per week"). Everyone signs a contract by hand.
Every round (a day, a week or 28 days) each member proves each task with a **live photo** from the
camera. The photos appear in the group chat. If more than half of the other members press **X**, the
photo does not count. Done tasks give points, full rounds give a bonus, rounds in a row give a
streak bonus, and a leaderboard shows who delivers.

---

## 2. Status

**Code checked on 23 Nov:** the current `main` contains onboarding, login and email confirmation,
password reset, groups and contracts, photo check-ins, reactions, text and GIF chat, points,
leaderboard, profile pictures and the design work through PR #22. `HabitCore` has **92 XCTest
cases**, run successfully on 23 Nov without a Supabase connection. This is evidence for the rules,
not proof that the camera, database policies or the whole demo work on real phones.

**Before the presentation:** rehearse create → join → accept → start → photo → reactions →
leaderboard using three accounts and real phones. Verify camera permission, network, emails,
Supabase access policies and the deployed database migrations. This update did not run that live demo.

| Area | Current behavior and where to look |
|---|---|
| Account | Onboarding, sign up, confirmation code, login, password reset and logout: `AuthView.swift`, `AuthService.swift` |
| Home and appearance | Group cards, profile pictures, New Habit and Join Habit; light/dark surfaces and emoji-based banners: `HomeView.swift`, `Theme.swift`, `Components/Pictures.swift` |
| Groups | Create or join using a code, sign the contract, owner accepts/declines and starts: `CreateGroupView.swift`, `JoinView.swift`, `ContractView.swift`, `LobbyView.swift`, `GroupService.swift` |
| Running group | Task card, photo check-in, vote deck, leaderboard, text/GIF chat and periodic refresh: `GroupView.swift`, `Components/TaskCard.swift`, `Components/FeedView.swift` |
| Late join and hold | An accepted late joiner starts next round; a running group with fewer than three accepted players is on hold. Rules: `Rounds.swift`, `Tasks.swift`, `Scoring.swift`; database: migrations 006 and 007 |
| Leaderboard | Tap the podium: points history chart, rankings and the round bonus below them: `LeaderboardView.swift`, `Components/BonusCard.swift` |
| Group and player information | Tap member photos for group info and invite code; tap a ranking row for player history: `GroupInfoView.swift`, `PlayerProfileView.swift` |
| Help and pictures | Profile/settings and choosing profile pictures: `ProfileView.swift`; group look: `GroupLookView.swift` |

**Pause with a reason (R18)** is built (step 72): "Can't today? Take a pause" on the task card,
the 48 hour 👎 window and the retroactive point loss. The thumbs-up and thumbs-down reaction UI,
`CheckinService.setReaction` and `addPause` were not exercised against the live backend
as part of this documentation update. Check hand-in materials and the manual RLS evidence yourselves.

---

## 3. How it is built: three layers

```
 Views/            what you see. SwiftUI screens. Never talk to Supabase.
   │ calls
   ▼
 Services/         the only code that talks to Supabase (database, login, storage)
   │ uses for every rule
   ▼
 HabitCore/        the game rules as pure Swift functions. No SwiftUI, no Supabase, no internet.
                   Tested with `cd HabitCore && swift test` (98 tests passed on 23 Nov 2026).

 supabase/migrations/   the database: tables, access rules (RLS), database functions
```

Three ideas hold everything together (SPEC §2). You must be able to explain each in one sentence:

1. **Three layers.** A button calls a service, the service talks to Supabase and asks HabitCore for every rule.
2. **Time is a parameter.** Every rule that depends on time takes `now: Date`. The app passes `Date()`,
   tests pass any date they like. That is how we test "round 3 in summer time" in milliseconds.
3. **Points are computed, never stored.** There is no points column. The score is always calculated
   from the check-ins and the X votes. If a photo becomes invalid, the score is simply lower next time.

And one security idea: **access is checked in the database (RLS), not in the app.** The anon key is in
the app and can be extracted. Without RLS anyone with the key could read everything.

---

## 4. One feature from the button to the database: "Do GYM 2"

Follow this once in Xcode. It is the best way to understand the whole app.

1. **View:** `Views/Components/TaskCard.swift` shows the button. It is only enabled if
   `status.canCheckInToday` is true. Tapping it opens `CameraView` (camera only, no photo library).
2. **View:** `Views/GroupView.swift` → `checkIn(image)` calls the service.
3. **Service:** `Services/CheckinService.swift` → `addPhoto(groupId:image:caption:)`
   - loads the group with `GroupService.load` (group, members, check-ins, reactions, messages)
   - asks **HabitCore** `taskStatus(...)`: is the session running, is a task open, is today still free?
   - if not, throws a readable `RuleError` ("You already checked in today. Come back tomorrow.")
   - uploads the photo with `PhotoService.upload` (resized to 800 px, saved as JPEG = no location data,
     random file name in the private bucket `proofs`)
   - inserts a row into `checkins`. The **database** sets the time and the day.
4. **HabitCore:** `Tasks.swift` → `taskStatus` uses `Rounds.swift` (which round is today?) and
   `Votes.swift` (`isValid`: more than half X?).
5. **Database:** `001_schema.sql` → policy `"checkins insert"`: only allowed if you are the author,
   an accepted member (`is_accepted`) and the session is running (`is_active`). This is the intended
   access restriction; verify the deployed policy with a two-account manual check.
6. Back in the view, `reload()` loads everything again and HabitCore recomputes points, rank, bonus.

---

## 5. HabitCore: the rules

| File | Main functions | Rules | Tests |
|---|---|---|---|
| `Models.swift` | plain data: `HabitGroup`, `Member`, `Checkin`, `Reaction`, `TaskStatus`, `LeaderboardRow`, `RuleError` | – | – |
| `Rounds.swift` | `phase`, `currentRound`, `round(of:in:)`, `timeLeft`, `canStart`, `localDay`, `isOnHold`, `firstRound` | R8, R9, R14, R29, R30 | 17 |
| `Tasks.swift` | `taskStatus` (done, failed, open, canCheckInToday) | R10 to R12, R19, R29, R30 | 12 |
| `Votes.swift` | `xThresholdReached`, `isValid`, `canReact`, `pauseVotingWindow`, `pauseVotingEnds` | R15 to R19 | 17 |
| `Scoring.swift` | `scoreRounds`, `roundBonusPercent`, `leaderboard`, `grade` (A to D) | R20 to R24, R29 | 22 |
| `Validation.swift` | `validateSignUp`, `validatePassword`, `validateGroup`, `validateSignatureImage`, `validateMessage`, `validatePauseReason`, `validateGifURL` | R1, R4, R18, R26 | 27 |
| `InviteCode.swift` | `InviteCode.generate()` (6 characters, no 0/O/1/I, `SystemRandomNumberGenerator`) | R4, S9 | 3 |

Test names say which rule they check, e.g. `testR17PhotoInvalidWhenMoreThanHalfX`.

**The points in one example** (3 per week, rounds with 3, 3, 2, 3 tasks done):

| Round | Base (20 per task) | Bonus | Points |
|---|---|---|---|
| 1 | 60 | +25 % (full round) | 75 |
| 2 | 60 | +30 % (2nd full round in a row) | 78 |
| 3 | 40 | none (not full, streak resets) | 40 |
| 4 | 60 | +25 % | 75 |

The bonus grows by 5 % per full round in a row and stops at +50 %. Tests also check the three player
types from the SPEC: 1035, 940 and 480 points over 12 rounds.

**The X rule:** a photo or pause is invalid when more than half of the *other* members pressed X.
3 members → 2 X needed, 4 → 2, 5 → 3, 6 → 3. The author's own X never counts.

---

## 6. The database (Supabase)

Database changes are recorded in `supabase/migrations/`. The repository contains migrations 001–007.
These files describe intended database changes; their deployment to the shared project was not checked
in this documentation update. Confirm the actual migration state with the team before the demo.

| File | What it adds |
|---|---|
| `001_schema.sql` | 6 tables (`profiles`, `groups`, `memberships`, `checkins`, `reactions`, `messages`), RLS on every table, helper functions `is_accepted`, `is_owner`, `is_active`, private bucket `proofs`, function `join_by_code` |
| `002_profiles_and_join_preview.sql` | trigger that creates the profile at sign up, `preview_group_by_code` (read the contract before joining) |
| `003_chat_gifs.sql` | `messages.gif_url`, only links to GIPHY's GIF servers allowed |
| `004_leave_delete_signature.sql` | `leave_group` (owner role moves to the member who joined first, last one out deletes the group), owner may delete the group, signature size limit |
| `005_icons_and_pictures.sql` | `groups.icon`, `groups.photo_path`, `profiles.photo_path`, private bucket `pictures` with policies |
| `006_leave_messages.sql` | Updates `leave_group`, adds system messages for departures and the on-hold notice |
| `007_late_join.sql` | Adds `memberships.first_round`; updates joining, contract preview and acceptance for active groups |

**Who may do what (RLS):**

| Table | Read | Write |
|---|---|---|
| profiles | every logged-in user (only name and picture) | only your own row |
| groups | owner and everyone with a membership | create: you become owner. Change, delete: owner only |
| memberships | accepted members of the group, and your own row | join only via `join_by_code`. Accept/decline: owner only |
| checkins | accepted members | you, as accepted member, while the session runs |
| reactions | accepted members | your own, never on your own check-in |
| messages | accepted members | you, as accepted member |
| storage `proofs` | accepted members of the group folder | upload: accepted members. Delete: owner |
| storage `pictures` | profile pictures: everyone logged in. Group pictures: members | only your own folder / owner for the group |

**`security definer`** means a database function runs with the rights of its creator and skips RLS.
We need it in three places, and each one checks itself what is allowed:
- `join_by_code`: a joiner is not a member yet, so RLS would hide the group
- `leave_group`: changes the owner in one safe step
- `is_accepted` / `is_owner`: policies on `memberships` cannot read `memberships` through RLS without going in circles

---

## 7. The app code

### Services (the only place that talks to Supabase)

| File | Does |
|---|---|
| `SupabaseClient.swift` | the one client, reads URL and key from `Info.plist`; `readable { }` turns every error into a readable text |
| `Rows.swift` | how database rows look (snake_case) and how they turn into HabitCore models; Lisbon day format |
| `AuthService.swift` | sign up, confirmation codes, password reset, log in, log out, profile and profile picture |
| `GroupService.swift` | create, preview, join, accept/decline, start, finish, leave, delete, change look, Home cards, `load` (everything for one group) |
| `CheckinService.swift` | photo check-in, pause with a reason (R18), reactions and feed |
| `PhotoService.swift` | proof photos: resize, JPEG, upload, load with cache, delete all |
| `PictureService.swift` | profile and group pictures (square 400 px) |
| `ChatService.swift` | text messages and GIF messages |
| `GifService.swift` | GIPHY search (rating G) and animated GIF loading |

### Views (one file per screen)

`HabitUsApp.swift` decides: not set up → hint, not logged in → onboarding then `AuthView`, logged in → `HomeView`.
`GameScreen.swift` opens the right screen for a game: contract (pending), `LobbyView`, `GroupView` or `ResultsView`.
`Theme.swift` holds colors, fonts and the shared building blocks (chunky button, pills, cards, backgrounds).
Previews with sample data: `GroupView`, `LeaderboardView`, `HomeView` (card), `ProfileView`, `OnboardingView`.

### Config and secrets

| File | In git? | Contains |
|---|---|---|
| `Config/Base.xcconfig` | yes | shared settings, includes the two files below |
| `Config/Local.xcconfig` | **no** | your Apple team and bundle id suffix (signing) |
| `Config/Secrets.xcconfig` | **no** | Supabase URL, anon key, GIPHY key. Ask Lenny for the values |
| `Config/*.example.xcconfig` | yes | templates to copy |

The only external package is `supabase-swift`, pinned to exactly 2.55.7 (`Package.resolved` is committed).

---

## 8. Where we changed the SPEC (and why)

The following summarizes changes and remaining differences. The SPEC now includes late joining and
on-hold behavior as R29 and R30, but older sections can still contain conflicting descriptions.

| Change | SPEC said | Why we changed it | Watch out |
|---|---|---|---|
| Leave a group any time | "Later" / contract binding | Contracts are a fun element, people must be able to leave | the chat says "X left the group."; below 3 players a running challenge is on hold until someone joins (steps 68, 69); fewer members means fewer X are needed, also for older photos |
| Signature drawn with the finger | typed name | feels more like a real contract | stored as a small PNG (max 40 KB) in `memberships.signature` |
| GIFs in the chat (GIPHY) | text only | fun | third party service: search terms and IP go to GIPHY; the GIPHY key is in the app |
| Group icon (emoji), profile and group pictures | avatar emoji | looks better, closer to the design references | pictures may come from the photo library, proofs still only from the camera |
| Onboarding and current design | – | explain the app and make the screens readable | PR #22 uses a neutral, Retro-inspired design with light/dark variants and emoji-based group banners; it uses a system serif approximation, not Retro's original font |
| Email confirmation, forgot password, password rules | no email verification, 8 characters | real accounts: a 6 digit code from the email, a way back in, the usual password rules (steps 27, 29, 30, 31) | emails go through Resend with our own domain `habitractapp.com` (about 10 € a year, paid by Lenny); if Resend or the SMTP settings break, nobody can sign up |

---

## 9. Known limits (say them yourselves in the walkthrough)

- Many game rules run in the app; RLS and selected database functions enforce access and some transitions. A modified client may bypass client-only game rules. Cross-group access is intended to be blocked by RLS, but the deployed policies need a real two-account manual check.
- No account deletion. Email verification and password reset exist since steps 27 and 29.
- The password rules are checked in the app. The server only checks them if they are also set in Supabase (step 30).
- A photo of a screen can fake a "live" photo. That is exactly why the group can press X.
- No push notifications, no live updates (the group screen reloads every 10 seconds).
- Not tested automatically: deployed RLS and database functions, camera, layout and the full multi-user journey. A manual RLS check (S5) is required; this update did not verify its result.
- GIPHY sees search terms and IP addresses.

---

## 10. Getting started on your Mac (15 minutes)

1. `git clone https://github.com/lennyesterday/HabitUs.git` and open `HabitUs.xcodeproj`.
2. Copy `Config/Local.example.xcconfig` → `Config/Local.xcconfig`, set your team and a suffix (README).
3. Copy `Config/Secrets.example.xcconfig` → `Config/Secrets.xcconfig`, ask Lenny for the three values.
4. `cd HabitCore && swift test` → 98 tests green.
5. Run in the simulator, sign up with your own email, join Lenny's test game with the code.
6. Read in this order: `HabitCore/Sources/HabitCore/Scoring.swift` → `Tasks.swift` → `Services/CheckinService.swift` → `Views/GroupView.swift` → `supabase/migrations/001_schema.sql`.

**On your own iPhone (for the demo):** no paid Apple account needed.
1. Plug the iPhone in, tap "Trust". Turn on Settings → Privacy & Security → Developer Mode (the iPhone restarts).
2. In Xcode pick the iPhone instead of the simulator and press ▶ Run.
3. If it says "Untrusted Developer": Settings → General → VPN & Device Management → your Apple ID → Trust, then ▶ again.
4. With a free Apple ID the app stops opening after **7 days**. Install it fresh on 22 or 23 Nov for the presentation on 24 Nov.
5. Show the screen with QuickTime → New Movie Recording → camera: iPhone. Prepare a running group with 3 accounts, so feed, votes and leaderboard are not empty. Test the internet in the room (hotspot as backup).

Work rules (`AGENTS.md`): a branch per task (`b/x-rule`), pull request, someone else reviews, tests stay green, commit from your own account.

---

## 11. Presentation preparation

- **Together:** rehearse the full demo on three real phones and confirm camera permissions, network,
  login, group membership, photo upload, reactions and leaderboard refresh.
- **Database:** confirm migrations 001–007 are applied and perform the two-account RLS check. Do not
  run migrations or change shared data just to prepare this handover.
- **Hand-in:** verify the current README, names and student numbers, decisions, demonstration data,
  and any course-specific URL requirement with the team and course instructions.
- **Pause:** built in step 72, but not yet tried with three accounts. Try it once before the demo.

---

## 12. Questions to expect (with short answers)

| Question | Short answer |
|---|---|
| Your key is in the app. Is that safe? | It is the public anon key. Every table and bucket has RLS, so the key alone shows nothing. The service role key is never in the app. |
| Can I see another group's photos? | The intended storage policy checks group membership. A two-account manual test is needed to verify the deployed policy. |
| Why are points not stored? | They cannot get out of sync. An invalid photo needs no correction. |
| How do you test rules about weeks without waiting? | Time is a parameter. Tests pass any `now`. |
| Why a separate HabitCore package? | Rules testable in seconds without phone, internet or database. Clear for the walkthrough. |
| What happens when the owner leaves? | `leave_group` gives the owner role to the member who joined first, in one locked database step. If nobody is left, the group is deleted. |
| Why `security definer`? | A joiner is not a member yet, so RLS would hide the group. The function itself checks only what is needed. |
| How do you stop fake photos? | Camera only, database timestamp, and the group can press X. No AI detection on purpose. |
| How are passwords stored? | Only Supabase Auth, as a bcrypt hash. Our tables never see them. |
| What is not tested? | RLS, camera, layout, two people tapping at the same second. See section 9. |
| What would you do next? | Add live updates and push notifications, enforce more game rules in the database, and add account deletion. |

---

## 13. Words you will hear

| Word | Meaning |
|---|---|
| SwiftUI view | a screen or part of a screen, written as a Swift struct with a `body` |
| `async` / `await` | code that waits for the internet without freezing the screen |
| Supabase | hosted Postgres database + login + file storage, so we need no own server |
| RLS (Row Level Security) | rules in the database that decide per row who may read or write it |
| Policy | one such RLS rule, e.g. "checkins insert" |
| Migration | a SQL file that changes the database structure, run once, in order |
| anon / publishable key | the public key in the app; safe only because of RLS |
| Bucket | a folder in Supabase Storage (`proofs`, `pictures`) |
| PR (pull request) | proposal to merge a branch into `main`, reviewed by a teammate |
| Squash and merge | merge a PR as one single commit |

---

## 14. Step-by-step log

Every change gets one entry here, newest at the bottom. Format: **what** was done, **why**, the
**files** it touched, and **how to check** it. This is the story you tell in the walkthrough.

### Day 1: Tue 17 Nov

**Step 1: Project skeleton** (branch `c/setup`, PR #1)
- What: Xcode project, the `HabitCore` package with the data models and an empty stub for every function from SPEC §6, the database schema with RLS on every table, stub services and screens, `supabase-swift` pinned to 2.55.7.
- Why: SPEC §8 plan for day 1, so everyone can call everyone else's functions before they are finished.
- Files: `HabitCore/`, `supabase/migrations/001_schema.sql`, `HabitUs/Services/`, `HabitUs/Views/`, `Config/`.
- Decision: the group model is called `HabitGroup`, because SwiftUI already has a type called `Group`.

**Step 2: First working prototype** (branch `c/prototype`, PR #2)
- What: all rules R1 to R26 in `HabitCore`, written **tests first** (61 tests). Real services for log in, groups, check-ins, photos and chat. All screens from sign up to the photo check-in.
- Why: Milestone 1 (SPEC §8): the happy path with three accounts.
- Files: `HabitCore/Sources/*`, `HabitCore/Tests/*`, `HabitUs/Services/*`, `HabitUs/Views/*`, `supabase/migrations/002_profiles_and_join_preview.sql`.
- Decision: migration 002 creates the profile automatically at sign up, and lets a joiner read the contract before signing.
- Decision: the simulator has no camera, so it offers a generated test photo, only in simulator builds.

### Day 2: Wed 18 Nov

**Step 3: Supabase project connected**
- What: Supabase project "HabitUs App" created, migrations 001 and 002 run in the SQL editor, email confirmation turned off, URL and publishable key in `Config/Secrets.xcconfig` (not in git).
- Why: the app needs a real database to work on several phones.
- How to check: the app shows the log in screen instead of "Supabase is not set up".

**Step 4: GIFs in the chat** (branch `b/gif-chat`, PR #3)
- What: GIF button in the chat, GIPHY search (rating G, "Powered by GIPHY"), animated GIFs in the feed.
- Why: makes the chat more fun.
- Files: `GifService.swift`, `GifPicker.swift`, `ChatService.swift`, `FeedView.swift`, `003_chat_gifs.sql`, new rule `validateGifURL` with 2 tests.
- Security: the database only accepts https links to `.gif` files on GIPHY's servers, and `HabitCore` checks the same rule.

**Step 5: Leave and delete groups, signature by hand** (branch `a/leave-delete-signature`, PR #4)
- What: everyone can leave at any time. When the owner leaves, the member who joined first becomes owner, and the last one out deletes the group. The owner can delete the group for everyone. The contract is signed with the finger (PencilKit).
- Why: Lenny's decision. The contract is a fun element, and people must be able to leave.
- Files: `GroupService.swift` (`leave`, `delete`), `GameScreen.swift` (menu), `SignaturePad.swift`, `ContractView.swift`, `004_leave_delete_signature.sql`, rule `validateSignatureImage` (replaces the typed-name rule on purpose).

**Step 6: App icon** (branch `a/app-icon`, PR #5)
- What: icon with two figures and a check mark. The black corners of the original were cropped away, because iOS rounds the corners itself.

**Step 7: Group icons and pictures** (branch `a/no-avatar`, PR #6)
- What: the avatar emoji at sign up was removed. Groups get one emoji as icon, picked from all emojis with search. There are now profile pictures and group pictures (owner).
- Files: `EmojiPicker.swift`, `Pictures.swift`, `ProfileView.swift`, `GroupLookView.swift`, `PictureService.swift`, `005_icons_and_pictures.sql` (private bucket `pictures`), rule `validateGroupIcon`.

**Step 8: Onboarding and new log in look** (branch `a/onboarding`, PR #7)
- What: five onboarding pages with Next/Skip, shown whenever nobody is logged in. The log in screen got the brand blue, the logo and the chunky yellow button. The accent color is now the icon blue.
- Files: `OnboardingView.swift`, `AuthView.swift`, `Theme.swift`, `HabitUsApp.swift`.

**Step 9: Bug fixes found while testing**
- A profile was missing for an old account: the app now creates it, or logs out if the account was deleted in the dashboard (`AuthService.myProfile`).
- Only a thin line in the middle of each text field reacted to taps: the whole grey box works now (`AuthView.field`).
- The log in form lost what was typed and switched tabs by itself: the segmented Picker was replaced by two buttons, and repeated auth events are ignored (`AuthView.modeSwitch`, `HabitUsApp.swift`).
- How we found them: the simulator was driven step by step, together with debug logs.

**Step 10: GIPHY key added**
- The key is in `Config/Secrets.xcconfig` (not in git). Ask Lenny for it.

**Step 11: Redesign inspired by PlayUs** (branch `a/redesign`, PR #9)
- What: Home with big game cards (picture or emoji, member pictures, points and rank). New group screen with a colored task card, bonus card, podium, ranking rows, chat bubbles and a floating message bar. Leaderboard with a points chart (Swift Charts). Settings as section cards.
- Why: fun, but still a habit app.
- HabitCore: `roundBonusPercent` and `LeaderboardRow.pointsPerRound`, with 2 new tests (68 in total).
- Files: `HomeView.swift`, `GroupView.swift`, `TaskCard.swift`, `BonusCard.swift`, `Podium.swift`, `FeedView.swift`, `LeaderboardView.swift`, `ResultsView.swift`, `ProfileView.swift`, `Theme.swift`, `GroupService.myGames`.

### Day 3: Thu 19 Nov

**Step 12: Handover document and the PR for Vincent**
- What: this document. PRs #1 to #9 were bundled into one PR to `main`.
- What went wrong: #10 was merged by Lenny's account by mistake and reverted in #11.
- Now: **PR #12** has the same content, and Vincent reviews and merges it.

**Step 13: Rule for keeping this log** (branch `a/redesign`, PR #12)
- What: `AGENTS.md` now says that every change adds an entry here.
- Why: AI tools such as Claude or Codex read `AGENTS.md` in every repo. Whoever codes, the log stays complete.
- Files: `AGENTS.md`, `docs/HANDOVER.md`.

**Step 14: Habits, not games: calmer design and wording** (branch `a/habit-wording`, PR #13)
- What:
  - All visible texts say "habit" instead of "game" ("New Habit", "Join a Habit", "No habits yet", invite text).
  - Home has a light background instead of strong blue, and the main button is blue.
  - Buttons have a thin edge and normal case instead of CAPITALS. Pills are light.
  - Ranking rows are white with a colored place badge. The "Best player" laurels are gone, and the leaderboard is light instead of dark.
  - The task card button is white in the group color, and the yellow group color was replaced by green for contrast.
- Why: Lenny: "it's not about games, it's about habits". It should still be fun, but feel like a habit app.
- Files: `Theme.swift`, `HomeView.swift`, `GroupView.swift`, `TaskCard.swift`, `BonusCard.swift`, `Podium.swift`, `LeaderboardView.swift`, `ResultsView.swift`, `JoinView.swift`, `CreateGroupView.swift`, `LobbyView.swift`, `GameScreen.swift`, `GroupService.swift` (one error text).
- Not renamed on purpose: internal code names like `GameCard`, `GameScreen` and `myGames`. Nobody sees them, and renaming them would touch many files.
- How to check: the previews of `GroupView` and `HomeView` (Card). Onboarding and log in were not changed and still use the blue look.

**Step 15: "Join Habit" button with a group icon** (branch `a/habit-wording`, PR #13)
- What: the second button on Home says "Join Habit" and shows a group symbol (three people, `person.3.fill`) instead of "Join" with a single person.
- Why: Lenny wanted it clearer that you join a group habit.
- Files: `HomeView.swift`.
- How to check: run the app and log in. The button is next to "New Habit" on Home. It builds, but it was not checked on screen yet.

**Step 16: Tap the podium to open the leaderboard** (branch `leaderboard`)
- What: the "Leaderboard & chart" button on the group screen is gone. Tapping the podium (top 3 with the crown) now opens the leaderboard with the chart. A small hint "Tap for leaderboard & chart" sits under the podium.
- Why: Lenny wanted fewer buttons. The podium is the natural place to tap.
- Files: `GroupView.swift`.
- How to check: open a running habit, tap the podium, and the leaderboard opens. It builds without warnings, but it was not tapped on a real screen yet.

**Step 17: No hint text under the podium** (branch `leaderboard`)
- What: the small text "Tap for leaderboard & chart" under the podium was removed. Tapping the podium still opens the leaderboard.
- Why: Lenny wanted a cleaner screen.
- Files: `GroupView.swift`.
- Note for the walkthrough: the podium no longer shows a hint that it can be tapped. Mention it in the demo.

### Day 4: Fri 20 Nov

**Step 18: Player profile with grade, history and reminder** (branch `group-playerprofil`)
- What: tap a player in the rows under the podium to open their profile:
  - picture, place, points, streak, full rounds and pauses
  - a **grade A to D**
  - the **history round by round**: done/target, points, photo thumbnails (rejected photos are faded with an X), pauses with reason (and if they were rejected), missed tasks
  - for other members, a **"Remind …" button**: it posts "👋 Lenny reminds Bene to do Gym: 2 left this round!" into the group chat
- Grade rule (HabitCore `grade(donePerRound:target:)`, 4 tests): share of tasks done in **finished** rounds (the running round does not count yet). A from 90 %, B from 70 %, C from 50 %, otherwise D, and no grade before the first finished round. Whole numbers only, so exactly 90 % is an A. `LeaderboardRow` now also has `donePerRound`.
- Why: Lenny wanted to see who keeps the habit and who is slipping, and to nudge them.
- **Why not a real push notification:** real push to another iPhone needs the paid Apple Developer account, Apple's push service (APNs) and a server that sends the messages. SPEC section 1 lists push as "Later". The chat reminder is the honest version for now. Mention this in the walkthrough.
- Files: `PlayerProfileView.swift` (new), `Podium.swift` (`RankingRows` is tappable), `GroupView.swift` (opens the profile), `HabitCore/Sources/HabitCore/Scoring.swift`, `Models.swift`, `ScoringTests.swift`.
- How to check: the `PlayerProfileView` preview shows a sample player. In the app, open a running habit, tap a row under the podium, then try "Remind". `swift test` → 72 green. Not yet tried with real photos on screen.

**Step 19: Reminder button removed again** (branch `group-playerprofil`)
- What: the "Remind …" button and its chat message were taken out of the player profile. Grade, stats and history stay.
- Why: Lenny decided to leave reminders and notifications out for now.
- Options for later: real push (paid Apple Developer account, APNs key, device tokens in Supabase, an Edge Function that sends) or local notifications that remind you on your own phone (free, no server).
- Files: `PlayerProfileView.swift`.

**Step 20: Group info** (branch `group-info`)
- What: tapping the member pictures at the top of the group screen opens "Group info":
  - group picture or icon, name, habit
  - facts: status, how often, length of a round, start, end or open end, current round with time left, owner
  - all members with crown and signature. Tapping a member opens the player profile
  - the contract with the group's own rules
  - a short summary of how points work
- Why: Lenny wanted one place with everything important about a group.
- Code: the contract text moved into a small reusable view `ContractTerms` (in `ContractView.swift`), so the signing screen and the group info always show the same words.
- Files: `GroupInfoView.swift` (new), `GroupView.swift` (the member pictures are a button now), `ContractView.swift`.
- How to check: the `GroupInfoView` preview, or in the app tap the member pictures in a running habit. Not yet tried on a real device.

**Step 21: Group info: my signature under the contract instead of the member list** (branch `group-info`)
- What: the "Members" section with everyone's signature was removed from the group info. Under the contract there is now only **my own** hand-drawn signature with "Signed by Lenny", like on a paper contract.
- Why: Lenny wanted the group info calmer. Members are already visible on the group screen and in the player profiles.
- Files: `GroupInfoView.swift`.
- How to check: open the group info. The signature is under "Contract & rules". The preview has no signature in its sample data, so check this in the app.

**Step 22: 👎 instead of X in the contract and the onboarding** (branch `group-info`)
- What: the contract now says "If more than half of the other members give a **👎** …", and the onboarding page "Your group checks" shows 👍 and 👎 instead of 👍 and ✕.
- Why: Lenny: a thumbs down is clearer and friendlier than an X.
- Note: in the SPEC (R15 to R18) and in the code (`ReactionKind.x`, `xThresholdReached`) it is still called "X", only the word on screen changed. The rule itself is the same. The like/👎 buttons in the feed are still to be built (section 11), and they should use 👍 and 👎.
- Files: `ContractView.swift`, `OnboardingView.swift`.

**Step 23: Date next to every signature** (branch `group-info`)
- What: wherever a signature is shown, its date is shown next to it:
  - group info: "Signed by Lenny · 18 Nov 2026"
  - lobby requests for the owner
  - while signing: "Date: 20 Nov 2026" under the signature field
- How: the database already saves the time in `memberships.signed_at` (set by the database, see `001_schema.sql`). The app now loads it: `Member.signedAt` (optional, in HabitCore `Models.swift`), `MemberRow` in `Rows.swift`, and `GroupService.members` selects `signed_at`. New helper `Theme.signatureDate`.
- Why: Lenny wanted it to look like a real signed contract.
- Files: `Models.swift`, `Rows.swift`, `GroupService.swift`, `Theme.swift`, `GroupInfoView.swift`, `LobbyView.swift`, `ContractView.swift`.
- How to check: open the group info and a lobby with a request. `swift test` → 72 green. Not checked on screen yet.

**Step 24: Change the profile picture by tapping it** (branch `profilsettings`)
- What: the "Profile" section with "Add picture" was removed from the settings. Instead, the round profile picture at the top has a small camera badge. Tapping it opens a menu: **Take photo** (camera), **Choose from library**, and **Remove picture** (only if there is one).
- Why: Lenny wanted it like in other apps: tap the picture to change it.
- Also: the camera permission text in `Config/Info.plist` now mentions profile pictures, because the camera is used for them too.
- Files: `ProfileView.swift`, `Config/Info.plist`.
- How to check: open the profile from Home and tap the picture. In the simulator "Take photo" offers the generated test photo (there is no camera). It was only seen in the preview so far.

**Step 25: Copyright row removed from the settings** (branch `profilsettings`)
- What: the row "HabitUs, 2026 · Nova SBE · Introduction to Programming" was removed from the "Info" section of the settings. Only the version is left.
- Why: Lenny wanted it out.
- Files: `ProfileView.swift`.

**Step 26: Logo and "HabitUs" at the top of Home** (branch `profilsettings`)
- What: the top of Home shows the app logo and "HabitUs" instead of "Hi Bene 👋 / Your habits". The profile picture on the right stays.
- Why: Lenny wanted the brand at the top.
- Files: `HomeView.swift`.
- How to check: run the app and log in. It builds, but it was not looked at on screen yet.

**Step 27: Enter the code from the confirmation email** (branch `email-code`)
- What: when "Confirm email" is turned on in Supabase, sign up no longer stops with an error. The card shows "Check your email", where you type the code from the email and press "Confirm". There is also "Send a new code" and "Back". If someone who never confirmed tries to log in, a new code is sent and the code screen opens (only when the password was right, so R3 still holds). With "Confirm email" off, nothing changes.
- How: `AuthService.signUp` now returns whether a code is needed. New `verifyEmailCode` (Supabase `verifyOTP(type: .signup)`) and `resendEmailCode`. `logIn` throws `EmailNotConfirmed` for that case. HabitCore `validateEmailCode`: 6 to 10 digits, spaces ignored, 2 tests (79 in total).
- Still needed in Supabase before turning it on:
  1. Custom SMTP: the built-in mailer only reaches team members. Use Brevo or Resend with a domain.
  2. The "Confirm signup" email template must contain the code `{{ .Token }}` instead of only the link.
  3. A higher email rate limit.
  4. Only then turn on "Confirm email".
- Files: `AuthService.swift`, `AuthView.swift`, `HabitCore/Sources/HabitCore/Validation.swift`, `ValidationTests.swift`.
- How to check: the `AuthView` preview "Code from email". With real emails only after the Supabase steps above. Not tested end to end yet.

**Step 28: The app is now called Habitract** (branch `rename-habitract`)
- What: everything the user sees says "Habitract" instead of "HabitUs": the name under the app icon, Home header, login card, onboarding, settings texts, invite share text and the camera permission text.
- Why: the name HabitUs is already taken (also as a domain for the confirmation emails).
- How: `CFBundleDisplayName = Habitract` in `Config/Info.plist`, plus the visible strings. On purpose NOT renamed: the Xcode project, target, folder `HabitUs/`, `HabitUsApp` and the bundle ID (AGENTS.md forbids changing it, and renaming the project would break everyone's checkout). The GitHub repo is still called HabitUs.
- Files: `Config/Info.plist`, `HomeView.swift`, `AuthView.swift`, `OnboardingView.swift`, `ProfileView.swift`, `LobbyView.swift`, `CreateGroupView.swift`, `Theme.swift`, `README.md`.
- How to check: run the app. Home shows "Habitract", the home screen of the simulator shows "Habitract" under the icon.

**Step 29: Forgot password** (branch `forgot-password`)
- What: under "Log in" there is now "Forgot password?". You enter your email, get a code by email, type the code and a new password, and are logged in with the new password. "Send a new code" and "Back" work like on the sign up code screen.
- Why: with real accounts and confirmed emails, people need a way back in without asking us.
- How: `AuthService.sendResetCode` (Supabase `resetPasswordForEmail`) and `setNewPassword` (`verifyOTP(type: .recovery)`, then `update(user:)` with the new password). The screen never says whether an account exists ("If there is an account for ..."), like R3. HabitCore: `validateEmail` and `validatePassword` split out of `validateSignUp`, so sign up and reset use the same rules; 2 new tests (81 in total). The code and the password are checked before the code is sent to Supabase, so a too short password does not use up the code.
- Supabase: the "Reset Password" email template must contain `{{ .Token }}` (Habitract style template, like Confirm signup).
- Known limit: the code logs you in before the new password is saved. If saving fails (for example no internet at exactly that moment), you are logged in but keep the old password.
- Files: `AuthService.swift`, `AuthView.swift`, `HabitCore/Sources/HabitCore/Validation.swift`, `ValidationTests.swift`.
- How to check: previews "Log in" and "Forgot password" in `AuthView`. With a real email: log out, "Forgot password?", enter the code from the email.

**Step 30: Password rules and "Repeat password"** (branch `forgot-password`)
- What: sign up and "Forgot password?" now ask for the password twice. Under the fields is a live checklist that turns green line by line: at least 8 characters, a capital letter, a small letter, a number, a special character, both passwords match. Logging in does not check the rules, so older accounts with simpler passwords still work.
- Why: the usual password rules, and typing it twice catches typos before the account exists.
- How: HabitCore `passwordRules(_:)` returns the rules with `isMet`; the view only shows them (`PasswordChecklist` in `AuthView.swift`). `validatePassword(_:repeated:)` throws the first missing rule or "The two passwords are not the same." `validateSignUp` got a `repeatedPassword` parameter. 3 new tests (84 in total).
- Supabase (recommended): Authentication → Sign In / Providers → Email → minimum password length 8 and "Lowercase, uppercase letters, digits and symbols", so the server checks the same rules and not only the app.
- Files: `HabitCore/Sources/HabitCore/Validation.swift`, `ValidationTests.swift`, `AuthService.swift`, `AuthView.swift`.
- How to check: `AuthView` previews "Sign up" and "Forgot password", or type a password in the app and watch the list.

**Step 31: Emails are live** (Supabase and Resend settings, no code)
- What: sign up now really sends a 6 digit code, and "Forgot password?" a reset code. Both emails are in the Habitract style (blue header, yellow code box).
- How: domain `habitractapp.com` bought by Lenny (Cloudflare), added and verified in Resend (region Ireland). In Supabase → Authentication → Emails → SMTP: host `smtp.resend.com`, **port 465**, username `resend`, password = a Resend API key with sending access (only in Supabase, never in the repo or chat), sender `noreply@habitractapp.com`, name "Habitract". Templates "Confirm signup" and "Reset Password" contain `{{ .Token }}`. Email rate limit raised. "Confirm email" turned on.
- Problem we had: the port was 448 instead of 465. Supabase then waits until it gives up and answers sign up with 504 after a long time, so the app only showed the spinner. The Supabase logs (Logs → Auth, `POST /auth/v1/signup` with 504) showed it.
- How to check: sign up with a new email, the code arrives within a minute (also check spam). Supabase `/auth/v1/settings` shows `mailer_autoconfirm: false`.

**Step 32: Onboarding in light and dark mode** (branch `design-startscreen`)
- What: the onboarding keeps its existing blue design in light mode and uses a darker blue gradient in dark mode. Its white and yellow text and buttons stay the same.
- Why: make the first screens fit the iPhone appearance without changing the design of other screens.
- Files: `OnboardingView.swift`, `docs/HANDOVER.md`.
- How to check: open the Welcome light and dark previews, or change the iPhone appearance while viewing onboarding. The app builds; the appearance has not yet been checked on a device.

**Step 33: A first Retro-inspired login design** (branch `design-startscreen`)
- What: the login and related account forms use a warm neutral background, a serif title, a simple card and rounded buttons. Colors adapt to light and dark appearance. Login, sign up and password recovery keep their existing behavior.
- Why: try a calmer visual direction inspired by the Retro photo app, starting with the login screen.
- Files: `AuthView.swift`, `docs/HANDOVER.md`.
- How to check: use the light and dark login previews and try login, sign up, confirmation and password recovery in the app. The design has not yet been checked on a device or tested with real accounts.

**Step 34: Matching onboarding design** (branch `design-startscreen`)
- What: the welcome and game description pages now match the login's neutral light and dark backgrounds, serif headings and rounded buttons. Illustrations use softer colors; the text and navigation stay the same.
- Why: carry the first design experiment through the whole introduction.
- Files: `OnboardingView.swift`, `docs/HANDOVER.md`.
- How to check: view the welcome and photo page previews in both appearances, then swipe through all pages in the app. Not yet checked visually on a device.

**Step 35: Restore the original introduction design** (branch `design-startscreen`)
- What: reversed the Retro-inspired login and onboarding design from steps 33 and 34. The onboarding light and dark backgrounds from step 32 remain.
- Why: Bene preferred the earlier appearance.
- Files: `AuthView.swift`, `OnboardingView.swift`, `docs/HANDOVER.md`.
- How to check: open the welcome light and dark previews and the login preview. Visual appearance has not yet been checked on a device.

**Step 36: First Home background design** (branch `design-interface`)
- What: Home has a soft blue gradient and a subtle dotted texture, with a darker version in dark mode. The title and habit cards use appearance-aware text and card colors.
- Why: connect Home to the blue introduction while keeping the photos and habit cards easy to see.
- Files: `HomeView.swift`, `docs/HANDOVER.md`.
- How to check: open the Home light and dark previews, and check an empty Home and a Home with habit cards in both appearances. Not yet checked visually on a device.

**Step 37: Home action cards** (branch `design-interface`)
- What: New Habit and Join Habit are now compact action cards with separate icon tiles, rounded corners and a small pressed effect. They keep their existing actions and adapt to light and dark mode.
- Why: give the two main actions a playful but restrained appearance that fits the Home background.
- Files: `HomeView.swift`, `docs/HANDOVER.md`.
- How to check: open Home in light and dark mode and tap both actions; check that each opens the same screen as before. Not yet checked visually or tapped on a device.

**Step 38: Cleaner Home actions** (branch `design-interface`)
- What: New Habit and Join Habit now use simple capsule shapes and clear icons, without the raised edge and separate icon tiles. The blue accent and light/dark colors remain.
- Why: Bene shared Retro screenshots as a reference for a calmer, cleaner interface.
- Files: `HomeView.swift`, `docs/HANDOVER.md`.
- How to check: open Home in light and dark mode and try both actions. Not yet checked visually or tapped on a device.

**Step 39: Create and join form design** (branch `design-interface`)
- What: the first New Habit and Join Habit screens use a soft blue background and clean rounded sections instead of the standard grouped form. Existing inputs, validation and navigation remain.
- Why: Bene wanted the screens opened by the two Home actions to feel cleaner and more distinctive, in light and dark mode.
- Files: `CreateGroupView.swift`, `JoinView.swift`, `docs/HANDOVER.md`.
- How to check: open both screens in light and dark mode, try the controls and advance to the contract. Not yet checked visually or tested with a real group.

**Step 40: More playful create and join screens** (branch `design-interface`)
- What: the first create and join screens now have colored icon badges, rounded cards with a subtle raised edge, a prominent yellow Next button and custom period choices. The invite code has its own inset field.
- Why: Bene wanted a more game-like feel while keeping the forms clean and readable in light and dark mode.
- Files: `CreateGroupView.swift`, `JoinView.swift`, `docs/HANDOVER.md`.
- How to check: in both appearances open New Habit and Join Habit, try all inputs and advance using Next. Not yet tested visually or with a real group.

**Step 41: Sharper form card text** (branch `design-interface`)
- What: the raised shadow now applies only to the card background, not its text and controls.
- Why: the previous shadow made labels such as "How often" look doubled.
- Files: `CreateGroupView.swift`, `docs/HANDOVER.md`.
- How to check: open New Habit and Join Habit in light and dark mode and check the section titles. Not yet visually checked on a device.

**Step 42: Softer group banner colors** (branch `design-interface`)
- What: groups without a photo get one of five muted blue, violet, warm brown, slate blue or rose gradients and a subtle circle pattern behind their chosen emoji. The group's ID picks a stable color; two groups can occasionally share one. A group photo still replaces the emoji and pattern.
- Why: Bene wanted group cards to feel varied and fit the app palette instead of using a standard green background.
- Files: `HomeView.swift`, `docs/HANDOVER.md`.
- How to check: compare several groups without photos and one with a photo in both appearances. The same banner is also used in group info. Not yet checked visually on a device.

**Step 43: Subtle varied group banners** (branch `design-interface`)
- What: emoji banners use a softly tinted gradient and one of three understated shapes, selected from the group ID. Colors adjust to light or dark appearance and remain stable when the app redraws. Photos still fill the banner.
- Why: Bene wanted less intense color and more variety across groups.
- Files: `HomeView.swift`, `docs/HANDOVER.md`.
- How to check: compare several groups in both appearances and confirm a group photo still displays. Not yet checked visually on a device; similar groups can still occur by chance.

**Step 44: Emoji-inspired group banners** (branch `design-interface`)
- What: emoji banners derive a muted background hue from colorful pixels in the selected emoji. Neutral or ambiguous emoji use the stable group-ID color. Shape, position and angle vary using the group ID, and both appearances stay muted.
- Why: Bene wanted the background to relate to the emoji and the decorative shapes to vary too.
- Files: `HomeView.swift`, `docs/HANDOVER.md`.
- How to check: compare colorful and neutral emoji in both appearances, then reopen the group to see stable shapes. Group photos should still display. Not yet visually checked on a device.

**Step 45: Serif type and golden group names on Home** (branch `design-interface`)
- What: Home text uses a system serif style inspired by the Retro reference, and group names use a dark gold in light mode and yellow in dark mode. Card shadows apply to the background so text stays sharp.
- Why: Bene wanted to try the yellow accent for group names and a Retro-inspired typeface on this page.
- Files: `HomeView.swift`, `docs/HANDOVER.md`.
- How to check: compare Home and its group cards in both appearances. The exact Retro font is not included; this uses the system serif font. Not yet checked visually on a device.

**Step 46: Restore Home text styling** (branch `design-interface`)
- What: reversed the serif font and gold group names from step 45, restoring the previous Home appearance. Emoji-inspired group banners remain.
- Why: Bene preferred the earlier text styling.
- Files: `HomeView.swift`, `docs/HANDOVER.md`.
- How to check: open Home in light and dark mode and check group names and banners. Not yet checked visually on a device.

**Step 47: Consistent group backgrounds and chat area** (branch `design-in-group`)
- What: group screens and contract use the same light/dark blue background as Home. The task card uses the same emoji-derived colors and pattern as the Home group banner. Chat has its own rounded area, and the message field and key cards adapt to appearance.
- Why: Bene wanted consistent backgrounds, matching group colors and a clearer boundary around chat.
- Files: `HomeView.swift`, `GroupView.swift`, `TaskCard.swift`, `FeedView.swift`, `BonusCard.swift`, `Podium.swift`, `ContractView.swift`, `LobbyView.swift`, `GroupInfoView.swift`, `GroupLookView.swift`, `LeaderboardView.swift`, `ResultsView.swift`, `PlayerProfileView.swift`, `docs/HANDOVER.md`.
- How to check: view an active group, lobby, group info, leaderboard, player profile, results and signing screen in both appearances; compare its emoji banner and task card, and send a message. Not yet visually checked or tested with a real group.

**Step 48: Group options and leaderboard styling** (branch `design-in-group`)
- What: the active group name is larger; the three-dot button opens a custom options panel with the same permitted actions and confirmations. The leaderboard has a small podium, clearer ranked rows and a separate points chart; the current player is highlighted.
- Why: Bene wanted a clean but more game-like group and leaderboard, inspired by the supplied examples.
- Files: `GameScreen.swift`, `GroupView.swift`, `LeaderboardView.swift`, `docs/HANDOVER.md`.
- How to check: in both appearances open group options as owner and member, check each action and its confirmation, and inspect the leaderboard with different group sizes. Not yet visually checked or tested with a real group.

**Step 49: Put the leaderboard chart back on top** (branch `design-in-group`)
- What: removed the leaderboard podium and placed the points history chart above the redesigned ranking rows.
- Why: Bene preferred the graph at the top as before.
- Files: `LeaderboardView.swift`, `docs/HANDOVER.md`.
- How to check: open the leaderboard and verify the chart appears above the rankings. Not yet checked visually on a device.

**Step 50: Show initials on profile photos** (branch `design-in-group`)
- What: a small initial badge appears on a profile photo. Profiles without a photo keep the existing large initial. The shared component is used on Home, in groups, chat and profiles.
- Why: Bene wanted the player's initial to stay visible even after choosing a profile picture.
- Files: `Pictures.swift`, `docs/HANDOVER.md`.
- How to check: compare players with and without photos on Home and in a group, including overlapping avatars. Not yet checked visually on a device.

**Step 51: Center initials on profile photos** (branch `design-in-group`)
- What: the initial moves from the edge to the center of the photo, on a dark circular background for readability.
- Why: Bene wanted the letter clearly readable over any photo.
- Files: `Pictures.swift`, `docs/HANDOVER.md`.
- How to check: view profile photos of different sizes and brightness on Home and in a group. Not yet checked visually on a device.

**Step 52: Smaller centered initials** (branch `design-in-group`)
- What: reduced the size of the centered initial and its dark background on profile photos.
- Why: Bene liked the treatment but wanted it a little smaller.
- Files: `Pictures.swift`, `docs/HANDOVER.md`.
- How to check: view profile photos on Home and in a group. Not yet checked visually on a device.

**Step 53: Softer initial background** (branch `design-in-group`)
- What: made the dark circle behind profile photo initials more transparent.
- Why: Bene wanted the letter to remain readable without a strong dark edge.
- Files: `Pictures.swift`, `docs/HANDOVER.md`.
- How to check: compare initials over light and dark profile photos. Not yet checked visually on a device.

**Step 54: First Retro-inspired app-wide design pass** (branch `interface-overhaul`)
- What: major titles use a system serif, body text uses the default system typeface, and shared buttons are flatter capsules. Home, group pages, onboarding, login, setup and profile use a warm light or near-black dark background with adaptive cards. The existing app logo, content and behavior remain.
- Why: Bene requested a first overall design experiment inspired by Retro's clean typography and neutral surfaces.
- Files: `Theme.swift`, `HomeView.swift`, `CreateGroupView.swift`, `OnboardingView.swift`, `AuthView.swift`, `ProfileView.swift`, text styles in `Views/`, `docs/HANDOVER.md`.
- How to check: inspect onboarding, login, Home, create/join, groups, contract and profile in both appearances. The exact Retro font is not included; the system serif is an approximation. This is a first pass, not yet visually checked on a device or tested end to end.

**Step 55: Restore the previous app design** (branch `interface-overhaul`)
- What: reverted the Retro-inspired overall design experiment from step 54, restoring the previous colors, typography and controls.
- Why: Bene preferred the earlier design.
- Files: the same `Views/` files changed in step 54 and `docs/HANDOVER.md`.
- How to check: compare the app with the design before step 54 in light and dark mode. Not yet visually checked on a device.

**Step 56: Stronger game-inspired colors** (branch `interface-overhaul`)
- What: the shared Home/group/setup background uses a stronger blue gradient for each appearance, headings use a heavier rounded system font, and common buttons and Home cards have clearer edges. The existing muted emoji banner colors remain.
- Why: Bene requested a more colorful, higher-contrast game-inspired look while supporting light and dark mode.
- Files: `Theme.swift`, `HomeView.swift`, `CreateGroupView.swift`, `docs/HANDOVER.md`.
- How to check: compare onboarding, Home, group and create/join screens in both appearances, including text and buttons. The app builds; the appearance has not yet been visually tested on a device or formally contrast audited.

**Step 57: Stronger group colors and emoji pattern** (branch `interface-overhaul`)
- What: the shared blue background and emoji-based group gradients are a little more saturated. Small, faint copies of the chosen emoji are scattered behind the group banner and task card; their placement stays stable for each group. Group photos still cover the banner background.
- Why: Bene wanted stronger colors and a playful emoji pattern, while keeping light and dark appearances readable.
- Files: `HomeView.swift`, `docs/HANDOVER.md`.
- How to check: compare several groups and emoji in both appearances on Home and in their task cards. Not yet visually checked on a device or formally contrast audited.

**Step 58: Classic system typography** (branch `interface-overhaul`)
- What: changed rounded system fonts in the app views to the standard system typeface, including shared headings. Existing weights, colors and layouts remain.
- Why: Bene preferred a more classic, less rounded font throughout the app.
- Files: text styles in `Views/`, `docs/HANDOVER.md`.
- How to check: inspect text across onboarding, Home, group, chat and settings in both appearances. Not yet visually checked on a device.

**Step 59: Square group cards experiment** (branch `interface-overhaul`)
- What: group cards on Home and their emoji/photo banners have square corners. The group info banner retains its previous shape.
- Why: Bene wanted to try square group boxes.
- Files: `HomeView.swift`, `docs/HANDOVER.md`.
- How to check: inspect group cards with emoji and photos in both appearances. Not yet visually checked on a device.

**Step 60: Lighter group card text** (branch `interface-overhaul`)
- What: group names and status text on Home use lighter font weights.
- Why: Bene wanted thinner text, especially for the group names.
- Files: `HomeView.swift`, `docs/HANDOVER.md`.
- How to check: view group cards on Home in both appearances. Not yet checked visually on a device.

**Step 61: Restore rounded type and group cards** (branch `interface-overhaul`)
- What: restored rounded system fonts and rounded Home group cards and banners. Group names and status text keep the lighter weights from step 60.
- Why: Bene preferred the earlier rounded style with thinner group card text.
- Files: text styles in `Views/`, `HomeView.swift`, `docs/HANDOVER.md`.
- How to check: inspect the Home group cards and typography in both appearances. Not yet checked visually on a device.

**Step 62: Retro-style overall experiment** (branch `interface-overhaul`)
- What: this experiment uses black/neutral backgrounds, adaptive cards, serif headings, standard body type, and flat pill buttons. Emoji-only group banners use neutral backgrounds, while group photos remain visible. Onboarding, login, Home, group pages and profile follow the neutral palette.
- Why: Bene requested another overall test closely inspired by the supplied Retro screenshots.
- Files: `Theme.swift`, `HomeView.swift`, `OnboardingView.swift`, `AuthView.swift`, `ProfileView.swift`, `CreateGroupView.swift`, `JoinView.swift`, other `Views/` typography, and `docs/HANDOVER.md`.
- How to check: inspect onboarding, login, Home, setup, group and profile in both appearances and test their controls. The system serif approximates the reference font; the exact font is not included. Not yet visually checked on a device or tested end to end.

**Step 63: Restore emoji backgrounds** (branch `interface-overhaul`)
- What: restored the emoji-based muted colors and small emoji pattern on group banners and task cards; the neutral Retro-style app surfaces remain.
- Why: Bene wanted to keep the emoji backgrounds in the design experiment.
- Files: `HomeView.swift`, `docs/HANDOVER.md`.
- How to check: compare groups with different emoji in light and dark mode, and verify group photos still display. Not yet visually checked on a device.

**Step 64: Match create and join screens to neutral design** (branch `interface-overhaul`)
- What: the first New Habit and Join Habit screens use serif introductory titles, quiet section labels and adaptive neutral cards. Period choices use neutral pill buttons. The confirmation pages use the matching background.
- Why: Bene wanted the setup screens' typography and colors to match the current Retro-inspired experiment.
- Files: `CreateGroupView.swift`, `JoinView.swift`, `docs/HANDOVER.md`.
- How to check: open both flows in light and dark mode, choose each frequency, and proceed through the contract. Not yet visually checked or tested with a real group.

**Step 65: Show profile photos without initials** (branch `interface-overhaul`)
- What: profile photos are shown without the initial overlay; profiles without photos still show their initial. Names are also displayed under the group podium photos, alongside the existing names in group lists and chat.
- Why: Bene wanted photos unobstructed while keeping players identifiable within a group.
- Files: `Pictures.swift`, `Podium.swift`, `docs/HANDOVER.md`.
- How to check: view players with and without photos on Home and in a group, including the podium. Not yet visually checked on a device.

**Step 66: Move round bonus below leaderboard** (branch `interface-overhaul`)
- What: the round bonus card is no longer in the group screen; it appears below the rankings on the leaderboard instead. Its values and scoring rules are unchanged.
- Why: Bene wanted the group screen less crowded and bonus information on the leaderboard.
- Files: `GroupView.swift`, `LeaderboardView.swift`, `docs/HANDOVER.md`.
- How to check: open an active group, then its leaderboard; the bonus appears only below the rankings. Not yet visually checked on a device.

**Step 67: Password hints only when something is wrong** (branch `login/signup-edits`)
- What: the password checklist under sign up and "Forgot password?" is gone while everything is fine. As soon as you type, only the rules that are still missing appear in red ("Needs a number"), and each line disappears once it is met. "The passwords are not the same" appears only after you typed something into the second field.
- Why: a list of six grey lines looked busy before anyone typed anything.
- How: `PasswordChecklist` in `AuthView.swift` filters `passwordRules` to the missing ones. The rules themselves (HabitCore) did not change.
- How to check: `AuthView` preview "Password hints" (empty, too simple, not the same, all fine).

**Step 68: "X left the group" and on hold below 3 players** (branch `group-updates`, migration 006, rule R30)
- What: when an accepted member leaves, the chat shows a grey note in the middle: "Lenny left the group." If a **running** challenge then has fewer than 3 players, a second note says "Only 2 players are left, so the game is on hold. Invite someone with the code to go on." While on hold nobody can check in, and the group screen shows a card "The game is on hold" with an "Invite friends" button. As soon as a third player is accepted, it goes on. In the lobby people come and go without notes. Withdrawing a pending request stays quiet.
- Why: with 2 players the X vote hardly works. Ending the challenge would be too hard now that people can join later (step 69).
- How: inside the database function `leave_group` (`006_leave_messages.sql`): it writes the note as a message with `system = true`. The insert policy on `messages` refuses `system = true`, so no app can fake a note. "On hold" is not stored: HabitCore `isOnHold` computes it from the number of accepted members (`minimumPlayers = 3`, also used for the start check), and `taskStatus` refuses check-ins while on hold. The rounds keep counting while on hold, for everyone the same. The leave dialog warns before.
- Files: `006_leave_messages.sql`, `Rounds.swift`, `Tasks.swift`, `ChatService.swift`, `Rows.swift`, `FeedView.swift` (`SystemNote`), `GameScreen.swift`, `GroupView.swift`, `TaskCard.swift`.

**Step 69: Join a running challenge** (branch `group-updates`, migration 007, rule R29)
- What: the invite code now works until the challenge is over, also in the group screen menu ("Invite friends"). The join screen says "This challenge is already running...". The owner sees a card "1 join request" with Accept and Decline on the group screen. Someone accepted while it runs starts in the **next** round, and the chat says "Mia joined the group and starts in round 4." Until then they see "Welcome! You start in round 4" and can already chat and vote. When the group has 3 players again, the chat says "There are 3 players again, the game goes on." Starting the session no longer declines open requests.
- Points (option C, chosen by Lenny): for every round before their first, a late joiner gets the **average points of the members who played that round** (rounded down). Their streak, complete rounds, grade and history only count their own rounds. The player profile says "Joined in round 4. Rounds 1 to 3 got the group average: 38 pts."
- Known weakness (say it yourselves): the average is a gift. Someone could join late on purpose, or leave and join again, to get the average without the work. Fine for friends, not for money.
- How: `007_late_join.sql` adds `memberships.first_round`. A trigger sets it when the owner accepts (current round + 1), so no app can change it, and writes the note. `join_by_code` and `preview_group_by_code` allow running challenges (not ended ones). HabitCore: `Member.firstRound`, `firstRound(acceptedAt:in:)`, `taskStatus(firstRound:)`, and `leaderboard` gives the average for earlier rounds (`LeaderboardRow.firstRound`, `catchUpPoints`). 6 new tests (92 in total).
- Supabase: **run `006_leave_messages.sql` (again, it is safe to rerun) and then `007_late_join.sql` in the SQL editor.** The app also works before that, but without notes, late joining and first rounds.
- Files: `007_late_join.sql`, `Models.swift`, `Rounds.swift`, `Tasks.swift`, `Scoring.swift`, tests, `GroupService.swift`, `Rows.swift`, `JoinView.swift`, `GroupView.swift` (`NoticeCard`, previews), `TaskCard.swift`, `PlayerProfileView.swift`, `LobbyView.swift`, `SPEC.md` (R29, R30).
- How to check: preview "On hold, with a join request" in `GroupView.swift`. For real: a running group with 3 players, one leaves → note and on hold; a 4th person joins with the code, owner accepts → note, game goes on, the new player starts next round with the average points.

**Step 70: Invite code in the group info** (branch `group-updates`)
- What: the group info (tap the member pictures at the top of the group screen) now shows the invite code big at the top, with "Copy" and "Share". While the challenge runs it says that new players start in the next round and get the group average. After the end the code is grey with "The challenge is over, so the code does not work any more."
- Why: so everyone in the group can always find the code and invite friends later (R29).
- Files: `GroupInfoView.swift` (`inviteSection`).
- How to check: preview of `GroupInfoView`.

**Step 71: Refresh the presentation handover** (branch `presentation-handover`)
- What: updated the current status, file map, test counts, database migration list and known limitations; added a presentation guide based on `main` at `311d53b`.
- Why: Bene wanted the team to understand our combined changes and be ready to explain the code and storage.
- Files: `docs/HANDOVER.md` only.
- How to check: compare section 15 with the linked source files. `swift test` completed with 92 tests and 0 failures on 23 Nov; live Supabase, camera and the full demo were not checked for this update.

**Step 72: Pause with a reason** (branch `pause-the-streak`, rule R18)
- What: under the camera button on the task card there is now **"Can't today? Take a pause"**. It opens a sheet:
  - a text field for the reason (1 to 200 characters, with a counter)
  - a short explanation: the pause counts as done with full points, but if more than half of the others press 👎 within 48 hours, the points are gone
  - "Post pause" and Cancel. Errors show in red in the sheet
  - the pause appears in the chat as "⏸ Pause · ACCEPTED" with 👍/👎 and **"Can be rejected until Tue 18:40"**
- The rule (R18, updated in `SPEC.md`):
  - accepted by default, counts like a valid photo
  - the others have **48 hours after posting** to reject it with 👎. This window does not depend on the round: a pause on the last day of a round can still be rejected in the next round
  - if more than half of the others press 👎 in time, the pause is rejected and that task has failed for its round. It cannot be redone
  - **retroactive:** a rejection after the round ended takes the points away afterwards, also the round bonus and the streak. Nothing extra was needed for that: points are computed from check-ins, never stored
  - after 48 hours the pause is final. Photos keep the old rule: votes only while their round runs (R19)
  - not limited to one per day (unlike photos). Only while the challenge runs, not on hold (R30), and from my first round on (R29)
- How:
  - HabitCore `Votes.swift`: `pauseVotingWindow` (48 h), `pauseVotingEnds(_:)`, and `canReact` now has two cases: a pause while `now < pauseVotingEnds`, a photo while its round is the current one. 6 new tests, written first (98 in total): pause rejectable in round 2 within 48 h, not after 48 h, not by the author, rejection in round 2 takes round 1 points (25 → 0) and the streak away, photos still freeze at the end of their round.
  - Service: `CheckinService.addPause` was a stub. It checks the reason with `validatePauseReason`, checks `canPause`, then inserts a `checkins` row with kind "pause" and the trimmed reason. The database sets time and day, like for photos.
  - `GroupData.canPause(now:)` in `GroupService.swift`: challenge active, not on hold, my first round has started, and I have an open task.
  - The unused `notBuiltYet` constant was removed from `SupabaseClient.swift`.
  - Database: no change. `checkins` already has kind 'pause' and `text`, and RLS already allows it.
- Why: R18 was the last missing must-have from SPEC section 7. The 48 hours give the group a fair chance to react to a pause posted late in a round.
- Files: `Votes.swift`, `VotesTests.swift`, `CheckinService.swift`, `GroupService.swift`, `SupabaseClient.swift`, `TaskCard.swift`, `PauseSheet.swift` (new), `GroupView.swift`, `FeedView.swift`, `SPEC.md` (R18, and R19 now says "photo check-ins" so it does not contradict R18).
- How to check: `cd HabitCore && swift test` → 98 green. The `PauseSheet` preview renders. With three accounts: A takes a pause → it shows in the chat with "Can be rejected until …"; B and C press 👎 → REJECTED, A's task shows ✗ and the points drop.
- Not tested: the `GroupView` preview did not start (the simulator timed out launching the app), so the new button on the task card was only checked by building, not on screen. Not tried against the live Supabase project or on real phones yet.
- Known limit: like the other game rules, the 48 hours are checked in the app (HabitCore), not in the database. A modified app could still vote later.

<!-- New entries go below. Template:
**Step N: Title** (branch `x/name`, PR #N)
- What:
- Why:
- Files:
- How to check:
-->


## 15. Presentation cheat sheet: current `main`

This section describes repository commit `311d53b`, not every experiment in the history above.
The experiments in steps 32–66 were merged through PR #22; later steps in that history describe
what survived. The actual shared database and three-phone flow still need to be checked separately.

### A 30-second explanation

"Habitract helps friends keep a habit together. They create a group, agree on a contract, and
check in with live photos. Other members can react, and the app calculates points and a ranking.
The iPhone app is built with SwiftUI; Supabase provides login, a Postgres database and private file
storage. We separated the game calculations into HabitCore so we can test them without the internet."

### Where to find what we built

All app source paths below start at `HabitUs/` in the repository.

- **App startup:** `HabitUsApp.swift` → `RootView` decides between the setup hint, onboarding,
  login and Home. Login changes come from `AuthService.userChanges()`.
- **Onboarding and sign-in:** `Views/OnboardingView.swift` explains the app; `Views/AuthView.swift`
  contains login, sign-up, email confirmation and password-reset screens. `Services/AuthService.swift`
  calls Supabase Auth; `HabitCore/Sources/HabitCore/Validation.swift` checks input.
- **Group collection:** `Views/HomeView.swift` shows New Habit, Join Habit and group cards.
  `GroupBanner` shows a group photo or emoji; `GroupEmojiBackground` derives a muted color from
  the emoji when possible and falls back to a stable group-ID color. The small emoji pattern and
  the task card reuse this presentation. This visual calculation does not change stored group data.
- **Light and dark appearance:** `HomeBackground` in `HomeView.swift`, shared colors and fonts in
  `Views/Theme.swift`, and system colors such as `secondarySystemBackground` determine the look.
  Large headings use the iOS system serif font; it is an approximation, not Retro's original font.
- **Create, join and sign:** `Views/CreateGroupView.swift`, `Views/JoinView.swift` and
  `Views/ContractView.swift` display the forms and contract. `Components/SignaturePad.swift` captures
  a signature. `Services/GroupService.swift` writes and reads the group and membership.
- **Inside a group:** `Views/GameScreen.swift` selects lobby, active group or results;
  `Views/GroupView.swift` assembles tasks, voting, rankings and chat.
  `Components/TaskCard.swift` shows progress and the camera action;
  `Components/CameraView.swift` opens the iPhone camera. The simulator offers a generated test photo.
- **Chat and reactions:** `Components/FeedView.swift` renders messages and photo check-ins;
  `Components/VoteDeck.swift` provides the photo voting shortcut. `Services/ChatService.swift` saves
  messages; `Services/CheckinService.swift` saves reactions. `GroupView` reloads every 10 seconds
  while open, and supports pull-to-refresh; this is polling, not push notifications.
- **Ranking:** `Views/LeaderboardView.swift` shows the points chart, ranking and round bonus;
  `Components/BonusCard.swift` draws the bonus, and `HabitCore/Sources/HabitCore/Scoring.swift`
  computes the actual points. `Views/PlayerProfileView.swift` shows a player's history.
- **Group and profile pictures:** `Views/Components/Pictures.swift` loads pictures through
  `Services/PictureService.swift`. A profile photo is shown without a letter over it; if no photo
  loads, the first letter is shown. `Views/ProfileView.swift` and `Views/GroupLookView.swift`
  provide the relevant choices.

### Where the information is stored

- **Accounts and sessions:** Supabase Auth handles sign-up and login; the app observes auth state.
  The Supabase SDK retains the session on the device. App tables do not store the user's password.
- **Database:** `profiles`, `groups`, `memberships`, `checkins`, `reactions`, and `messages` are
  Postgres tables. Their definitions and RLS policies are in `supabase/migrations/001_schema.sql`;
  migrations 002–007 add features and change functions. The SQL files are versioned code, not a
  guarantee that the team's hosted database currently has the same state.
- **Files:** proof images are uploaded to the private `proofs` bucket by `Services/PhotoService.swift`;
  profile and group pictures use the private `pictures` bucket via `Services/PictureService.swift`.
  Database rows contain paths to the files. GIPHY messages store a GIF URL, not the GIF itself.
- **Signature:** the drawn signature is converted to a PNG and encoded into the membership's
  `signature` field; `SignaturePad.swift` and migration 004 explain the format and size limit.
- **Configuration:** `Config/Base.xcconfig` includes local configuration. Each developer keeps
  Supabase URL, public anon/publishable key and GIPHY key in their ignored `Config/Secrets.xcconfig`;
  personal signing values belong in ignored `Config/Local.xcconfig`. Never share a service-role key.
- **Points:** scores are computed from check-ins and reactions by HabitCore; they are not saved as
  a points column. A rejected photo can therefore change the next calculation.

### Questions the team can practice

1. **What happens when someone taps the camera button?** `TaskCard` calls `GroupView`, which opens
   `CameraView`. After a photo, `CheckinService.addPhoto` checks `taskStatus`, `PhotoService` uploads
   a resized JPEG to `proofs`, and the service inserts a `checkins` row. The database provides the
   timestamp/day. An upload or permission error must still be checked on a real phone.
2. **How does a photo become invalid?** `FeedView` or `VoteDeck` calls `setReaction`; `Votes.swift`
   checks whether more than half of the other accepted members gave thumbs down. The author cannot
   vote on their own photo. The current code recomputes validity using the current accepted member
   count, so departures can change the threshold.
3. **How are points calculated?** A done task is 20 points; a full round gets +25%, increasing by
   5 percentage points per consecutive full round, up to a total bonus of +50%. `Scoring.swift`
   performs the calculation; `LeaderboardView.swift` displays it.
4. **What if somebody joins late or leaves?** `007_late_join.sql` sets `first_round` to the next
   round when a late joiner is accepted. `Scoring.swift` gives them earlier rounds' group averages,
   rounded down. Below three accepted players the challenge is on hold, but calendar rounds continue.
   This catch-up rule can be exploited by rejoining; it is a known limitation.
5. **What protects private data?** The migrations define RLS policies and private storage buckets.
   The app's public key identifies the project; it does not replace RLS. We must verify the deployed
   policies with separate accounts; a successful local rule test does not prove database security.
6. **What is tested and what is not?** 98 HabitCore tests passed on 23 Nov. These cover local rules,
   not the hosted database, RLS, camera, visual layout or a real multi-user end-to-end session.
   Pause with a reason is built (step 72), the 48 hour window is tested in HabitCore. Never claim the live demo was tested unless the
   team has actually rehearsed it.
