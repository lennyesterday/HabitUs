# Habit App (working title): Spec and Team Plan (Swift version)

Group project for Introduction to Programming (Nova SBE, course 2477). Team: Lenny, Vincent, Bene.
Deadline: **Mon 23 Nov 2026, 23:59** on Moodle (confirmed by the course wiki, the "Sunday" in the professor call was wrong). Presentation: **Tue 24 Nov, 12:42**.
Official rules and grading: [[Gruppenprojekt]] and [[Course Wiki Guides]], source: https://2477-introduction-programming.gitlab.io/wiki/team-project/

> [!info] Rewritten for Swift on 2026-11-17
> After the [[Professor Call 2026-11-17]]: native iPhone app in **Swift and SwiftUI**, backend is **Supabase** (login, database, photo storage). No own server. The game rules (section 3) are the same as before. The old Python and Streamlit version is in [[Habit App Spec (Python, old)]].
> **Status 17.11.:** no code yet. The timeline in section 8 starts tonight.

> [!warning] Biggest risk: the wiki requires a public URL
> The course wiki says: the app is **deployed at a public URL**, the README contains that URL, and the live demo runs **at the deployed URL**. **Slides and recorded videos are not accepted as a replacement.** A native iPhone app has no URL. The professor allowed Swift in the call, but did not talk about the URL.
> **Before writing code:** get a written OK through the helpdesk form (or Moodle message) that a live demo from our iPhones replaces the public URL, and ask what goes into the README instead. If the answer is no, we switch to Python + Streamlit + Supabase (see [[Habit App Spec (Python, old)]], storage moved to Supabase).

This file is the single source of truth for what we build, who builds it and how we get graded. If the code and this file disagree, we fix one of them on purpose and say which.

## 1. What the app is

Friends form a group around one habit, for example "gym three times a week". Everybody signs the group contract. Each round every member has to prove the habit with photos taken live inside the app. The group sees every photo in a shared chat and can reject it. Proven tasks give points, and a leaderboard shows who delivers.

**How you win:** highest points when the challenge ends. That is after the last round before the end date, or when the owner finishes an open end challenge.
**How you lose:** you cannot be kicked out, but the leaderboard shows every round who delivered and who did not.

### In scope

- Accounts with login, one owner and several participants per group
- Group contract with fixed rules, confirmed by every member
- Join by invite code, owner accepts or declines, session starts with at least 3 members
- Free choice of frequency: a number of times per day, per week or per month, up to once every day of the month. That gives the tasks per round (GYM 1, GYM 2, GYM 3)
- Live photo proof from the iPhone camera inside the app, posted into the group chat
- Like and X on every proof. Enough X make a proof invalid
- Pause with a reason for exceptions such as being sick
- Points, round bonus, streak bonus, leaderboard, countdown to the end of the round
- Group chat with text messages

### Deliberately out of scope

- No automatic fake detection (no GPS, no image analysis). The group checks, not an algorithm
- No uploads from the photo library
- No rule changes and no late joining once a session runs
- No public feed. Photos are visible to the group only
- **No push notifications for this deadline.** Real iPhone push needs a paid Apple Developer account, APNs and a server that sends them. See "Later" in section 7
- No App Store or TestFlight release. The app runs on our own iPhones, installed from Xcode

## 2. Tech stack and structure

- **App:** Swift 5.10+, SwiftUI, iOS 17, Xcode 16. Every team member needs a Mac with Xcode
- **Backend:** Supabase (free plan). Supabase Auth for email and password, Postgres for the data, Supabase Storage for the photos. Access rules are written as Row Level Security (RLS) policies in the database
- **Library:** `supabase-swift` through Swift Package Manager. That is the only external package
- **Tests:** XCTest. The rules live in a small local Swift package (`HabitCore`) that runs with `swift test` on the Mac in seconds, without simulator and without internet
- **Install on phones:** Xcode with a free Apple ID can install the app on your own iPhone (the build has to be renewed after 7 days, enough for us). The paid developer account is only needed for TestFlight, which we do not use

```
HabitApp.xcodeproj
HabitApp/
    HabitAppApp.swift       entry point: is someone logged in, which screen to show
    Views/                  one file per screen
        AuthView.swift      landing, sign up, log in
        HomeView.swift      my games, New Game, Join Game
        CreateGroupView.swift
        ContractView.swift  contract text and signature (used by create and join)
        JoinView.swift      enter invite code
        LobbyView.swift     members, requests, Start Session
        GroupView.swift     the main group screen (layout)
        Components/
            TaskCard.swift  tasks of the round, countdown, camera and pause buttons
            Podium.swift    top 3
            FeedView.swift  chat with photo and pause messages, like and X
            CameraView.swift  UIImagePickerController with the camera only
        LeaderboardView.swift
        ResultsView.swift   shown when the session has ended
        Theme.swift         colors, fonts, small helpers
    Services/               the only place that talks to Supabase
        SupabaseClient.swift  AuthService.swift  GroupService.swift
        CheckinService.swift  PhotoService.swift  ChatService.swift
    Config/
        Secrets.xcconfig    Supabase URL and anon key (never committed)
        Secrets.example.xcconfig
HabitCore/                  Swift package with the rules. No SwiftUI, no Supabase
    Sources/HabitCore/
        Models.swift  Rounds.swift  Tasks.swift  Votes.swift  Scoring.swift  Validation.swift  InviteCode.swift
    Tests/HabitCoreTests/
supabase/
    migrations/             every change to the data structure as a numbered SQL file (course rule)
        001_schema.sql      tables, RLS policies, storage policies, the join function
    seed.sql                demo group for the presentation
README.md  SPEC.md  DECISIONS.md  AGENTS.md
```

