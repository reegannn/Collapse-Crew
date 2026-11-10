# HANDOFF: Collapse Crew (working title)

A co-op puzzle-escape game for Roblox. 2-4 players escape a collapsing location by solving teamwork puzzles before a hazard (rising water, lava, etc.) reaches them.

This document hands development to **Claude Code working inside a GitHub repo**. It is a **temporary** arrangement. Once the Roblox Studio + Claude MCP integration is set up, development moves to Studio-connected work (see Milestone M12). Everything here is built so that move is clean.

---

## 0. Read this first

1. **Do NOT run, execute, build, install, lint, format or test anything locally.** See section 2. Your work is writing files and reviewing them by reading.
2. Read `docs/STATUS.md` (if it exists) at the start of every session, and update it at the end.
3. Work **one milestone at a time**, in order, unless the owner says otherwise.
4. Every milestone ends with a **Self-Review Gate** (section 9). Do not start the next milestone until the gate is complete.
5. The owner is new to game development. Explain decisions in plain language in `docs/DECISIONS.md` and in commit/PR descriptions. Avoid unexplained jargon.
6. If the repo already has content, inspect it first and adapt this plan to it. If it is empty, begin with M0.

---

## 1. Project summary

**Genre:** co-op puzzle-escape (hybrid with light progression/idle-style meta).
**Players:** 2-4 per team (solo allowed with scaled puzzles, see M6).
**Core loop:** Lobby -> form team -> enter a collapsing location -> solve room puzzles together while a hazard advances -> escape -> earn coins/XP -> spend on cosmetics and camp upgrades -> come back tomorrow for the Daily Expedition.

### Why this concept (market reasoning)
- Escape-style games are trending, but most are solo run-and-collect. Co-op puzzle-escape is an underserved combination (puzzle and survival genres were reported as low-competition).
- Roblox's discovery system leans on retention and return rate, and co-play is a recognised signal. Roblox's own docs list play-through rate, first-play bounce rate (a negative signal) and playtime per user among key signals: https://create.roblox.com/docs/discovery
- Therefore: a **very strong first 2-3 minutes** (no bounce), **reasons to return within 24-48h** (daily expedition, streak, camp), and **mechanics that make players invite friends** (forced teamwork).

### Design pillars
1. **Teamwork is mandatory, not optional.** Every room needs 2+ players to do different things at once.
2. **Instantly readable.** A new player understands the goal in under 10 seconds.
3. **Short, repeatable runs.** 4-8 minutes per expedition; always "one more go".
4. **Visible progress.** Streaks, camp growth, cosmetics.
5. **Mobile-first.** Most Roblox players are on phones: big buttons, simple controls, no precision-required inputs.
6. **Server-authoritative.** The client never decides outcomes.

---

## 2. Hard rules for Claude Code (read carefully)

### Forbidden (no exceptions)
- Running the game, Roblox Studio, Rojo, Wally, Selene, StyLua, luau-analyze, test runners, build scripts, package managers (`npm`, `pip`, `aftman`, `rokit`, etc.) or any installer.
- Executing any script or project code, in any language, to "check that it works".
- Downloading tools, binaries, or dependencies.
- Any command whose purpose is to verify behaviour by executing code.

If you are unsure whether something counts, **do not run it**. Write the question into `docs/STATUS.md` under "Questions for owner".

### Allowed
- Creating, editing and deleting files in the repo.
- Reading and searching files (read/grep/glob tools).
- Standard git operations (branch, add, commit, push) following section 8.
- Using a **read-only** review subagent for self-review (section 9), provided it only reads files.

### Because nothing can be tested here
- Mark anything that depends on real Roblox behaviour with `-- TODO(verify-in-studio): <what to check>`. These are collected into `docs/STUDIO_VERIFY.md` (maintained by you) and become the first work list for M12.
- **Do not invent Roblox APIs.** Use only APIs you are confident exist and are current. If unsure, use the simplest well-known alternative and add a `TODO(verify-in-studio)`.
- Prefer boring, well-documented patterns over clever ones.
- No secrets, API keys or Open Cloud credentials in the repo. Ever.

---

## 3. Technical approach

