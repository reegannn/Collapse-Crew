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

**Update (2026-11-10).** Refined by D-013: each milestone still uses the session's
working branch, but is now merged through its own pull request before the next begins.

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

## D-006: Two-step start-up with a written-down load order

**Date:** 2026-11-10 · **Milestone:** M1

**Decision.** Each side of the game has exactly one self-running script (the Bootstrap).
It loads every Service (server) or Controller (client) from an explicit list, calls
`Init()` on all of them, and only then calls `Start()` on all of them.

**Why.** Games often break at start-up because module A tries to use module B before B
is ready. With two steps, `Init()` means "prepare yourself, talk to nobody" and
`Start()` means "everyone is prepared, begin". The explicit list means the load order is
visible in one place instead of depending on how Roblox happens to order scripts. If one
module fails, it is logged and skipped so the rest of the game still starts.

**Alternatives.** Letting every script run on its own (simple, but order is
unpredictable), or scanning a folder and loading whatever is found (less typing, but the
order is hidden and a stray file gets loaded by accident).

---

## D-007: One doorway for network messages, with silent rejection

**Date:** 2026-11-10 · **Milestone:** M1

**Decision.** Every message between a player's device and the server goes through the
`Remotes` module. Each message type is declared in one list
(`Remotes/Definitions.luau`) with the exact arguments it may carry and how often one
player may send it. A message that breaks those rules is dropped without telling the
sender which rule it broke. Requests that expect a reply only ever go from client to
server and always answer `(ok, payload)`. Each message type has exactly one piece of
server code that handles it.

**Why.** Cheaters can send any message they like, as often as they like. Checking every
message in one place means no individual feature can forget to check. Ignoring bad
messages silently gives a cheater no hints about what the server looks for. The server
never asks a client a question and waits, because a client could simply never answer and
freeze that part of the server.

**Alternatives.** Letting each feature create and check its own remotes (flexible, but
one forgotten check is a security hole).

---

## D-008: Settings are read-only and live in `Config`

**Date:** 2026-11-10 · **Milestone:** M1

**Decision.** Every tunable number lives in a `Config` module and is frozen when the
game starts, so code can read it but not change it. Each milestone adds its own settings
to the relevant Config module; M1 holds only what the framework itself needs.

**Why.** Balancing a game means changing numbers often. Keeping them all in one folder
means they can be found and changed without hunting through logic. Freezing them means a
bug cannot quietly change a setting for everyone mid-game.

---

## D-009: Clients announce when they are ready

**Date:** 2026-11-10 · **Milestone:** M1

**Decision.** When a client has finished starting, it sends a `ClientReady` message.
Server code that wants to push information to a player uses
`PlayerSessionService.WhenClientReady` to wait for that first.

**Why.** A player counts as "joined" slightly before their own scripts are running.
Waiting for an explicit "ready" removes any doubt about whether an early message will be
heard. The message grants nothing, so sending it falsely gains a cheater nothing.

---

## D-010: Plain `pcall` helpers instead of a Promise library

**Date:** 2026-11-10 · **Milestone:** M1

**Decision.** Operations that can fail (saving data, purchases) use the small `Safe`
module: `Safe.Call`, `Safe.Retry` (retry with increasing waits) and `Safe.Spawn`.

**Why.** The brief allows "Promise-lite or plain pcall helpers". A Promise library is
powerful but adds a concept the owner would need to learn, and a home-made one would be
untested code at the heart of everything. Three tiny functions cover what v1 needs and
can be understood in a minute.

---

## D-011: Dates are handled as UTC "day numbers"

**Date:** 2026-11-10 · **Milestone:** M1

**Decision.** Calendar logic (daily reward, streaks, Daily Expedition) uses a single
number: the count of whole UTC days since 1 January 1970. All of it goes through
`Util/Time`, and rules are only ever evaluated on the server.

**Why.** "Did the player come back the next day?" becomes simple subtraction
(`today - lastDay == 1`) with no time zones, daylight saving or month lengths to get
wrong. Using the server's clock means a player cannot change their phone's date to claim
rewards early.

---

## D-012: Saved and networked data uses lists or text-keyed dictionaries only

**Date:** 2026-11-10 · **Milestone:** M1

**Decision.** Any data that is saved or sent between server and client is built from
plain values in tables that are either a list (items 1, 2, 3 ...) or a dictionary whose
keys are text. For example a team's members are a list of small records, not a table
keyed by each player's numeric user id.

**Why.** Roblox does not reliably save or transmit dictionaries with number keys (they
can be silently altered or dropped). Agreeing on the shape now avoids a class of
"my data vanished" bugs later.

---

## D-013: One pull request per milestone, merged only when the owner confirms

**Date:** 2026-11-10 · **Decided by:** the owner

**Decision.** When a milestone passes its Self-Review Gate, a pull request (a proposal
to add the milestone's work to the main copy of the project) is opened with a detailed
description of everything in it, including all new features. Work then **stops** until
the owner confirms the merge. After merging, the working branch is restarted from the
updated `main` and the next milestone begins.

**Why.** It gives the owner a clear checkpoint after every milestone: a written summary
to read, and the final say on what goes into the project. It also keeps each pull
request to one milestone, so it stays readable.

**One exception, for history.** M0 and M1 were both already on the working branch when
this rule was made, and the environment does not allow splitting them onto separate
branches without extra permission. They therefore share the first pull request, with the
description divided clearly by milestone. From M2 onward it is strictly one milestone
per pull request.

---

## Open questions for the owner

From `handoff.md` section 11. Until answered, the stated assumption is used.

| # | Question | Assumption in use | Answer |
|---|----------|-------------------|--------|
| 1 | Final game name and visual style direction? | Working title "Collapse Crew"; bright, cartoon, mild | _open_ |
| 2 | Comfortable with a coin-only economy at launch (no paid randomness)? | Yes: coins only, no loot boxes | _open_ |
| 3 | Which Roblox account or group will own the experience? | Unknown; no IDs are hard-coded | _open_ |
| 4 | When is the Studio + MCP setup expected? | Unknown; M12 stays last unless pulled forward | _open_ |
| 5 | Per-milestone branches (D-002): keep the single session branch, or switch? | Single session branch with `m<N>:` commit prefixes | **Answered 2026-11-10:** one pull request per milestone, owner confirms each merge (D-013) |
