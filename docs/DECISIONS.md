# Decisions

Short records of decisions and the reasons behind them, written in plain language.
Newest at the bottom. Each record says **what** was decided, **why**, and what the
**alternatives** were, so a decision can be revisited later with full context.

Open questions for the owner are tracked at the end of this file and in
[`STATUS.md`](STATUS.md).

---

## D-001: Repo layout and how it maps into Roblox

**Date:** 2026-11-10 · **Milestone:** M0

**Decision.** The code lives in three folders, and `default.project.json` tells Rojo
(the tool that will later copy this repo into Roblox Studio) where each one goes:

| Repo folder | Place in the Roblox game | Who can see it |
|-------------|--------------------------|----------------|
| `src/server` | `ServerScriptService.Server` | Server only |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Each player's device |
| `src/shared` | `ReplicatedStorage.Shared` | Both |

**Why.** This is the most common Rojo layout, so it is well documented and unsurprising.
Putting each folder inside a named container (`Server`, `Client`, `Shared`) keeps our
code separate from anything Roblox or Studio adds to those services.

**Alternatives.** Mapping the folders directly onto the services (no `Server`/`Shared`
containers) is slightly shorter but mixes our files with everything else in the service.

---

## D-002: One working branch per session during the handoff phase

**Date:** 2026-11-10 · **Milestone:** M0

**Decision.** The handoff asks for one branch per milestone (for example
`m1-core-framework`). The Claude Code hosting environment instead assigns a single branch
for a session and does not allow pushing to other branches without the owner's explicit
permission. So, for now, milestones done in the same session share that session's branch,
and every commit message starts with its milestone (`m0:`, `m1:` ...) so the work can
still be told apart or split later.

**Why.** Following the environment's rule avoids pushing to branches the owner has not
approved. The commit prefixes keep the history as readable as separate branches would.

**How to change it.** If the owner prefers true per-milestone branches, say so and name
the branches (or approve the `m<N>-<name>` pattern); later sessions will use them.

---

## D-003: No third-party libraries in version 1

**Date:** 2026-11-10 · **Milestone:** M0 (from the handoff brief)

**Decision.** The game uses only small utilities written in this repo (`Signal`, `Maid`,
`Remotes`, and so on). `wally.toml` exists but lists no dependencies.

**Why.** Libraries have to be downloaded and tried out to be trusted, and nothing can be
downloaded or run during this phase. Writing small in-house tools keeps the repo
self-contained and fully readable.

**Revisit.** In M12, once Studio testing is possible, decide whether to adopt
battle-tested libraries (especially for data saving and session locking).

---

## D-004: Naming style

**Date:** 2026-11-10 · **Milestone:** M0

**Decision.** Public functions use `PascalCase` (`EconomyService.AddCoins`), matching the
names the handoff already uses (`Init`, `Start`, `GetProgress`). Constructors are the one
exception and use lowercase `new` (`Maid.new()`), which is the habit across Roblox's own
API (`Instance.new`, `Vector3.new`). Local variables are `camelCase`. Full table in
[`CONVENTIONS.md`](CONVENTIONS.md).

**Why.** One consistent style means nobody has to guess whether a function is called
`addCoins` or `AddCoins`. Following Roblox's own style makes our code read like the
examples in Roblox's documentation.

---

## D-005: `handoff.md` is kept unedited; `ROADMAP.md` is the living plan

**Date:** 2026-11-10 · **Milestone:** M0

**Decision.** The original brief is committed as `handoff.md` and left as written.
`docs/ROADMAP.md` is a copy of its milestone sections that gets ticked off and amended as
the project evolves.

**Why.** Keeping the original untouched means there is always a record of what was first
asked for, while the roadmap is free to change.

---

## Open questions for the owner

From `handoff.md` section 11. Until answered, the stated assumption is used.

| # | Question | Assumption in use | Answer |
|---|----------|-------------------|--------|
| 1 | Final game name and visual style direction? | Working title "Collapse Crew"; bright, cartoon, mild | _open_ |
| 2 | Comfortable with a coin-only economy at launch (no paid randomness)? | Yes: coins only, no loot boxes | _open_ |
| 3 | Which Roblox account or group will own the experience? | Unknown; no IDs are hard-coded | _open_ |
| 4 | When is the Studio + MCP setup expected? | Unknown; M12 stays last unless pulled forward | _open_ |
| 5 | Per-milestone branches (D-002): keep the single session branch, or switch? | Single session branch with `m<N>:` commit prefixes | _open_ |