### Toolchain (files only; never executed here)
- **Rojo-compatible layout** (`default.project.json`) so the repo syncs into Studio later. Write the config; do not run Rojo.
- **Luau with `--!strict`** at the top of every module where practical.
- Config files for later use: `stylua.toml`, `selene.toml`, `wally.toml` (empty dependencies at first). Write them; do not run them.
- **No third-party runtime libraries in v1.** Write small in-house utilities (Signal, Maid, Remotes). This keeps the repo self-contained and avoids unverifiable installs. Evaluate libraries later in M12 when Studio access exists.
- **UI is built in code** (Instance builders), not in Studio, since no Studio is available during this phase. Keep UI modules small and data-driven so they can be restyled in Studio later.
- **Maps are data + generator modules** (procedural parts from definitions), so layouts are reproducible from the repo. Art polish happens in Studio later.

### Architecture
- **Server-authoritative services** (`ServerScriptService`), **client controllers** (`StarterPlayerScripts`), **shared modules** (`ReplicatedStorage`).
- Services/controllers expose `Init()` then `Start()`. A single bootstrap script per side requires and starts them in a defined order.
- All client->server communication goes through a single `Remotes` module with **schema validation and rate limiting** on the server.
- State machines for rounds (explicit states, explicit transitions).
- All tunable numbers live in `Config/` modules (never magic numbers inline).
- Use `task.wait`, `task.spawn`, `task.defer`, `task.delay`. Never `wait()`, `spawn()`, `delay()`.
- Use `CollectionService` tags for puzzle/hazard objects instead of hard-coded paths.
- Every connection and instance created at runtime is cleaned up via a `Maid`.

### Suggested repo layout
```
.
├── default.project.json
├── README.md
├── handoff.md                      (this file)
├── stylua.toml  selene.toml  wally.toml  .gitignore
├── docs/
│   ├── STATUS.md                   (living status log)
│   ├── DECISIONS.md                (short decision records)
│   ├── ARCHITECTURE.md
│   ├── ROADMAP.md                  (copy of sections 5-6, kept current)
│   ├── STUDIO_VERIFY.md            (all TODO(verify-in-studio) items)
│   ├── LEVEL_DESIGN.md             (locations, rooms, puzzles)
│   └── reviews/                    (one review file per milestone)
└── src/
    ├── server/                     -> ServerScriptService
    │   ├── Bootstrap.server.luau
    │   └── Services/
    ├── client/                     -> StarterPlayerScripts
    │   ├── Bootstrap.client.luau
    │   └── Controllers/
    └── shared/                     -> ReplicatedStorage
        ├── Config/
        ├── Types/
        ├── Util/                   (Signal, Maid, Logger, etc.)
        ├── Remotes/
        └── Content/                (location, room, puzzle, cosmetic definitions)
```

---

## 4. Platform and policy guardrails

- **Server owns truth:** coins, XP, inventory, round outcomes, puzzle state, timers.
- **Remote hygiene:** validate argument count, types and ranges; rate-limit; ignore unexpected calls silently (log in a debug-only logger).
- **DataStore:** use `UpdateAsync`, `pcall` with retries/backoff, schema version field, save on `PlayerRemoving` and `game:BindToClose`. Respect request budgets (batch saves, no per-second writes).
- **Purchases:** implement `MarketplaceService.ProcessReceipt` idempotently (record receipt IDs); grant only after data is saved/confirmed.
- **Random paid items:** avoid paid randomised rewards (loot-box style) unless odds are disclosed and the item is policy-compliant. Default: no paid randomness. (`TODO(verify-in-studio)`: owner to confirm current Roblox policy before M7 monetization goes live.)
- **Player-visible text:** anything user-generated must go through Roblox's filtering APIs (e.g. `TextService`), and chat should use Roblox's built-in chat.
- **Younger audience:** keep content mild (cartoon hazards, no gore), no external links, no off-platform prompts.
- **Do not copy** other games' names, assets, characters or distinctive mechanics wholesale. The "Brainrot" meme aesthetic is deliberately NOT used.

---

## 5. Milestones

Legend: each milestone lists **Goal**, **Features**, **Deliverables**, **Acceptance criteria** (verifiable by reading, since nothing is executed) and **Depends on**.

### Milestone overview