Three rules that hold the code together:

1. **Three layers.** A button in `Views/` calls a function in `Services/`, which talks to Supabase and uses `HabitCore` for every rule. Views never call Supabase directly. `HabitCore` never imports SwiftUI or Supabase. This is what makes the rules testable without a phone.
2. **Time is a parameter.** Every rule that depends on time takes `now: Date` as an argument. Views pass `Date()`, tests pass any time they want. That is how we test "round 3" without waiting three weeks.
3. **Points are computed, not stored.** A score is always calculated from the check-ins and reactions. There is no points column that could get out of sync. If a photo becomes invalid, the score is simply lower the next time it is computed.

And one rule for security: **access is checked in the database (RLS), not in the app.** Hiding a button is not security. Even a modified app with our public key cannot read another group's photos.

## 3. Rules

Each rule has an id. Tests name the rule they check, for example `testR17PhotoInvalidWhenMoreThanHalfX`.

### Accounts

- **R1** Sign up needs email, password (at least 8 characters), display name (2 to 20 characters), an avatar emoji and a ticked terms box. The terms say that proof photos are visible to the members of the group.
- **R2** Passwords are handled only by Supabase Auth, which stores a bcrypt hash. Our tables never contain a password. The login stays in the iPhone Keychain, so closing the app does not log you out.
- **R3** A failed login shows the same message for an unknown email and for a wrong password.

### Groups and contract

- **R4** Create a group: name, habit (short, for example "Gym"), frequency, end, free rules text. Frequency is two fields: **per what** (day, week, month) and **how often**. How often goes from 1 up to the most that the period allows: 1 to 10 per day, 1 to 7 per week, 1 to 28 per month. End is either **open end** or an **end date** picked from a calendar, with shortcuts for 4 weeks, 3 months and 6 months. The creator is the owner, signs the contract and gets an invite code (6 characters, no 0, O, 1 or I).
- **R5** Join: enter the code, read the contract, sign it. This creates a pending request. The code only works while the group is in the lobby.
- **R6** Only the owner can accept or decline a request. Declined is final.
- **R7** Only the owner can start the session, and only with at least 3 accepted members including the owner. Starting sets the start day to today, declines all open requests and disables the code.
- **R8** The contract cannot be changed after the start, the end date included. The owner can finish the challenge at any time with "Finish challenge" and a confirmation. For an open end challenge this is the only way it ends.

### Rounds and tasks

- **R9** A round is one period of the chosen frequency: 1, 7 or 28 calendar days in Europe/Lisbon time. A month counts as 28 days. Round 1 starts on the start day. With an end date, the last round is the last one that fits completely on or before that date, and the challenge ends when it ends. A started round is never cut short. With open end, rounds continue until the owner finishes. The session can only be started if at least one full round fits before the end date.
- **R10** In every round each member has as many tasks as the "how often" number, named after the habit: GYM 1, GYM 2, GYM 3. With more than 7 tasks the task card shows a progress bar and a number ("12 of 28") instead of one chip per task.
- **R11** Task k is done when the member has k counted check-ins in that round. A counted check-in is a valid photo or a valid pause.
- **R12** A photo check-in is allowed only if the session is active, the member is accepted and an open task is left. If the period is a week or longer, the member also must have no valid photo check-in today in this group, so 3 per week means three different days. If the period is a day, several check-ins on the same day are allowed, up to the target.
- **R13** The photo comes from the camera only (`UIImagePickerController` with source `.camera`, no library). The database sets the timestamp and the day. The app resizes the image to at most 800 px and saves it again as JPEG, which also removes the location data.
- **R14** The task card always shows the time left in the round, for example "3 days 2 h left". Under 24 hours it turns red.

### Like, X and pause

- **R15** Every accepted member except the author can give one reaction per check-in: like or X. It can be changed or removed while the round is running and the check-in is still valid.
- **R16** A like is support only. It never changes points.
- **R17** A photo becomes invalid as soon as **more than half of the other members** have pressed X. Invalid is final. It no longer counts, the day is free again and the member can take a new photo if the round still has time. This rule keeps players accountable: a photo has to really show the habit. A picture that has nothing to do with the task, or was taken somewhere else, can be thrown out by the group.
- **R18** Pause: next to an open task the member can press pause and must give a reason (up to 200 characters). The pause is posted into the chat and is accepted by default: the task counts as done with full points. If more than half of the other members press X, the pause is rejected. That task has failed for this round and cannot be redone. A pause needs a real reason, not just any excuse. If the group does not buy it, it can reject it.
- **R19** When a round ends, its check-ins are frozen. No more reactions.

How many X are needed (R17 and R18):

| Members in the group | Other members | X needed |
|---|---|---|
| 3 | 2 | 2 |
| 4 | 3 | 2 |
| 5 | 4 | 3 |
| 6 | 5 | 3 |

