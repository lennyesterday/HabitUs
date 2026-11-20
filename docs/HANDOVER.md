# Habitract (repo: HabitUs): what has been built so far

Written by Lenny for Bene and Vincent, 19 Nov 2026. Read it once, then open the files it points to.
Everything here describes the code on branch `test-run-1` / PR #10 ("Initial version of HabitUs").
Where the code and `SPEC.md` disagree, section 8 lists it on purpose.

---

## 1. The app in one paragraph

Friends form a group around one habit ("Gym, 3 times per week"). Everyone signs a contract by hand.
Every round (a day, a week or 28 days) each member proves each task with a **live photo** from the
camera. The photos appear in the group chat. If more than half of the other members press **X**, the
photo does not count. Done tasks give points, full rounds give a bonus, rounds in a row give a
streak bonus, and a leaderboard shows who delivers.

---

## 2. Status

### Built (the app builds, the 72 rule tests are green)

Tried in the simulator against our Supabase project: onboarding, sign up, log in, Home, the GIF search.
**Not yet tried end to end with three real accounts:** create → join → accept → start → check in →
leave / delete, profile and group pictures. Do this together once before the feature freeze.


| Area | What you can do |
|---|---|
| Start | Onboarding pages (shown whenever nobody is logged in), sign up, log in, log out |
| Home | One card per habit group: picture or emoji, member pictures, status, my points and rank |
| Create | Name, habit, emoji icon (all emojis, with search), how often, end date or open end, own rules |
| Contract | Read the rules, sign with the finger, get a 6 character invite code |
| Join | Enter code, read the contract first, sign, wait for the owner |
| Lobby | Owner accepts or declines requests, starts the session with at least 3 members |
| Group screen | Task card with countdown, camera check-in (test photo in the simulator), bonus card, podium, rankings, chat with text and GIFs, refresh every 10 s |
| Leaderboard | Tap the podium: line chart of points per round, all players with full rounds, streak, pauses |
| Player profile | Tap a player under the podium: grade A to D, stats, history round by round with photos, pauses and missed tasks |
| Group info | Tap the member pictures at the top of the group screen: picture, facts (how often, round length, start, end, current round, owner), contract and own rules with my own signature under it, how points work |
| End | Owner can finish the challenge, results screen with the champion |
| Groups | Everyone can leave any time, the owner can delete the group for everyone |
| Profile | Profile picture, group picture and icon (owner), settings, "How it works" |

### Not built yet (Milestone 2, needed before the feature freeze on Friday)

| Missing | Why it matters | Where |
|---|---|---|
| **Like and X buttons** on proofs | The demo story (SPEC §14) is "the other two press X, the photo turns invalid". The rule exists and is tested, only the button and the service are missing | `CheckinService.setReaction`, `FeedView` |
| **Pause with a reason** | R18 | `CheckinService.addPause`, a sheet in `GroupView` |
| RLS manual check with screenshots (S5) | Evidence for the security criterion | `docs/` |
| README names and student numbers, `DECISIONS.md`, `seed.sql` | Hand-in requirements | repo root, `supabase/` |

Both missing services are stubs that throw "This part is not built yet."

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
                   Tested with `cd HabitCore && swift test` (72 tests, about 0.01 s).

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
   an accepted member (`is_accepted`) and the session is running (`is_active`). Even a hacked app
   cannot post into another group.
6. Back in the view, `reload()` loads everything again and HabitCore recomputes points, rank, bonus.

---

## 5. HabitCore: the rules

| File | Main functions | Rules | Tests |
|---|---|---|---|
| `Models.swift` | plain data: `HabitGroup`, `Member`, `Checkin`, `Reaction`, `TaskStatus`, `LeaderboardRow`, `RuleError` | – | – |
| `Rounds.swift` | `phase`, `currentRound`, `round(of:in:)`, `timeLeft`, `canStart`, `localDay`, `roundCount` | R8, R9, R14 | 14 |
| `Tasks.swift` | `taskStatus` (done, failed, open, canCheckInToday) | R10 to R12, R19 | 10 |
| `Votes.swift` | `xThresholdReached`, `isValid` | R15 to R18 | 6 |
| `Scoring.swift` | `scoreRounds`, `roundBonusPercent`, `leaderboard`, `grade` (A to D) | R20 to R24 | 19 |
| `Validation.swift` | `validateSignUp`, `validateGroup`, `validateGroupIcon`, `validateSignatureImage`, `validateMessage`, `validatePauseReason`, `validateGifURL` | R1, R4, R18, R26 | 20 |
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

Migrations are run once, in order, in the Supabase SQL editor. All five are already applied to our project.

