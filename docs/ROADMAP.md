# Roadmap

The living copy of the milestone plan from [`handoff.md`](../handoff.md) (sections 5-7).
`handoff.md` is the original brief and is not edited; **this file is kept current**.
Tick boxes here as features land. Progress per session is logged in
[`STATUS.md`](STATUS.md).

Legend: `[x]` done (written and statically reviewed, **not** run), `[ ]` not done,
`[~]` deliberately deferred (reason given next to it).

## Milestone overview

| ID | Name | Main outcome | Status |
|----|------|--------------|--------|
| M0 | Repo foundation | Layout, configs, docs, conventions | Done |
| M1 | Core framework | Bootstrap, utilities, remotes, config, logging | Done |
| M2 | Player data and economy | Saving, coins, XP, leaderstats | Not started |
| M3 | Lobby and teams | Lobby, party formation, team arenas | Not started |
| M4 | Round loop | State machine, timer, win/lose, respawn rules | Not started |
| M5 | Hazard system | Rising water/lava + hazard interface | Not started |
| M6 | Puzzles and Location 1 | Puzzle framework, 4 puzzle types, 3-room Location 1 | Not started |
| M7 | Rewards, shop and monetization | Rewards, cosmetics shop, game pass, dev products | Not started |
| M8 | Retention layer | Daily Expedition, streaks, daily reward, camp | Not started |
| M9 | UI/UX and onboarding | HUD, party UI, tutorial, mobile controls | Not started |
| M10 | Analytics and tuning | Event tracking, funnels, feature flags, balance | Not started |
| M11 | Safety and anti-exploit | Hardening, moderation, rate limits, audit | Not started |
| M12 | Studio transition | Move to Studio + MCP; verify everything; art pass | Not started |
| M13 | Launch readiness | Location 2, store page, release checklist, soft launch | Not started |

Each milestone ends with the Self-Review Gate (see [`CONVENTIONS.md`](CONVENTIONS.md)).
Review reports live in [`reviews/`](reviews/).

---

## M0: Repo foundation

**Goal:** a clean, Rojo-compatible skeleton and working agreements.

- [x] `default.project.json` mapping `src/server`, `src/client`, `src/shared`
- [x] Config files (`stylua.toml`, `selene.toml`, `wally.toml`, `.gitignore`), written only
- [x] `README.md` (what it is, folder map, "no local execution during the handoff phase")
- [x] `docs/` skeleton: STATUS, DECISIONS, ARCHITECTURE, ROADMAP, STUDIO_VERIFY, LEVEL_DESIGN, `reviews/`
- [x] PR template and commit convention doc

**Acceptance:** all files exist; project file maps all three source folders; STATUS.md
lists the milestone plan; no executable steps were run.
**Depends on:** nothing.

## M1: Core framework

**Goal:** the plumbing every other milestone relies on.