### Points and leaderboard

- **R20** 20 points per done task.
- **R21** Round bonus: **+25 %** on the points of a round in which all tasks are done. The bonus appears as soon as the last task is done.
- **R22** Streak bonus: another **+5 %** for every further complete round in a row, up to +25 %. So the 2nd complete round in a row gets +30 % in total, the 3rd +35 %, and from the 6th on it stays at +50 %. An incomplete round resets the streak.
- **R23** A missed task gives 0. There are no negative points.
- **R24** Leaderboard: total points, highest first. Tie: fewer pauses first, then display name.

The bonuses are percentages on purpose. A fixed bonus would be huge in a "1 per day" challenge and tiny in a "7 per week" one. With percentages the bonus is about 30 % of a perfect player's points for every frequency. Because a task is worth 20 and the steps are 5 %, all results are whole numbers.

Worked example, 3 per week, four rounds with 3, 3, 2 and 3 done tasks:

| Round | Tasks | Bonus | Points |
|---|---|---|---|
| 1 | 60 | +25 % | 75 |
| 2 | 60 | +30 % | 78 |
| 3 | 40 | none | 40 |
| 4 | 60 | +25 % | 75 |
| Total | | | **268** |

What the rules do to typical players, 3 per week over 12 rounds. These numbers are also tests:

| Player | Points | Share of the perfect score |
|---|---|---|
| Does everything | 1035 | 100 % |
| Misses one task in one round | 940 | 91 % |
| Does 2 of 3 every round | 480 | 46 % |

One slip costs little. Never fulfilling the contract costs a lot. That is intended: the bonus rewards keeping the contract, not being close.

### Chat and access

- **R25** The feed shows text messages, photo check-ins and pauses in time order, the newest at the bottom, the last 50 items. It refreshes when the screen opens, on pull to refresh and every 10 seconds while the group screen is open.
- **R26** A text message has 1 to 500 characters.
- **R27** Only accepted members can see or change anything in a group: feed, photos, leaderboard, members. A pending member sees only the contract and the status of the request. Enforced by RLS.
- **R28** Only the owner can accept, decline, start and end. Enforced by RLS.

## 4. Screens

| Screen | Shows | Actions |
|---|---|---|
| Landing | Three lines on what the app does | Log in, Sign up |
| Sign up / Log in | Fields from R1 | Submit |
| Home | New Game, Join Game, one card per game of mine | Open a card |
| Create group | Name, habit, how often, per what, open end or end date, rules text | Next |
| Contract | The rules as a contract, signature | Sign |
| Group created | Invite code, large | Copy or share (`ShareLink`), go to lobby |
| Join | Code field | Next, then Contract |
| Lobby | Accepted members, requests with signature, code | Owner: Accept, Decline, Start Session |
| Group | Header, task card, podium, feed | Check in, Pause, Like, X, send message, Leaderboard |
| Leaderboard | Rank, points, complete rounds, streak | Back |
| Results | Winner, final ranking | Back to Home |

Navigation: one `NavigationStack` from Home. Sign up and log in are shown instead of Home while nobody is logged in.

### Home

One Home for everyone. The role is visible on the card, there is no separate owner dashboard.

