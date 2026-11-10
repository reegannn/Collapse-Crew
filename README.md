# Collapse Crew (working title)

A co-op puzzle-escape game for Roblox. Teams of 2-4 players (solo is allowed) escape a
collapsing location by solving teamwork puzzles before a hazard such as rising water or
lava reaches them.

**Core loop:** lobby -> form a team -> enter a collapsing location -> solve room puzzles
together while the hazard advances -> escape -> earn coins and XP -> spend on cosmetics
and camp upgrades -> come back tomorrow for the Daily Expedition.

## Where things stand

- **Current progress:** see [`docs/STATUS.md`](docs/STATUS.md). It is updated at the end of
  every work session and is the first thing to read.
- **The full plan:** [`handoff.md`](handoff.md) is the original brief.
  [`docs/ROADMAP.md`](docs/ROADMAP.md) is the living copy of the milestone list.
- **Why things were built the way they were:** [`docs/DECISIONS.md`](docs/DECISIONS.md),
  written in plain language.

## Important: nothing is run during the handoff phase

This repo is currently developed **by writing and reading files only**. Until the Roblox
Studio connection is set up (milestone M12):

- Do **not** run the game, Roblox Studio, Rojo, Wally, Selene, StyLua, tests, build
  scripts or installers against this repo as part of development work.
- The tool config files (`default.project.json`, `stylua.toml`, `selene.toml`,
  `wally.toml`) are **written but have never been executed**.
- Anything that depends on how Roblox really behaves is marked in the code with
  `-- TODO(verify-in-studio): ...` and collected in
  [`docs/STUDIO_VERIFY.md`](docs/STUDIO_VERIFY.md). That list is the first job once
  Studio access exists.

In short: treat the code as carefully reviewed but **untested** until M12.

## Folder map

```
.
├── default.project.json     Tells Rojo how the folders below map into a Roblox place
├── handoff.md               The original project brief
├── stylua.toml              Formatter settings (not run yet)
├── selene.toml              Linter settings (not run yet)
├── wally.toml               Package manager settings (no dependencies in v1)
├── .github/                 Pull request template
├── docs/
│   ├── STATUS.md            Living status log: done, next, blockers, questions
│   ├── DECISIONS.md         Short records of decisions and the reasons for them
│   ├── ARCHITECTURE.md      How the code is organised
│   ├── ROADMAP.md           Milestones and their feature checklists
│   ├── STUDIO_VERIFY.md     Everything that must be checked in Roblox Studio
│   ├── LEVEL_DESIGN.md      Locations, rooms and puzzles
│   ├── CONVENTIONS.md       Commit, branch, pull request and coding conventions
│   └── reviews/             One self-review report per milestone
└── src/
    ├── server/              Runs only on Roblox's servers  -> ServerScriptService.Server
    ├── client/              Runs on each player's device   -> StarterPlayerScripts.Client
    └── shared/              Visible to both                -> ReplicatedStorage.Shared
```

### What "server", "client" and "shared" mean

- **Server** code runs on Roblox's computers. Players cannot see or change it, so it owns
  everything that matters: coins, XP, timers, puzzle results, who won.
- **Client** code runs on each player's phone, tablet, console or PC. It shows the screen,
  plays sounds and sends button presses to the server. It is never trusted with outcomes.
- **Shared** code is used by both sides: settings, data shapes and small helper tools.

## How this becomes a playable game later (M12)

When Studio access is ready, [Rojo](https://rojo.space) reads `default.project.json` and
copies the `src/` folders into a Roblox place. The steps for that are deliberately not
part of the current phase; they are planned in `docs/ROADMAP.md` under M12.