- [x] Server and client **Bootstrap** with ordered `Init()` / `Start()` (shared start-up routine in `Util/Lifecycle`)
- [x] Utilities: `Signal`, `Maid`, `Logger` (levels, debug toggle), plain `pcall` helpers (`Safe`; chosen over Promise-lite, see DECISIONS D-010), `TableUtil`, `Time` (UTC day numbers and date keys), plus `PlayerUtil`
- [x] **Remotes module**: declarative remote definitions, server-side schema validation, per-player rate limiting
- [x] **Config** modules: game, round, economy, hazard, UI constants (M1 holds the framework's own values; each later milestone adds its tunables)
- [x] **Types** module (strict type exports): PlayerData, TeamState, RoundState, PuzzleDefinition, HazardDefinition, etc. (team/round/puzzle shapes are drafts, finalised in M3/M4/M6)
- [x] Feature-flag stub (`Flags` module, read from `Config/FlagConfig` for now)
- [x] _Added:_ `PlayerSessionService` + `SessionController` "client ready" handshake (DECISIONS D-009), the first real remote and the worked example of the Service/Controller pattern

**Acceptance:** no module has circular requires; every remote has a schema; every module
has a header comment describing its contract; no use of `wait()`/`spawn()`.
**Depends on:** M0.

## M2: Player data and economy

**Goal:** safe saving and the basic currency loop.

- [ ] `DataService`: load on join, session-lock-style protection, retries with backoff, save on leave/BindToClose, autosave interval, schema versioning and migration function
- [ ] Profile schema: coins, XP/level, streak data, owned cosmetics, equipped cosmetics, camp upgrades, purchase receipts, settings, first-join timestamp
- [ ] `EconomyService`: server-only `AddCoins`/`SpendCoins` with validation and transaction logging
- [ ] **leaderstats** (Coins) driven by profile data (supersedes the earlier standalone leaderstats script)
- [ ] Data-failure behaviour: if load fails, player plays in "safe mode" (no saving, clear message), never overwrites existing data

**Acceptance:** no path writes to the DataStore without a successful prior load; all coin
changes go through `EconomyService`; migration function exists even if v1 is the only
version.
**Depends on:** M1.

## M3: Lobby and teams

**Goal:** get players from the lobby into a team run.

- [ ] Lobby area definition and spawn logic
- [ ] **Party/team formation**: auto-fill queue plus "invite friend" flow (Roblox friend join), team size 1-4
- [ ] Ready-up system and launch countdown
- [ ] **Team arenas**: each team gets an instanced arena cloned/generated at a spatial offset on the same server (v1 approach). Arena pool with allocate/release and cleanup
- [ ] Late-join and disconnect handling (drop-out, backfill rules)
- [ ] Design note in `docs/DECISIONS.md` for later scaling to reserved servers (`TeleportService`) (M13/Roadmap R5)

**Acceptance:** arena allocate/release is symmetric (no leaked instances); a team of 1-4
is handled by explicit code paths; all queue state lives on the server.
**Depends on:** M1, M2.

## M4: Round loop

**Goal:** a complete, finishable run with no puzzles yet (placeholder objective).

- [ ] **Round state machine**: Lobby -> Briefing -> Running -> Success | Failure -> Results -> Return to lobby
- [ ] Timer and progress tracking, replicated to clients
- [ ] Checkpoints and respawn rules (respawn at room checkpoint; revival by teammates is a stretch idea logged in the roadmap)
- [ ] Win condition (all living team members reach the exit) and lose condition (hazard catches too many players or time expires)
- [ ] Results payload (time, rooms cleared, coins/XP earned)
- [ ] Cleanup between rounds

**Acceptance:** every state has an entry and exit function; all transitions are in one
table; no round resource survives past `Results`.
**Depends on:** M3.

## M5: Hazard system

**Goal:** the pressure that drives every run.

- [ ] **Hazard interface**: `Start`, `Update(dt)`, `GetProgress`, `Stop`, `Reset`, plus config-defined speed curves
- [ ] First hazard: **Rising Water** (server-side moving volume with elimination check)
- [ ] Second hazard: **Rising Lava** (same interface, different visuals/damage rules)
- [ ] Hazard speed scaling by team size and difficulty
- [ ] Safe-zone rules and "hazard slows while a room is being solved" tuning hook (config-driven)
- [ ] Client hooks for VFX/audio (events only; visuals added in M9/M12)

**Acceptance:** adding a third hazard requires only a new module + config entry, no
changes to the round loop; elimination logic is server-only.
**Depends on:** M4.

## M6: Puzzle framework and Location 1

**Goal:** the signature gameplay.

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

**Acceptance:** each puzzle is data-driven and has a documented reset path; all puzzle
state is server-side; `LEVEL_DESIGN.md` documents every room with a solve walkthrough.
**Depends on:** M4, M5.

## M7: Rewards, shop and monetization

**Goal:** a healthy, fair economy and the first revenue hooks.

- [ ] Reward calculation (base + speed bonus + teamwork bonus + first-clear bonus), config-driven
- [ ] XP/level system with unlock gates
- [ ] **Cosmetic shop** (trails, hats, camp decor, death-splash effects): purchase with coins, ownership checks, equip/unequip
- [ ] **Game pass hooks:** 2x Coins pass (apply in `EconomyService`, never client-side)
- [ ] **Developer products:** coin packs via idempotent `ProcessReceipt`
- [ ] Pricing table in config; economy balance notes in `docs/DECISIONS.md`
- [ ] No paid randomness in v1 (see handoff section 4)

**Acceptance:** every grant path is idempotent and server-side; receipts are recorded;
ownership is checked on the server before any equip.
**Depends on:** M2, M4.

## M8: Retention layer

**Goal:** give players reasons to return within 24-48 hours.

- [ ] **Daily Expedition**: a date-seeded (UTC) rotating combination of location, hazard and modifier; bonus rewards for the first clear of the day
- [ ] **Streak counter** with a forgiving rule (one missed day pauses rather than resets, config-driven)
- [ ] **Daily reward** (claimable once per UTC day)
- [ ] **Team Camp**: lobby-side camp that visibly grows with the player's progress and purchases (v1: per-player camp upgrades, displayed in the lobby for the party)
- [ ] Milestone rewards (e.g. 3-day, 7-day streaks)
- [ ] Time helpers tested by reasoning about edge cases (UTC midnight rollover, leap/DST not applicable since UTC)

**Acceptance:** all date logic uses UTC and a single `Time` module; claim endpoints are
idempotent; nothing relies on client clocks.
**Depends on:** M2, M6, M7.

## M9: UI/UX and onboarding

**Goal:** a clear, mobile-friendly interface and a first-minute experience that prevents
early bounce.

- [ ] HUD: hazard progress bar, timer, objective text, teammate status
- [ ] Lobby UI: party panel, ready button, Daily Expedition card, streak display
- [ ] Results screen (time, rewards, "play again" with the same team)
- [ ] Shop and inventory UI
- [ ] **Tutorial/first-run flow**: guided Room 0 that teaches the core "hold the door" idea in under 90 seconds, skippable for returning players
- [ ] Touch-first layout, large tap targets, safe-area handling; keyboard/gamepad parity
- [ ] Accessibility basics: colour-blind-safe cues (shape + colour), optional reduced-motion setting, readable font sizes
- [ ] Audio and VFX hook points (placeholders)

**Acceptance:** all UI is built from small modules driven by data; no UI module makes
gameplay decisions; tutorial progress is stored in the profile.
**Depends on:** M4, M6, M7, M8.

## M10: Analytics and tuning

**Goal:** know where players quit and balance with data.

- [ ] `AnalyticsService` wrapper (event names and payloads defined in one place) using Roblox's built-in analytics/custom events where available (`TODO(verify-in-studio)`)
- [ ] Funnel events: join, tutorial start/complete, first room cleared, first run completed, second run started, shop open, purchase, daily claim
- [ ] Per-puzzle fail/time events to find frustrating rooms
- [ ] Feature flags and remote-config-style tunables in `Config`
- [ ] `docs/ANALYTICS.md` listing every event and what question it answers

**Acceptance:** event names are constants; no PII; analytics calls can never throw into
gameplay (wrapped in `pcall`).
**Depends on:** M4-M9.

## M11: Safety and anti-exploit

**Goal:** harden before real players arrive.

- [ ] Remote audit: every remote reviewed for validation, rate limit, and permission
- [ ] Server-side sanity checks: movement/teleport plausibility around puzzle interactions, interaction distance checks, cooldowns
- [ ] Duplicate-reward and race-condition review (leave-while-saving, double-claim)
- [ ] Moderation/filtering review for any player-visible text
- [ ] Failure-mode review: DataStore outage, empty teams, mid-round disconnects
- [ ] `docs/SECURITY.md` with threat list and mitigations

**Acceptance:** every remote appears in the audit table; every reward path has an
idempotency argument written down.
**Depends on:** M2-M10.

## M12: Studio transition (the planned handover)

**Goal:** move development from this repo-only phase into Studio-connected work with the
Roblox Claude MCP/integration.

- [ ] Owner sets up Studio, Rojo (or the chosen sync), and the MCP integration
- [ ] Sync the repo into a Studio place; resolve first-run errors
- [ ] **Work through `docs/STUDIO_VERIFY.md`** top to bottom; record results
- [ ] Execute the full first playtest: tutorial, one full run per team size (1-4), disconnect cases
- [ ] Replace placeholder geometry with real art/lighting (owner-led, Claude assists)
- [ ] Add VFX/audio, tune hazard speed and puzzle difficulty
- [ ] Decide library adoption (e.g. data/session-lock libraries) now that testing is possible
- [ ] Update `docs/ARCHITECTURE.md`: which workflows are Studio-first vs repo-first from now on

**Acceptance:** all `TODO(verify-in-studio)` items are resolved or converted into issues;
first successful end-to-end run recorded in `STATUS.md`.
**Depends on:** M0-M11 (may be **pulled forward** at any time the MCP is ready; if so,
treat the Studio-connected workflow as primary and keep the repo as source of truth).

## M13: Launch readiness

**Goal:** ship a polished first version.

- [ ] **Location 2** (new theme and hazard combination) to prove the content pipeline
- [ ] Store page: title, description, tags, thumbnails/icon shot list, trailer idea list
- [ ] Release checklist: settings, age/content questionnaire, game passes/products created, DataStore names, publishing flow
- [ ] **Soft launch plan**: small friend test, then limited public test, with metrics thresholds to proceed (D1 return rate, first-play bounce, tutorial completion)
- [ ] Update cadence plan (weekly small update, monthly new location)
- [ ] Community plan (Roblox group, update log, bug-report channel)

**Acceptance:** release checklist fully ticked; thresholds for go/no-go written down.
**Depends on:** M12.

---

## Post-launch roadmap (not yet in scope; keep the architecture ready)

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

## Feature-to-milestone index

Every big feature has exactly one home. If a feature is not on this list, add it to the
right milestone here and note it in [`DECISIONS.md`](DECISIONS.md) **before** building it.

| Feature | Milestone |
|---------|-----------|
| Repo layout, docs, conventions | M0 |
| Bootstrap, Signal/Maid/Logger, Remotes, Config, Types, feature flags, client-ready handshake | M1 |
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

---

## Ideas parking lot

Ideas that came up while building but are **outside the current milestone's scope**.
They are logged here instead of being built (scope control).

| Idea | Raised in | Possible home |
|------|-----------|---------------|
| Teammate revival during a run | handoff M4 | R4 |