```
┌──────────────────────────────────────────┐
│  Hi Lenny 👋                             │
│  [ + New Game ]      [ Join Game ]       │
│                                          │
│  My games                                │
│  ┌────────────────────────────────────┐  │
│  │ 🏋️ Gym Crew              👑 Owner  │  │
│  │ Lobby · 2 of 3 · 1 open request    │  │
│  └────────────────────────────────────┘  │
│  ┌────────────────────────────────────┐  │
│  │ 📚 Reading with Bene               │  │
│  │ Active · Round 2 · 1/3 this round   │  │
│  └────────────────────────────────────┘  │
│  ┌────────────────────────────────────┐  │
│  │ 🏃 Running                         │  │
│  │ Waiting for the owner              │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

| My status in the game | Card shows | Tap opens |
|---|---|---|
| Owner, lobby | 👑, members x of 3, number of open requests | Lobby |
| Accepted, lobby | "Waiting for start", members x of 3 | Lobby, read only |
| Pending | "Waiting for the owner" | Contract, read only |
| Declined | "Declined" | Nothing |
| Active | Round 2, with an end date also "ends 14 Feb", my tasks 1/3, my points | Group |
| Ended | "Ended", my rank | Results |

### Group

One screen, chat first, like PlayUs. No tabs.

```
┌──────────────────────────────────────────┐
│ ‹ Home       🧑 🧑 🧑        Leaderboard  │
│            136 pts  ·  #2 🏆             │
│                                          │
│            ROUND 2 · DAY 4               │
│  ┌────────────────────────────────────┐  │
│  │ 🏋️ GYM 1 ✅   GYM 2 ✅   GYM 3 ⏳   │  │
│  │      ⏱ 3 days 2 h left             │  │
│  │   [ 📸 Do GYM 3 ]        [ ⏸ ]     │  │
│  │   Bene 3/3 · Vincent 1/3           │  │
│  └────────────────────────────────────┘  │
│       🥈 Bene    👑 Lenny   🥉 Vincent   │
│       120 pts    136 pts     95 pts      │
│  ── Chat ──────────────────────────────  │
│  Bene: 📷 GYM 2 · Tue 18:40              │
│        [photo]   👍 2   ✖ 0     valid    │
│  Vincent: let's go 🔥                    │
│  Lenny: ⏸ GYM 2: sick                    │
│        👍 1   ✖ 1               accepted │
│  [ Message...                         ]  │
└──────────────────────────────────────────┘
```

SwiftUI pieces we expect to use: `NavigationStack`, `ScrollViewReader` (feed scrolls to the newest), `.sheet` for the camera and the pause reason, `.refreshable` (pull to refresh), `.task` with a 10 second loop (feed refresh), `TimelineView` (countdown), `AsyncImage` or a small loader for the photos.

## 5. Data model

Six tables in Supabase Postgres. Timestamps are `timestamptz`, set by the database. `day` and `started_on` are dates in Lisbon time.

```sql
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
```

Photos go into a **private** storage bucket `proofs`, path `<group_id>/<random uuid>.jpg`. The app loads them with the logged-in session. There are no public links.

**Access rules (RLS)**, all in `supabase/migrations/001_schema.sql`. Two helper functions, `is_accepted(group_id)` and `is_owner(group_id)`, keep the policies short.

| Table | Read | Write |
|---|---|---|
| profiles | any logged-in user (only name and avatar are in there) | only your own row |
| groups | owner, or anyone with a membership (pending sees the contract) | insert: you become owner. Update (start, finish): owner only |
| memberships | accepted members of the group, and your own row | insert only through `join_by_code` or by the owner for themself. Update (accept, decline): owner only |
| checkins | accepted members | insert: you, as an accepted member, while the session is active |
| reactions | accepted members | your own reaction, not on your own check-in |
| messages | accepted members | insert: you, as an accepted member |
| storage `proofs` | accepted members of the group in the folder name | upload: accepted members into their group folder |

`join_by_code(code, signature)` is the one database function. A joiner is not a member yet, so RLS would not let them find the group. The function looks up the code, checks that the group is still in the lobby and creates the pending request. Nothing else.

What is **not** in the database, because `HabitCore` calculates it:

| Thing | Calculated from |
|---|---|
| Phase of a group (lobby, active, ended) | `started_on`, `ended_early_at`, `end_on`, `period_days` and now |
| Round of a check-in | its `day`, `started_on` and `period_days` |
| Current round and countdown | `started_on`, `period_days` and now |
| Valid or invalid | number of X against the number of other members (R17, R18) |
| Tasks of a member (done, open, failed) | that member's check-ins of the round and `target` |
| Points, streak, rank | all check-ins and reactions of the group |

Open tasks of a member in a round = target, minus valid check-ins, minus rejected pauses.

## 6. Function contracts

These signatures are the agreement between the three areas. We create them as empty stubs tonight, so everyone can call everyone else's functions before they are finished. Changing a signature needs a message to the team.

**HabitCore** (pure functions, no internet, fully tested). Input is plain structs from `Models.swift`: `Group`, `Member`, `Checkin`, `Reaction`.

| File | Function | Area |
|---|---|---|
| `Rounds.swift` | `phase(of group: Group, now: Date) -> Phase` (`.lobby`, `.active`, `.ended`) | C |
| | `currentRound(of group: Group, now: Date) -> Int` | C |
| | `round(of day: Date, in group: Group) -> Int` | C |
| | `timeLeft(in group: Group, now: Date) -> TimeInterval` | C |
| | `canStart(_ group: Group, today: Date) -> Bool` (at least one full round fits) | C |
| | `localDay(_ now: Date) -> Date` (Europe/Lisbon) | C |
| `Votes.swift` | `xThresholdReached(xCount: Int, otherMembers: Int) -> Bool` | B |
| | `isValid(_ checkin: Checkin, reactions: [Reaction], memberCount: Int) -> Bool` | B |
| `Tasks.swift` | `taskStatus(user:group:checkins:reactions:memberCount:now:) -> TaskStatus` (target, done, failed, open, canCheckInToday) | B |
| `Scoring.swift` | `scoreRounds(donePerRound: [Int], target: Int) -> [Int]` | C |
| | `leaderboard(group:members:checkins:reactions:now:) -> [LeaderboardRow]` | C |
| `Validation.swift` | `validateSignUp(...)`, `validateGroup(...)`, `validateMessage(_:)`, `validatePauseReason(_:)`. Throw `RuleError` with a text the view can show | A |
| `InviteCode.swift` | `generate() -> String` (uses `SystemRandomNumberGenerator`) | A |

**Services** (talk to Supabase, use HabitCore for every rule, throw `RuleError` or the Supabase error). All `async throws`.

| File | Function | Area |
|---|---|---|
| `AuthService` | `signUp(email:password:displayName:avatar:)`, `logIn(email:password:)`, `logOut()`, `currentUser` | A |
| `GroupService` | `createGroup(...) -> Group`, `requestToJoin(code:signature:)`, `decide(membershipId:accept:)`, `start(groupId:)`, `finish(groupId:)` | A |
| | `myGames() -> [GameCard]`, `members(groupId:) -> [Member]` | A |
| `CheckinService` | `addPhoto(groupId:image:caption:)`, `addPause(groupId:reason:)`, `setReaction(checkinId:kind:)` with kind `.like`, `.x` or `nil` | B |
| | `feed(groupId:limit:) -> [FeedItem]` | B |
| `PhotoService` | `upload(_ image: UIImage, groupId:) -> String` (resize, JPEG, upload, returns path), `load(path:) -> UIImage` | B |
| `ChatService` | `post(groupId:text:)` | B |

## 7. What we build first

**Must have.** Without these there is no demo.

1. Sign up, log in, log out (R1 to R3)
2. Create group, contract with typed signature, invite code (R4)
3. Join by code, accept and decline, start with 3 (R5 to R7)
3b. Finish challenge by the owner (R8)
4. Home with cards
5. Group screen: task card with countdown, camera check-in, feed (R9 to R14, R25)
6. Like and X with the more than half rule (R15 to R17, R19)
7. Pause with reason (R18)
8. Points, bonus, streak, leaderboard (R20 to R24)
9. Text chat (R26)
10. RLS policies for every table and the bucket (R27, R28)
11. HabitCore tests and the app running on all three iPhones

**Should have**, in this order, only when every must have works on the phones: live chat with Supabase Realtime instead of the 10 second refresh, results screen, look and feel polish, drawn signature with PencilKit, HabitCore tests running on GitHub Actions for every push.

**Later**, not for this deadline: push notifications (paid Apple Developer account, APNs, a Supabase Edge Function that sends them), TestFlight, photo calendar, leaving a group, late joining, badges, points chart, reminders, password reset, account deletion.

### Four things to try tonight before we rely on them

| Spike | Why | Fallback | Area |
|---|---|---|---|
| Every one of us builds the empty app from Xcode onto their own iPhone with a free Apple ID | Signing problems must never be a last day problem. Everyone needs it to test and to commit | Run in the simulator, test the camera on one phone only | all |
| Supabase project, `schema.sql` applied, one row written and read from the app | Proves the key, the package and RLS work together | Ask the teaching team, look at the course guide | C |
| Take a photo with `UIImagePickerController`, resize, upload to the private bucket, load it again | Camera only works on a real phone, the simulator has none | Demo the check-in on one phone, the others watch the chat | B |
| Mirror an iPhone to a Mac with QuickTime (cable) and show it on a projector | The presentation is a live demo. Videos are not accepted as a replacement | A second iPhone, mirrored the same way | C |

## 8. Timeline

Deadline Mon 23, 23:59 (wiki). Thu 19 is also the internal deadline for the Advanced Strategy presentation, so Lenny keeps that day light.

| Day | Goal |
|---|---|
| Tue 17 evening | **Send the public URL question to the teaching team (helpdesk form).** Swift is decided (all three have a Mac and an iPhone). Repo, Xcode project, HabitCore package, all stubs from section 6 on `main`. Supabase project. The four spikes |
| Wed 18 | Schema and RLS done. Sign up, log in, create group, join, accept, start. HabitCore: rounds and scoring with tests |
| Thu 19 | **Milestone 1:** happy path on the phones with three accounts. Sign up, create, join, accept, start, photo, it shows in the feed, the score changes. Ugly is fine |
| Fri 20 | **Milestone 2:** X rule, pause, countdown, leaderboard, chat. **Feature freeze in the evening.** After that only fixes, tests and polish |
| Sat 21 | Tests complete. Security checklist (section 11) checked line by line. Teach-back call (section 10). README, seed data, demo accounts |
| Sun 22 | Buffer. Full demo rehearsal on the phones with the Supabase project, then reset the data to the seed |
| Mon 23 | Nothing new, stop merging. README checked on a fresh clone. **Submit before 18:00**, not at 23:59. Renew the 7 day builds on the phones. Open the Supabase dashboard (free projects pause after a week without use) |
| Tue 24 | Presentation 12:42 |

## 9. Who does what

Each area owns its files. You do not edit files of another area without asking. That keeps merge conflicts rare, which matters even more with Xcode project files, and makes it clear who explains what.

| | Area A: Accounts and Groups | Area B: Check-ins and Feed | Area C: Scoring, Time and Operations |
|---|---|---|---|
| Owner | Vincent or Bene | Vincent or Bene | Lenny (suggestion) |
| HabitCore | `Validation.swift`, `InviteCode.swift` | `Votes.swift`, `Tasks.swift` | `Models.swift`, `Rounds.swift`, `Scoring.swift` |
| Services | `AuthService`, `GroupService` | `CheckinService`, `PhotoService`, `ChatService` | `SupabaseClient` |
| Views | `AuthView`, `HomeView`, `CreateGroupView`, `ContractView`, `JoinView`, `LobbyView`, `Theme` | `GroupView`, `FeedView`, `CameraView`, pause sheet | `TaskCard`, `Podium`, `LeaderboardView`, `ResultsView` |
| Database | RLS for profiles, groups, memberships, `join_by_code` | RLS for checkins, reactions, messages, storage bucket | `schema.sql` tables, `seed.sql` |
| Other | Look and feel | Camera spike | Xcode project setup, Supabase project, README, demo setup |
| Rules | R1 to R8, R27, R28 | R12, R13, R15 to R19, R25, R26 | R9 to R11, R14, R20 to R24 |
| Tests | `ValidationTests`, `InviteCodeTests`, RLS manual check | `VotesTests`, `TasksTests` | `RoundsTests`, `ScoringTests` |
| Explains in the walkthrough | Security: login, RLS, who may see what | The proof: camera, X rule, fake photos | Data, time, tests, Supabase |

What each area delivers per milestone:

| | A | B | C |
|---|---|---|---|
| Tue 17 | App on own phone | App on own phone, camera spike | Repo, Xcode project, HabitCore package, stubs, Supabase project |
| Wed 18 | Sign up to Start Session | Photo upload works | Schema, round and score functions with tests |
| Milestone 1 (Thu) | Lobby complete | Photo check-in appears in the feed | Task card with round numbers, score from check-ins |
| Milestone 2 (Fri) | RLS for A tables, Home cards complete | X rule, pause, chat, RLS for B tables | Countdown, leaderboard, podium |
| Sat 21 | All A tests green, RLS check done | All B tests green | All C tests green, README, seed data |

## 10. How we work

**Git**

- `main` always builds and runs. Nobody pushes to `main` directly.
- One branch per piece of work, named `a/login`, `b/x-rule`, `c/leaderboard`.
- Pull request with three sentences: what it does, why, how to check it by hand. Another member reviews and merges.
- Merge only when `swift test` in `HabitCore/` is green and the app builds.
- Everyone commits from their own account on their own Mac.
- **Xcode project file:** only Lenny adds or removes files in the Xcode project during the first day. After that, whoever adds a new file pulls `main` first and pushes the change quickly. `.pbxproj` conflicts are the most common pain in Swift teams.
- `.gitignore` for Xcode (`DerivedData/`, `xcuserdata/`, `Secrets.xcconfig`) before the first commit.

**Understanding our own code.** The discussion is graded, and "the AI did that" scores zero.

- We do not have to explain every line. We have to know roughly what each part does and why we decided it that way. Before merging, the author can say in two or three sentences what the change does and where it sits (view, service, HabitCore or database).
- The reviewer of a pull request must be able to say in their own words what it does. If not, the author explains it in a call.
- `DECISIONS.md`: one line per decision. What, why, which alternative we rejected, who can explain it. Section 13 is the start of that list.
- **Teach-back on Sat 21:** each of us walks through one feature of **another** area, from the button in `Views/` to the function in `Services/` to the rule in `HabitCore` to the table and policy in `schema.sql`.

**Working with AI assistants.** Put these lines into `AGENTS.md`:

- Read `SPEC.md` first. Build only what the current task names. Do not build other features or fix other things you notice.
- Keep the layers: no Supabase calls in `Views/`, no SwiftUI or Supabase in `HabitCore`.
- Every rule from section 3 goes into `HabitCore` with a test. Tests first. Never weaken, skip or delete a test to get green.
- Never put the service role key into the app or the repo. Only the anon key, and only in `Secrets.xcconfig`.
- The database is the team's Supabase project. Inspect it with the Supabase MCP tools, read only by default. Do not change or delete tables or rows unless the task says so. Save every change to the data structure as a SQL file in `supabase/migrations/`. Tests never use the Supabase project.
- Every new table gets RLS turned on and a policy in `schema.sql` in the same change.
- Small changes. Show the diff and explain it in plain words. We are beginners and need to understand roughly what each part does.
- Stay inside the files of the area you are working in.

**Done means:** the rule from section 3 works on the phone, its test is green, the table has its RLS policy, a teammate has reviewed it, it is merged to `main`.

## 11. Grading: how we score on each criterion

Official weights and what "High (100 %)" means, from the course wiki. Low = 30 %, Mid = 70 %, High = 100 % of the criterion.

| Criterion | High means | What we do for it |
|---|---|---|
| 1. It works (20 %) | The deployed app runs all workflows without errors, **including invalid input** | Happy path by Thursday, feature freeze Friday. Every form shows a clear error for wrong input (HabitCore `Validation`). Rehearsed on the phones |
| 2. UI and UX (20 %) | Workflows are direct, results and errors are clearly shown | One chat-first group screen, task card with countdown, every error as a readable message, no dead ends |
| 3. Scope and ambition (20 %) | Substantial features well beyond a solo project, implemented consistently | Native iOS app, accounts and two roles, live camera proof, group voting, time-based rounds, streak scoring, cloud backend with access rules in the database |
| 4. Verification (10 %) | Tests cover **accepted and rejected actions and edge cases**, all pass on `main` | Every rule in HabitCore has a test that names it, rejected cases included. RLS checked by hand. We can say what is not tested and why |
| 5. Security (10 %) | Access control and input validation enforced. Dependencies **minimal, pinned, no known vulnerabilities** | RLS on every table and the bucket, `check` constraints plus HabitCore validation, only one package (`supabase-swift`) pinned in `Package.resolved` |
| 6. Repository walkthrough (20 %) | Members explain **how** it is built, **why**, **what its limits are** and **how it could change** | Area owners, review rule, `DECISIONS.md`, teach-back, known limits list, "what would you do next" answer |

The teaching staff also reviews the repository **on its own, without us**. So the README and the folder structure have to explain themselves: screens in `Views/`, rules in `HabitCore/`, storage in `supabase/` and `Services/`, tests in `HabitCore/Tests/`.

Hand-in requirements from the teaching team:

- [ ] Idea approved by the teaching team
- [ ] **Written OK from the teaching team:** native iPhone app demoed live from our phones instead of a public URL, and what goes into the README instead of the URL (see the warning at the top)
- [ ] Repo public, final code on `main`
- [ ] Every member has commits under their own account
- [ ] `README.md` with names and student numbers, how to build (open in Xcode, copy `Secrets.example.xcconfig`, run on a phone), how to set up Supabase (`schema.sql`), how to run the tests (`cd HabitCore && swift test`). Followed once on a fresh clone to check it works
- [ ] One person submitted the repo link on Moodle (if the field is closed, the professor opens it)
- [ ] Only what is committed by Mon 23, 23:59 counts. Later fixes do not, security fixes included

### Security checklist

Check every line on Sat 21. Each line has an owner who can explain it.

| # | Measure | Why | Area |
|---|---|---|---|
| S1 | Passwords only through Supabase Auth (bcrypt). Never in our tables, never logged | A stolen database must not reveal passwords | A |
| S2 | Same error for unknown email and wrong password | Nobody can find out who has an account | A |
| S3 | Session stored in the Keychain by the Supabase package. Every screen except landing needs a logged-in user | No screen without login | A |
| S4 | RLS turned on for **every** table, with the policies from section 5 | The anon key is inside the app and can be extracted. Without RLS anyone with the key could read everything | A, B |
| S5 | Manual RLS check with two test accounts in two groups: user 2 cannot read group 1's feed, photos or members, cannot react or check in there. A participant cannot accept or start. Screenshots in `docs/` | Evidence for S4 | A |
| S6 | The service role key is never in the app or the repo | That key ignores RLS | C |
| S7 | Length limits in the database (`check` constraints) and in HabitCore. SwiftUI `Text` shows user text as plain text | A message cannot break the layout or run anything | B |
| S8 | Photos only from the camera, resized and saved again as JPEG (no location data), random file name, private bucket, readable only by members | No metadata leaks, no guessing of file names, no public links | B |
| S9 | Invite code from `SystemRandomNumberGenerator`. A code only creates a request, the owner still has to accept. Dead after the start | A leaked or guessed code does not let anyone in | A |
| S10 | `.gitignore` has `Secrets.xcconfig`, `xcuserdata/`, `DerivedData/` before the first commit. The repo is public | No keys on GitHub | C |
| S11 | `seed.sql` uses demo accounts created by hand with random passwords. No password in the repo | Public repo | C |
| S12 | Only one package (`supabase-swift`), version pinned through `Package.resolved` and committed. Check its GitHub page for known security issues before hand-in | "Minimal, pinned, without known vulnerabilities" is the High criterion | C |
| S13 | Nothing secret on the projector: close the Supabase dashboard, Xcode with `Secrets.xcconfig` and the agent before the demo | Keys shown on screen are leaked keys | all |

Known limits. We name them ourselves in the walkthrough instead of waiting to be caught:

- **Game rules run in the app, access rules run in the database.** RLS guarantees that only members can see and post. Rules like "one photo per day" or "X locked after invalid" are checked in HabitCore before the app writes. A modified app could break a game rule inside its own group, but never get into another group. A real product would move these checks into database functions
- No limit on login attempts beyond Supabase's defaults, no email verification, no password reset
- A photo of a screen can fake a "live" photo. That is exactly why the group can press X
- No push notifications, so you only see news when you open the app
- No account deletion yet. Photos show people, so for a real launch this and EU hosting (Supabase region) would come first

## 12. Tests

`cd HabitCore && swift test`. HabitCore has no internet and no database, so tests build plain arrays of check-ins and reactions and pass in any `now`. They run in seconds.

| File | Checks | Area |
|---|---|---|
| `ValidationTests` | R1, R4, R26 and the pause length. 28 per month and 7 per week are accepted, 8 per week and 29 per month are refused | A |
| `InviteCodeTests` | 6 characters, never 0, O, 1 or I | A |
| `VotesTests` | R15 to R18. The table in section 3 row by row. The author's own X does not count | B |
| `TasksTests` | R11, R12, R19. With a weekly period a second photo on the same day is refused, with a daily period and target 2 it works and the third is refused. Allowed again after the first became invalid. Rejected pause blocks the task. No check-in when the session has ended | B |
| `RoundsTests` | R9, R14 for all three periods. Weekly: day 7 is round 1, day 8 is round 2. Daily: every day is a new round. End date: 3 per week with an end date 24 days after the start has 3 rounds and ends after day 21. Open end: still active after a year, ended once the owner finishes. Start refused if no full round fits. Lisbon time around midnight and the summer time change | C |
| `ScoringTests` | R20 to R24. The worked example gives 75, 78, 40, 75. The three player types give 1035, 940 and 480. Total bonus stops at +50 %. For 1 per day, 3 per week and 7 per week the bonus share of a perfect player is between 25 % and 35 %. An invalid photo lowers the score | C |

Not tested automatically, and why:

- RLS and the database. Testing policies automatically needs a local Supabase with Docker, too much for five days. Instead: the manual check S5 with screenshots
- Camera, signature and layout. They are Apple's UI parts, not our rules. Instead: a manual checklist with a screenshot of every screen before hand-in
- The Supabase services. They are thin. The rules they use are tested in HabitCore
- Two people tapping in the same second. Too rare for groups of this size

## 13. Decisions

Open, to settle together tonight:

- **DECIDED 17.11.** Swift and Supabase (this spec). All three of us have a Mac and an iPhone.
- **DECIDED** Deadline Mon 23.11., 23:59 (course wiki)
- **OPEN, blocks everything** Public URL rule. Written OK for a native iPhone demo, or back to Python + Streamlit + Supabase
- **CONFIRM** X and pause rejection count against the **other** members, so the author has no vote. In a group of 3 that means both others must press X.
- **CONFIRM** A rejected pause cannot be made up with a photo. A rejected photo can be retaken.
- **CONFIRM** At most 10 per day. Per week and per month the limit is one per day anyway, so 7 and 28.
- **CONFIRM** A round is one period (day, week, month) starting on the day the owner presses Start. A month is 28 days.
- **CONFIRM** There is no limit on the number of pauses. The group controls it with X.
- **CONFIRM** Email and password login instead of Sign in with Apple.

Made, with the reason (copy into `DECISIONS.md`):

| Decision | Why | Rejected alternative |
|---|---|---|
| Native iPhone app in SwiftUI | The idea lives on the phone: camera, always with you. The professor allowed it | Python and Streamlit web app |
| Supabase instead of our own server | Login, database and photo storage without writing or hosting a backend. Recommended by the professor | Own server with an API, or a Google Sheet |
| Access rules as RLS in the database | The key is inside the app, so the database must protect itself. One place to check | Checks only in the app |
| Game rules in a separate Swift package | Testable in seconds without phone or internet. Clear for the walkthrough | Rules inside the views |
| Points are computed from check-ins, not stored | Cannot get out of sync. An invalid photo needs no correction logic | A points column |
| Valid or invalid is computed from the X count | Same reason. No trigger or job needed | A status column updated by the app |
| Rounds are computed from the start day | No background job. Nothing to "close" at midnight | A job that closes rounds |
| Time is a parameter (`now`) | Rules about days, weeks and months become testable in milliseconds | Calling `Date()` inside the rules |
| No push notifications for now | Native push needs the paid developer account and a sender. Not worth it in five days | APNs with an Edge Function |
| Install from Xcode, no TestFlight | Free, enough for three phones and a demo | Paid account and TestFlight |
| The group judges photos, no image analysis | Friends know better than an algorithm whether that is the right gym. Far less to build | GPS or AI checks |
| Owner has no extra vote on photos | The owner also plays | Owner decides alone |
| Contract frozen after the start | The signature only means something if the rules cannot move | Changes with a new signature |
| One Home for all roles | A user can be owner in one game and participant in another | Separate owner dashboard |
| No negative points | People who fall behind should keep playing | Minus points for missed tasks |
| Bonuses are percentages, not fixed points | Keeps the bonus in proportion for every frequency. Checked with a simulation that is now a test | Fixed bonus per round |

## 14. Presentation

Our slot is 5 minutes, so the demo is one story of about two minutes. One iPhone is mirrored to the projector with QuickTime. The demo must run live, slides and videos do not count as a replacement.

1. Home on the projector with a running game from the seed data, round 2
2. One of us takes a live photo with a second phone. It appears in the chat on the projector
3. The other two press X on their phones. The photo turns invalid and the points drop
4. Leaderboard

Checklist from the course guide "Preparing the demo":

- [ ] The week before: whole demo run on the phones with the real Supabase project, starting data from `seed.sql`, one demo account per role, invalid input tried on purpose, tests green on `main`, README checked
- [ ] Demo account passwords where the whole team can find them (password manager or private chat, never the repo)
- [ ] The day before: one full rehearsal, Supabase dashboard opened (not paused), data reset to the seed, **stop merging**
- [ ] On the day: phones charged, apps open and logged in, a second iPhone ready, only the app on screen
- [ ] Any of us can run the demo, not only one person
- [ ] If something fails: say what happened and carry on

Questions we expect in the walkthrough, with the person who answers first:

| Question | Short answer | Area |
|---|---|---|
| Where is the data and why there | Supabase: Postgres for the data, a private bucket for the photos. No server of our own to run | C |
| Your key is in the app. Is that safe? | It is the public anon key. Every table and the bucket has RLS, so the key alone shows nothing. The service role key is never in the app | A |
| Can I see another group's photos | No. RLS checks membership in the database. Show the manual test | A |
| What do the tests not cover | RLS automatically, camera, layout, simultaneous taps. See section 12 | C |
| How do you stop fake photos | Camera only, database timestamp, and the group can reject with X. We chose not to build detection | B |
| Can a hacked app cheat? | Inside its own group, on game rules: yes, we name it as a known limit. Into another group: no | B |
| How are passwords stored | Supabase Auth with bcrypt. Our tables never see them | A |
| Why are points not stored | See decisions | C |
| What happens if Supabase is down | Nothing can load or be saved. The app shows a clear error message instead of crashing, and the action can be tried again. Tested by turning on flight mode | B |
| What would you do next | Push notifications, game rules as database functions, account deletion, TestFlight | anyone |