| ID | Name | Main outcome |
|----|------|--------------|
| M0 | Repo foundation | Layout, configs, docs, conventions |
| M1 | Core framework | Bootstrap, utilities, remotes, config, logging |
| M2 | Player data and economy | Saving, coins, XP, leaderstats |
| M3 | Lobby and teams | Lobby, party formation, team arenas |
| M4 | Round loop | State machine, timer, win/lose, respawn rules |
| M5 | Hazard system | Rising water/lava + hazard interface |
| M6 | Puzzles and Location 1 | Puzzle framework, 4 puzzle types, 3-room Location 1 |
| M7 | Rewards, shop and monetization | Rewards, cosmetics shop, game pass, dev products |
| M8 | Retention layer | Daily Expedition, streaks, daily reward, camp |
| M9 | UI/UX and onboarding | HUD, party UI, tutorial, mobile controls |
| M10 | Analytics and tuning | Event tracking, funnels, feature flags, balance |
| M11 | Safety and anti-exploit | Hardening, moderation, rate limits, audit |
| M12 | Studio transition | Move to Studio + MCP; verify everything; art pass |
| M13 | Launch readiness | Location 2, store page, release checklist, soft launch |

---

### M0: Repo foundation
**Goal:** a clean, Rojo-compatible skeleton and working agreements.
**Features**
- [ ] `default.project.json` mapping `src/server`, `src/client`, `src/shared`
- [ ] Config files (`stylua.toml`, `selene.toml`, `wally.toml`, `.gitignore`), written only
- [ ] `README.md` (what it is, folder map, "no local execution during the handoff phase")
- [ ] `docs/` skeleton: STATUS, DECISIONS, ARCHITECTURE, ROADMAP, STUDIO_VERIFY, LEVEL_DESIGN, `reviews/`
- [ ] PR template and commit convention doc

**Acceptance:** all files exist; project file maps all three source folders; STATUS.md lists the milestone plan; no executable steps were run.
**Depends on:** nothing.

### M1: Core framework
**Goal:** the plumbing every other milestone relies on.
**Features**
- [ ] Server and client **Bootstrap** with ordered `Init()` / `Start()`
- [ ] Utilities: `Signal`, `Maid`, `Logger` (levels, debug toggle), `Promise-lite` or plain `pcall` helpers, `Table` helpers, `Time` helpers (UTC date keys)
- [ ] **Remotes module**: declarative remote definitions, server-side schema validation, per-player rate limiting
- [ ] **Config** modules: game, round, economy, hazard, UI constants
- [ ] **Types** module (strict type exports): PlayerData, TeamState, RoundState, PuzzleDefinition, HazardDefinition, etc.
- [ ] Feature-flag stub (`Flags` module, read from Config for now)

**Acceptance:** no module has circular requires; every remote has a schema; every module has a header comment describing its contract; no use of `wait()`/`spawn()`.
**Depends on:** M0.

### M2: Player data and economy
**Goal:** safe saving and the basic currency loop.
**Features**
- [ ] `DataService`: load on join, session-lock-style protection, retries with backoff, save on leave/BindToClose, autosave interval, schema versioning and migration function
- [ ] Profile schema: coins, XP/level, streak data, owned cosmetics, equipped cosmetics, camp upgrades, purchase receipts, settings, first-join timestamp
- [ ] `EconomyService`: server-only `AddCoins`/`SpendCoins` with validation and transaction logging
- [ ] **leaderstats** (Coins) driven by profile data (supersedes the earlier standalone leaderstats script)
- [ ] Data-failure behaviour: if load fails, player plays in "safe mode" (no saving, clear message), never overwrites existing data

**Acceptance:** no path writes to the DataStore without a successful prior load; all coin changes go through `EconomyService`; migration function exists even if v1 is the only version.
**Depends on:** M1.

### M3: Lobby and teams
**Goal:** get players from the lobby into a team run.
**Features**
- [ ] Lobby area definition and spawn logic
- [ ] **Party/team formation**: auto-fill queue plus "invite friend" flow (Roblox friend join), team size 1-4
- [ ] Ready-up system and launch countdown
- [ ] **Team arenas**: each team gets an instanced arena cloned/generated at a spatial offset on the same server (v1 approach). Arena pool with allocate/release and cleanup
- [ ] Late-join and disconnect handling (drop-out, backfill rules)
- [ ] Design note in `docs/DECISIONS.md` for later scaling to reserved servers (`TeleportService`) (M13/Roadmap R5)

