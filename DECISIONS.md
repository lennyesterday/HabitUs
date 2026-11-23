# Decisions

The most important choices we made, what we did not choose, and why. Rule numbers (R1 to R31) are from [SPEC.md](SPEC.md). Details of every change: [docs/HANDOVER.md](docs/HANDOVER.md).

## Platform and architecture

| Decision | Why | Not chosen |
|---|---|---|
| Native iPhone app in Swift and SwiftUI | The idea lives on the phone: live camera for proofs, always with you. The professor allowed Swift in the call on 17 Nov | Python and Streamlit web app (our first spec) |
| No public URL, live demo on our phones | A native app has no URL. We show it on real iPhones and explain the setup in the README | TestFlight or App Store (paid Apple account, review takes days) |
| Supabase as backend (login, Postgres database, photo storage) | No own server to write, host and secure. Recommended by the professor | Own server with an API, Firebase, a Google Sheet |
| Three layers: Views → Services → HabitCore | Views never talk to the database. All game rules are plain Swift in `HabitCore`, so they run as tests in seconds without phone or internet | Rules spread over the screens |
| Points are computed, never stored | One source of truth (the check-ins and votes). A late 👎 or a late joiner changes the points automatically | A points column that can get out of sync |
| Access rules in the database (RLS) | Even a modified app cannot read or change another group | Checks only in the app |
| Only one package: `supabase-swift`, pinned | Fewer things that can break or have security holes | Extra libraries for images, charts or networking |

## Security and privacy

| Decision | Why |
|---|---|
| Only the public anon key in the app, never the service role key | The anon key can only do what RLS allows. The service role key would skip all rules |
| The public anon key, the project URL and the GIPHY key are committed (`Config/Public.xcconfig`) | The teaching team can clone and press ▶ without any setup. These keys are public by design (they ship inside every app anyway). Trade-off: anyone with the repo can create accounts on our server or use our GIPHY quota; after the course we can rotate both keys. Secret keys (service role, email service) are never in the repo |
| Proof photos only from the live camera, in a private bucket | A photo from the library would make cheating too easy; only group members can load them |
| Email confirmation with a 6 digit code, password reset by code, password rules (8+, capital, small letter, number, special character) | Real accounts, no fake emails. Codes are easier on a phone than links |
| Our own email domain `habitractapp.com` through Resend | Supabase's built-in mailer only reaches team members and has a tiny limit |
| "Same error for unknown email and wrong password", reset never says whether an account exists | Nobody can find out who uses the app (R3) |
| System notes ("X left the group") are written only by the database | No app can fake them |
| Delete your own account (R31) through a database function | The app must never hold the key that deletes logins |

## Game rules we changed or added during the project

| Decision | Why | Trade-off we accept |
|---|---|---|
| Name: HabitUs → **Habitract** (habit + contract) | "HabitUs" was taken. The contract is the core idea | Project and folders keep the old name, so no checkout breaks |
| Contract signed by hand with the finger | Feels like a real commitment | Stored as a small picture (max 40 KB) |
| 👎 instead of X, photo invalid when **more than half of the others** press it (R17) | The group itself keeps everyone honest | A small group needs few votes |
| Rejected photo: red card at the top, retake until the round ends | People did not notice the rejection in the chat | After the round the task is missed |
| Pause with a reason (R18), the others have **48 hours** to reject it | Being sick should not ruin a streak, but excuses can be voted down even after the round ended | Checked in the app (HabitCore), not in the database |
| Leave any time; the chat says so | Contracts are a fun element, nobody should be trapped | Fewer members also means fewer 👎 needed |
| **On hold** below 3 players instead of ending (R30) | With 2 players voting does not work. Ending would punish the ones who stayed | Rounds keep counting while on hold, for everyone the same |
| **Join a running challenge** (R29): start next round, get the **group average** for the rounds before | Friends can join later without being hopeless last | The average is a gift: someone could join late on purpose. Fine among friends, not with money |
| GIFs in the chat (GIPHY) | Fun | Search terms and IP go to GIPHY |
| Home sorted by newest activity, like WhatsApp | The group where something happens is on top | |

## What we would do next

- **Push notifications** ("Bene posted a photo", "your round ends in 24 h"). Needs the paid Apple Developer Program (APNs) and a server function. Local reminders would work without it.
- **Money stakes, our business model.** The current app is a pilot; the goal is that friends play for real money and Habitract earns a small fee per pot. Our model: a stake **per round**, not per challenge. Whoever completes the round gets their stake back and shares the stakes of those who did not. Late joiners simply pay from their first round, so no catch-up is needed. Step 1 would only show who owes whom ("Vincent owes Lenny 5 €") and leave the payment to PayPal or MB Way; real payments (Stripe Connect) need legal advice and are strictly reviewed by Apple. With money, the 👎 votes would need an appeal or a referee.
- **Game rules in the database** (for example the 48 hours), so a modified app cannot bend them inside its own group.
- **Live updates** instead of reloading every 10 seconds.
