# HabitUs: what has been built so far

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

### Built (the app builds, the 68 rule tests are green)

Tried in the simulator against our Supabase project: onboarding, sign up, log in, Home, the GIF search.
**Not yet tried end to end with three real accounts:** create → join → accept → start → check in →
leave / delete, profile and group pictures. Do this together once before the feature freeze.


| Area | What you can do |
|---|---|
| Start | Onboarding pages (shown whenever nobody is logged in), sign up, log in, log out |
| Home | One card per game: picture or emoji, member pictures, status, my points and rank |
| Create | Name, habit, emoji icon (all emojis, with search), how often, end date or open end, own rules |
| Contract | Read the rules, sign with the finger, get a 6 character invite code |
| Join | Enter code, read the contract first, sign, wait for the owner |
| Lobby | Owner accepts or declines requests, starts the session with at least 3 members |
| Group screen | Task card with countdown, camera check-in (test photo in the simulator), bonus card, podium, rankings, chat with text and GIFs, refresh every 10 s |
| Leaderboard | Line chart of points per round, all players with full rounds, streak, pauses |
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
                   Tested with `cd HabitCore && swift test` (68 tests, about 0.01 s).

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
| `Scoring.swift` | `scoreRounds`, `roundBonusPercent`, `leaderboard` | R20 to R24 | 15 |
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
| Onboarding pages and new design | – | explain the app, make it fun | – |
| Email confirmation off | no email verification | Supabase's built-in mailer only reaches team addresses | fake emails possible, but they see nothing without invite code + owner OK |

---

## 9. Known limits (say them yourselves in the walkthrough)

- Game rules run in the app, access rules in the database. A hacked app could break a game rule *inside its own group* (e.g. two photos a day), but never get into another group.
- No email verification, no password reset, no account deletion.
- A photo of a screen can fake a "live" photo. That is exactly why the group can press X.
- No push notifications, no live updates (the group screen reloads every 10 seconds).
- Not tested automatically: RLS and the database functions, camera, layout. RLS is checked by hand (S5).
- GIPHY sees search terms and IP addresses.

---

## 10. Getting started on your Mac (15 minutes)

1. `git clone https://github.com/lennyesterday/HabitUs.git` and open `HabitUs.xcodeproj`.
2. Copy `Config/Local.example.xcconfig` → `Config/Local.xcconfig`, set your team and a suffix (README).
3. Copy `Config/Secrets.example.xcconfig` → `Config/Secrets.xcconfig`, ask Lenny for the three values.
4. `cd HabitCore && swift test` → 68 tests green.
5. Run in the simulator, sign up with your own email, join Lenny's test game with the code.
6. Read in this order: `HabitCore/Sources/HabitCore/Scoring.swift` → `Tasks.swift` → `Services/CheckinService.swift` → `Views/GroupView.swift` → `supabase/migrations/001_schema.sql`.

Work rules (`AGENTS.md`): a branch per task (`b/x-rule`), pull request, someone else reviews, tests stay green, commit from your own account.

---

## 11. Proposed split for the rest

| Who | Task | Area | Files |
|---|---|---|---|
| Bene | Like and X buttons on photos and pauses (R15, R16, R17, R19) | B | `CheckinService.setReaction`, `Components/FeedView.swift` |
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