**Acceptance:** arena allocate/release is symmetric (no leaked instances); a team of 1-4 is handled by explicit code paths; all queue state lives on the server.
**Depends on:** M1, M2.

### M4: Round loop
**Goal:** a complete, finishable run with no puzzles yet (placeholder objective).
**Features**
- [ ] **Round state machine**: Lobby -> Briefing -> Running -> Success | Failure -> Results -> Return to lobby
- [ ] Timer and progress tracking, replicated to clients
- [ ] Checkpoints and respawn rules (respawn at room checkpoint; revival by teammates is a stretch idea logged in the roadmap)
- [ ] Win condition (all living team members reach the exit) and lose condition (hazard catches too many players or time expires)
- [ ] Results payload (time, rooms cleared, coins/XP earned)
- [ ] Cleanup between rounds

**Acceptance:** every state has an entry and exit function; all transitions are in one table; no round resource survives past `Results`.
**Depends on:** M3.

### M5: Hazard system
**Goal:** the pressure that drives every run.
**Features**
- [ ] **Hazard interface**: `Start`, `Update(dt)`, `GetProgress`, `Stop`, `Reset`, plus config-defined speed curves
- [ ] First hazard: **Rising Water** (server-side moving volume with elimination check)
- [ ] Second hazard: **Rising Lava** (same interface, different visuals/damage rules)
- [ ] Hazard speed scaling by team size and difficulty
- [ ] Safe-zone rules and "hazard slows while a room is being solved" tuning hook (config-driven)
- [ ] Client hooks for VFX/audio (events only; visuals added in M9/M12)

**Acceptance:** adding a third hazard requires only a new module + config entry, no changes to the round loop; elimination logic is server-only.
**Depends on:** M4.

### M6: Puzzle framework and Location 1
**Goal:** the signature gameplay.
**Features**
- [ ] **Puzzle interface**: `Setup(room, definition)`, `OnPlayerAction`, `IsSolved`, `Reset`, `Destroy`, with a `Solved` signal
- [ ] Puzzle types (v1):
  1. **Hold-the-door**: one player stands on a pressure plate to hold a door open for others
  2. **Power routing**: players rotate/connect nodes in sequence; distributed so one player cannot solve alone
  3. **Timed switches**: switches in different places must be activated within a window
  4. **Carry-and-place**: pick up an object and deliver it to a socket (carrying slows movement)
- [ ] **Solo/duo scaling**: for fewer players, plates/switches use "helper" mechanics (e.g. weighted object substitutes for a second player) so every team size can finish
- [ ] **Room definitions** as data (`Content/Locations/...`): rooms, puzzle assignments, checkpoint positions, difficulty rating
- [ ] **Location generator**: builds the rooms from definitions (simple part-based geometry with tags)
- [ ] **Location 1: "Sinking Cargo Ship"** (working name), 3 rooms, escalating
- [ ] Solvability checks written as static assertions in a `LocationValidator` module (e.g. every room requires at most N players; every definition references valid puzzle types)

**Acceptance:** each puzzle is data-driven and has a documented reset path; all puzzle state is server-side; `LEVEL_DESIGN.md` documents every room with a solve walkthrough.
**Depends on:** M4, M5.

### M7: Rewards, shop and monetization
**Goal:** a healthy, fair economy and the first revenue hooks.
**Features**
- [ ] Reward calculation (base + speed bonus + teamwork bonus + first-clear bonus), config-driven
- [ ] XP/level system with unlock gates
- [ ] **Cosmetic shop** (trails, hats, camp decor, death-splash effects): purchase with coins, ownership checks, equip/unequip
- [ ] **Game pass hooks:** 2x Coins pass (apply in `EconomyService`, never client-side)
- [ ] **Developer products:** coin packs via idempotent `ProcessReceipt`
- [ ] Pricing table in config; economy balance notes in `docs/DECISIONS.md`
- [ ] No paid randomness in v1 (see section 4)

**Acceptance:** every grant path is idempotent and server-side; receipts are recorded; ownership is checked on the server before any equip.
**Depends on:** M2, M4.

