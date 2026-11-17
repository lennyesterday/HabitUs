# HabitUs

iOS app (SwiftUI, iOS 17+) for our Introduction to Programming group project. Full spec: [SPEC.md](SPEC.md). Rules for AI assistants: [AGENTS.md](AGENTS.md).

## Setup (once per Mac)

1. Clone: `git clone https://github.com/lennyesterday/HabitUs.git`
2. Open `HabitUs.xcodeproj` in Xcode.
3. Signing, so the app runs on your own iPhone:
   - Copy `Config/Local.example.xcconfig` to `Config/Local.xcconfig` (this file is ignored by Git).
   - Set `BUNDLE_ID_SUFFIX` to your name, e.g. `.vincent`.
   - Set `DEVELOPMENT_TEAM` to your team ID. Easiest way: in Xcode under Target → Signing & Capabilities pick your Apple ID as team, then run `git diff` and copy the `DEVELOPMENT_TEAM = XXXXXXXXXX` value into `Local.xcconfig`. Afterwards undo the project change with `git checkout HabitUs.xcodeproj`.
4. Pick an iPhone simulator next to the play button and press ▶.

## How we work

- `main` always builds. Nobody pushes to `main` directly.
- Per task: pull `main` → new branch (`a/login`) → code → commit → push → pull request → a teammate reviews and merges.
- New files go into the `HabitUs/` folder. Xcode picks them up by itself (synchronized folder), so the project file rarely changes.