| File | What it adds |
|---|---|
| `001_schema.sql` | 6 tables (`profiles`, `groups`, `memberships`, `checkins`, `reactions`, `messages`), RLS on every table, helper functions `is_accepted`, `is_owner`, `is_active`, private bucket `proofs`, function `join_by_code` |
| `002_profiles_and_join_preview.sql` | trigger that creates the profile at sign up, `preview_group_by_code` (read the contract before joining) |
| `003_chat_gifs.sql` | `messages.gif_url`, only links to GIPHY's GIF servers allowed |
| `004_leave_delete_signature.sql` | `leave_group` (owner role moves to the member who joined first, last one out deletes the group), owner may delete the group, signature size limit |
| `005_icons_and_pictures.sql` | `groups.icon`, `groups.photo_path`, `profiles.photo_path`, private bucket `pictures` with policies |

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
| `AuthService.swift` | sign up, log in (same error for unknown email and wrong password, R3), log out, profile, profile picture |
| `GroupService.swift` | create, preview, join, accept/decline, start, finish, leave, delete, change look, Home cards, `load` (everything for one group) |
| `CheckinService.swift` | photo check-in, feed (**pause and like/X are stubs**) |
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

We decided these on purpose. The SPEC text still needs updating (sections 1, 3, 7).

| Change | SPEC said | Why we changed it | Watch out |
|---|---|---|---|
| Leave a group any time | "Later" / contract binding | Contracts are a fun element, people must be able to leave | Fewer members means fewer X are needed, also for older photos; a group can drop below 3 |
| Signature drawn with the finger | typed name | feels more like a real contract | stored as a small PNG (max 40 KB) in `memberships.signature` |
| GIFs in the chat (GIPHY) | text only | fun | third party service: search terms and IP go to GIPHY; the GIPHY key is in the app |
| Group icon (emoji), profile and group pictures | avatar emoji | looks better, closer to the design references | pictures may come from the photo library, proofs still only from the camera |
| Onboarding pages and new design | – | explain the app, make it fun | inspired by PlayUs, but toned down on purpose: it is a habit app, not a game ("New Habit", not "New Game") |
| Email confirmation, forgot password, password rules | no email verification, 8 characters | real accounts: a 6 digit code from the email, a way back in, the usual password rules (steps 27, 29, 30, 31) | emails go through Resend with our own domain `habitractapp.com` (about 10 € a year, paid by Lenny); if Resend or the SMTP settings break, nobody can sign up |

---

## 9. Known limits (say them yourselves in the walkthrough)

- Game rules run in the app, access rules in the database. A hacked app could break a game rule *inside its own group* (e.g. two photos a day), but never get into another group.
- No account deletion. Email verification and password reset exist since steps 27 and 29.
- The password rules are checked in the app. The server only checks them if they are also set in Supabase (step 30).
- A photo of a screen can fake a "live" photo. That is exactly why the group can press X.
- No push notifications, no live updates (the group screen reloads every 10 seconds).
- Not tested automatically: RLS and the database functions, camera, layout. RLS is checked by hand (S5).
- GIPHY sees search terms and IP addresses.

---

## 10. Getting started on your Mac (15 minutes)

1. `git clone https://github.com/lennyesterday/HabitUs.git` and open `HabitUs.xcodeproj`.
2. Copy `Config/Local.example.xcconfig` → `Config/Local.xcconfig`, set your team and a suffix (README).
3. Copy `Config/Secrets.example.xcconfig` → `Config/Secrets.xcconfig`, ask Lenny for the three values.
4. `cd HabitCore && swift test` → 84 tests green.
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

## 11. Proposed split for the rest

| Who | Task | Area | Files |
|---|---|---|---|
| Bene | 👍 and 👎 buttons on photos and pauses (R15, R16, R17, R19; "X" in the SPEC and code = 👎 in the app) | B | `CheckinService.setReaction`, `Components/FeedView.swift` |
| Vincent | Pause with reason (R18) | B | `CheckinService.addPause`, new pause sheet, `TaskCard` |
| Vincent | RLS manual check S5 with two accounts in two groups, screenshots | A | `docs/` |
| Lenny | README (names, student numbers), `DECISIONS.md`, SPEC update, `seed.sql`, demo setup | C | repo root, `supabase/` |
| All | Security checklist S1–S13, teach-back on Saturday, demo rehearsal on the phones | – | SPEC §11 |

---

## 12. Questions to expect (with short answers)

| Question | Short answer |
|---|---|
| Your key is in the app. Is that safe? | It is the public anon key. Every table and bucket has RLS, so the key alone shows nothing. The service role key is never in the app. |
| Can I see another group's photos? | No. The storage policy checks membership of the group folder in the database. |
| Why are points not stored? | They cannot get out of sync. An invalid photo needs no correction. |
| How do you test rules about weeks without waiting? | Time is a parameter. Tests pass any `now`. |
| Why a separate HabitCore package? | Rules testable in seconds without phone, internet or database. Clear for the walkthrough. |
| What happens when the owner leaves? | `leave_group` gives the owner role to the member who joined first, in one locked database step. If nobody is left, the group is deleted. |
| Why `security definer`? | A joiner is not a member yet, so RLS would hide the group. The function itself checks only what is needed. |
| How do you stop fake photos? | Camera only, database timestamp, and the group can press X. No AI detection on purpose. |
| How are passwords stored? | Only Supabase Auth, as a bcrypt hash. Our tables never see them. |
| What is not tested? | RLS, camera, layout, two people tapping at the same second. See section 9. |
| What would you do next? | Like/X live updates with Supabase Realtime, push notifications, game rules as database functions, account deletion. |

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

<!-- New entries go below. Template:
**Step N: Title** (branch `x/name`, PR #N)
- What:
- Why:
- Files:
- How to check:
-->