### M8: Retention layer
**Goal:** give players reasons to return within 24-48 hours.
**Features**
- [ ] **Daily Expedition**: a date-seeded (UTC) rotating combination of location, hazard and modifier; bonus rewards for the first clear of the day
- [ ] **Streak counter** with a forgiving rule (one missed day pauses rather than resets, config-driven)
- [ ] **Daily reward** (claimable once per UTC day)
- [ ] **Team Camp**: lobby-side camp that visibly grows with the player's progress and purchases (v1: per-player camp upgrades, displayed in the lobby for the party)
- [ ] Milestone rewards (e.g. 3-day, 7-day streaks)
- [ ] Time helpers tested by reasoning about edge cases (UTC midnight rollover, leap/DST not applicable since UTC)

**Acceptance:** all date logic uses UTC and a single `Time` module; claim endpoints are idempotent; nothing relies on client clocks.
**Depends on:** M2, M6, M7.

### M9: UI/UX and onboarding
**Goal:** a clear, mobile-friendly interface and a first-minute experience that prevents early bounce.
**Features**
- [ ] HUD: hazard progress bar, timer, objective text, teammate status
- [ ] Lobby UI: party panel, ready button, Daily Expedition card, streak display
- [ ] Results screen (time, rewards, "play again" with the same team)
- [ ] Shop and inventory UI
- [ ] **Tutorial/first-run flow**: guided Room 0 that teaches the core "hold the door" idea in under 90 seconds, skippable for returning players
- [ ] Touch-first layout, large tap targets, safe-area handling; keyboard/gamepad parity
- [ ] Accessibility basics: colour-blind-safe cues (shape + colour), optional reduced-motion setting, readable font sizes
- [ ] Audio and VFX hook points (placeholders)

**Acceptance:** all UI is built from small modules driven by data; no UI module makes gameplay decisions; tutorial progress is stored in the profile.
**Depends on:** M4, M6, M7, M8.

### M10: Analytics and tuning
**Goal:** know where players quit and balance with data.
**Features**
- [ ] `AnalyticsService` wrapper (event names and payloads defined in one place) using Roblox's built-in analytics/custom events where available (`TODO(verify-in-studio)`)
- [ ] Funnel events: join, tutorial start/complete, first room cleared, first run completed, second run started, shop open, purchase, daily claim
- [ ] Per-puzzle fail/time events to find frustrating rooms
- [ ] Feature flags and remote-config-style tunables in `Config`
- [ ] `docs/ANALYTICS.md` listing every event and what question it answers

**Acceptance:** event names are constants; no PII; analytics calls can never throw into gameplay (wrapped in `pcall`).
**Depends on:** M4-M9.

### M11: Safety and anti-exploit
**Goal:** harden before real players arrive.
**Features**
- [ ] Remote audit: every remote reviewed for validation, rate limit, and permission
- [ ] Server-side sanity checks: movement/teleport plausibility around puzzle interactions, interaction distance checks, cooldowns
- [ ] Duplicate-reward and race-condition review (leave-while-saving, double-claim)
- [ ] Moderation/filtering review for any player-visible text
- [ ] Failure-mode review: DataStore outage, empty teams, mid-round disconnects
- [ ] `docs/SECURITY.md` with threat list and mitigations

**Acceptance:** every remote appears in the audit table; every reward path has an idempotency argument written down.
**Depends on:** M2-M10.

### M12: Studio transition (the planned handover)
**Goal:** move development from this repo-only phase into Studio-connected work with the Roblox Claude MCP/integration.
**Features**
- [ ] Owner sets up Studio, Rojo (or the chosen sync), and the MCP integration
- [ ] Sync the repo into a Studio place; resolve first-run errors
- [ ] **Work through `docs/STUDIO_VERIFY.md`** top to bottom; record results
- [ ] Execute the full first playtest: tutorial, one full run per team size (1-4), disconnect cases
- [ ] Replace placeholder geometry with real art/lighting (owner-led, Claude assists)
- [ ] Add VFX/audio, tune hazard speed and puzzle difficulty
- [ ] Decide library adoption (e.g. data/session-lock libraries) now that testing is possible
- [ ] Update `docs/ARCHITECTURE.md`: which workflows are Studio-first vs repo-first from now on

**Acceptance:** all `TODO(verify-in-studio)` items are resolved or converted into issues; first successful end-to-end run recorded in `STATUS.md`.
**Depends on:** M0-M11 (may be **pulled forward** at any time the MCP is ready; if so, treat the Studio-connected workflow as primary and keep the repo as source of truth).

### M13: Launch readiness
**Goal:** ship a polished first version.
**Features**
- [ ] **Location 2** (new theme and hazard combination) to prove the content pipeline
- [ ] Store page: title, description, tags, thumbnails/icon shot list, trailer idea list
- [ ] Release checklist: settings, age/content questionnaire, game passes/products created, DataStore names, publishing flow
- [ ] **Soft launch plan**: small friend test, then limited public test, with metrics thresholds to proceed (D1 return rate, first-play bounce, tutorial completion)
- [ ] Update cadence plan (weekly small update, monthly new location)
- [ ] Community plan (Roblox group, update log, bug-report channel)

**Acceptance:** release checklist fully ticked; thresholds for go/no-go written down.
**Depends on:** M12.

---

## 6. Post-launch roadmap (not yet in scope, keep architecture ready)

| ID | Feature | Notes |
|----|---------|-------|
| R1 | **Ranked speedrun leaderboards** | Per-location, per-team-size; uses ordered DataStores/leaderboard service |
| R2 | **Seasonal events** | Limited-time locations, cosmetics, modifiers |
| R3 | **New location packs** | Monthly cadence using the generator + validator |
| R4 | **Revive and role system** | Medic/engineer-style roles; teammate revives |
| R5 | **Reserved-server runs** | Move team runs to `TeleportService` reserved servers for scale and private runs |
| R6 | **Social features** | Friends-only parties, emotes, ping system, shareable run replays |
| R7 | **Player-built rooms (UGC-lite)** | Long-term; needs moderation pipeline first |
| R8 | **Subscriptions/VIP** | Only after retention is proven |
| R9 | **Localization** | String tables from day one make this cheap |
| R10 | **Controller/console polish** | Gamepad UX review |

---

## 7. Feature-to-milestone allocation index

Every big feature has exactly one home:

| Feature | Milestone |
|---------|-----------|
| Repo layout, docs, conventions | M0 |
| Bootstrap, Signal/Maid/Logger, Remotes, Config, Types, feature flags | M1 |
| Data saving, schema/migration, coins, XP data, leaderstats | M2 |
| Lobby, party/queue, ready-up, team arenas, disconnect handling | M3 |
| Round state machine, timer, checkpoints, win/lose, results payload | M4 |
| Hazard interface, Rising Water, Rising Lava, scaling | M5 |
| Puzzle interface, 4 puzzle types, solo/duo scaling, Location 1, validator | M6 |
| Rewards, XP/levels, cosmetic shop, game pass, dev products | M7 |
| Daily Expedition, streaks, daily reward, camp | M8 |
| HUD, lobby/shop/results UI, tutorial, mobile layout, accessibility | M9 |
| Analytics, funnels, tuning flags | M10 |
| Anti-exploit, audits, moderation checks, failure modes | M11 |
| Studio/MCP move, verification, art/VFX/audio pass, library decisions | M12 |
| Location 2, store page, release checklist, soft launch | M13 |
| Leaderboards, events, packs, roles, reserved servers, social, UGC, VIP, localization, controller | R1-R10 |

If you find a feature not on this list, add it to the right milestone in `docs/ROADMAP.md` and note it in `docs/DECISIONS.md` before building it.

---

## 8. Working agreements

- **Branches:** one per milestone, e.g. `m1-core-framework`. Do not commit to `main` directly unless the owner says so.
- **Commits:** small and descriptive, e.g. `m2: add DataService load/save skeleton`.
- **PR description:** what changed, why, which acceptance criteria are met, open `TODO(verify-in-studio)` items, and the link to the milestone review file.
- **Definition of done (per milestone):** all features implemented or explicitly deferred (with reason) -> acceptance criteria checked by reading -> Self-Review Gate complete -> `STATUS.md` and `STUDIO_VERIFY.md` updated.
- **Scope control:** do not add features outside the milestone. Log ideas in `docs/ROADMAP.md` instead.
- **Docs travel with code:** any change to architecture or behaviour updates the relevant doc in the same commit.
- **Session protocol:** start by reading `STATUS.md`; end by writing what was done, what is next, blockers, and questions for the owner.

---

## 9. Self-Review Gate (mandatory at the end of every milestone)

This is **static review by reading only**. Do not run anything to perform it.

1. **Re-read every file changed in the milestone**, top to bottom, as if reviewing someone else's pull request. Use a read-only review subagent if available, instructed to only read files and report findings.
2. **Walk the checklist** below. Record each item as Pass / Fail / N/A with a note.
3. **Fix** every Fail, then re-read the fixed code. Repeat until clean.
4. **Write** `docs/reviews/M<N>-review.md` using the template at the end of this section.
5. **Only then** mark the milestone done in `STATUS.md`.

### Checklist
**Correctness**
- [ ] Every `require` path resolves to a file that exists; no circular requires
- [ ] Every function referenced exists with matching arguments and return types
- [ ] All code paths return/handle values (no accidental `nil` returns)
- [ ] Edge cases: 0/1/4 players, player leaves mid-action, empty tables, missing config keys

**Roblox-specific**
- [ ] Server/client boundaries respected (no server-only APIs on client and vice versa)
- [ ] No deprecated globals (`wait`, `spawn`, `delay`); `task` library used
- [ ] Players existing before `PlayerAdded` connects are handled
- [ ] Yielding calls (`DataStore`, `MarketplaceService`, `WaitForChild`) are protected (`pcall`/timeouts) and never block critical loops
- [ ] Anything dependent on engine behaviour has `TODO(verify-in-studio)` and is logged in `STUDIO_VERIFY.md`

**Security and fairness**
- [ ] Every remote validates arguments and is rate-limited
- [ ] Client never decides rewards, timers, puzzle results or ownership
- [ ] Reward/purchase paths are idempotent

**Resource safety**
- [ ] Every connection, instance and task created at runtime is cleaned up (Maid or equivalent)
- [ ] No per-frame work that could be event-driven; no unbounded tables

**Maintainability**
- [ ] `--!strict` where practical; types exported from `Types`
- [ ] No magic numbers (moved to Config)
- [ ] Module header comment states purpose and public API
- [ ] Names are consistent; dead code removed

**Docs**
- [ ] Acceptance criteria for the milestone are each addressed
- [ ] `ARCHITECTURE.md`, `DECISIONS.md`, `LEVEL_DESIGN.md` (if relevant) are up to date

### Review file template (`docs/reviews/M<N>-review.md`)
```
# M<N> Self-Review
Date: <date>   Reviewer: Claude Code (static read-only review)

## Scope
Files reviewed: <list>

## Checklist results
<table of checklist items with Pass/Fail/N/A and notes>

## Findings
| # | Severity (High/Med/Low) | File:line | Issue | Resolution |
|---|-------------------------|-----------|-------|------------|

## Unverified assumptions (-> STUDIO_VERIFY.md)
- <item>

## Verdict
<Ready / Ready with caveats / Not ready> and why
```

---

## 10. Coding standards (quick reference)

- File naming: `PascalCase.luau` for modules, `Name.server.luau` / `Name.client.luau` for scripts.
- One responsibility per module; services never reach into each other's internals, only public methods/signals.
- Functions short and named for what they do; early returns over deep nesting.
- Comments explain *why*, not *what*.
- Errors: use `pcall` at I/O boundaries (DataStore, Marketplace, Teleport); log with `Logger`; never swallow silently.
- Data shapes defined once in `Types`.
- Constants in `Config`, content in `Content`; code reads data, it does not hard-code it.

---

## 11. Assumptions and open questions for the owner

Assumed (change if wrong):
- Working title **Collapse Crew**; theme is bright, cartoon and mild.
- Team size 1-4; Location 1 is a sinking cargo ship; first hazards are water and lava.
- English only at launch; strings kept in a table for later localization.
- Game passes/dev products will be created by the owner in the Creator Dashboard (IDs go in `Config`).

Questions to resolve (record answers in `docs/DECISIONS.md`):
1. Final game name and visual style direction?
2. Is the owner comfortable with the economy being coin-based only at launch (no paid randomness)?
3. Which Roblox account/group will own the experience?
4. When is the Studio + MCP setup expected? (Determines whether M12 is pulled forward.)

---

## 12. First actions

1. Inspect the repo. If empty, start **M0**.
2. Create `docs/STATUS.md` with the milestone table from section 5 (all "Not started" except M0 "In progress").
3. Complete M0, run the Self-Review Gate, then continue to M1.
4. Do not run or test anything. When in doubt, write it down and ask.
