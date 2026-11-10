# M1 Self-Review

Date: 2026-11-10   Reviewer: Claude Code (static read-only review)

**How this review was done.** Nothing was run. The review had three passes:

1. The author re-read each file while writing and fixed four issues before the formal
   review (findings A1-A4 below).
2. An independent **read-only review subagent** (restricted to reading and searching
   files; no execution, no edits) read all 24 source files, `default.project.json` and
   the conventions, traced the full require graph, and "mentally executed" the key
   paths. It reported **no High findings**, 2 Medium and 15 Low (findings 1-17).
3. Every finding was fixed or explicitly accepted, and the changed files were re-read
   after the fixes. Note: this last re-read was by the author; the subagent reviewed the
   code as it stood **before** the fixes.

## Scope

Files reviewed:

- `src/shared/Util/`: `Signal`, `Maid`, `Logger`, `Safe`, `TableUtil`, `Time`,
  `PlayerUtil`, `Lifecycle`
- `src/shared/Config/`: `GameConfig`, `RoundConfig`, `EconomyConfig`, `HazardConfig`,
  `UIConfig`, `FlagConfig`
- `src/shared/Flags.luau`, `src/shared/Types/init.luau`
- `src/shared/Remotes/`: `init`, `Definitions`, `Schema`, `RateLimiter`
- `src/server/Bootstrap.server.luau`, `src/server/Services/PlayerSessionService.luau`
- `src/client/Bootstrap.client.luau`, `src/client/Controllers/SessionController.luau`
- `default.project.json`
- Docs changed with the code: `ARCHITECTURE.md`, `DECISIONS.md` (D-006 to D-013),
  `STUDIO_VERIFY.md`, `ROADMAP.md`, `CONVENTIONS.md`, `STATUS.md`

## Require graph (no circular requires)

All static `require` calls resolve to files that exist. The graph only ever points
"downwards" through the layers in `ARCHITECTURE.md`, so there are no cycles.

- `Util/Logger`, `Util/Signal`, `Util/TableUtil`, `Util/Time`, `Util/PlayerUtil`,
  `Types`, `Remotes/RateLimiter` -> nothing
- `Util/Maid`, `Util/Safe`, `Util/Lifecycle` -> `Util/Logger`
- `Config/*` -> `Util/TableUtil` (`HazardConfig` also -> `Types`)
- `Flags` -> `Config/FlagConfig`, `Util/Logger`
- `Remotes/Schema` -> `Config/GameConfig`
- `Remotes/Definitions` -> `Remotes/Schema`, `Util/TableUtil`
- `Remotes` -> `Flags`, `Config/GameConfig`, `Util/Logger`, and its three children
- `server/Bootstrap` -> `GameConfig`, `Lifecycle`, `Logger`, `Remotes`; then (by name)
  `Services/PlayerSessionService` -> `Maid`, `Remotes`, `Signal`
- `client/Bootstrap` -> `GameConfig`, `Lifecycle`, `Logger`, `Remotes`; then (by name)
  `Controllers/SessionController` -> `Remotes`

## Checklist results

| Area | Item | Result | Note |
|------|------|--------|------|
| Correctness | Every `require` path resolves; no circular requires | Pass | See graph above |
| Correctness | Functions referenced exist with matching arguments and return types | Pass | Every cross-module call checked against its definition |
| Correctness | All code paths return/handle values | Pass | Validators always return `(bool, reason)`; `getDefinition`/`getInstance` return or raise |
| Correctness | Edge cases (0/1/4 players, leaves mid-action, empty tables, missing config) | Pass after fixes | Findings 1, 3, 5, 6 were edge-case gaps; all fixed |
| Roblox | Server/client boundaries respected | Pass | `Remotes` guards every function with a server/client check; no server-only API is used on the client |
| Roblox | No deprecated globals; `task` library used | Pass | No `wait(`, `spawn(`, `delay(` anywhere |
| Roblox | Players existing before `PlayerAdded` connects are handled | Pass | `PlayerUtil.ObservePlayers`; `PlayerSessionService` needs no join-time state |
| Roblox | Yielding calls protected, never block critical loops | Pass | `WaitForChild` has a timeout and nil handling; `InvokeServer` is wrapped; `Init`/`Start` are wrapped |
| Roblox | Engine-dependent items marked and logged | Pass after fixes | 14 `TODO(verify-in-studio)` comments, each with a `STUDIO_VERIFY.md` row (SV-101 to SV-116) |
| Security | Every remote validates arguments and is rate-limited | Pass | Order: sender present -> rate limit -> schema. Now fails closed if a limiter is missing (finding 8) |
| Security | Client never decides rewards, timers, puzzle results or ownership | Pass | The only remote is `ClientReady`, which grants nothing |
| Security | Reward/purchase paths idempotent | N/A | No rewards or purchases in M1 |
| Resources | Connections, instances and tasks cleaned up | Pass after fixes | Finding 1 (leak) fixed. Two connections are permanent on purpose and documented as such |
| Resources | No per-frame work; no unbounded tables | Pass | No per-frame work. Per-player tables are cleared on leave; the rest are bounded by the number of remotes/flags |
| Maintainability | `--!strict`; types exported from `Types` | Pass | 24 of 24 Luau files |
| Maintainability | No magic numbers | Pass (one documented exception) | Per-remote rate limits live beside their schema in `Remotes/Definitions` (finding 10; recorded in `CONVENTIONS.md`) |
| Maintainability | Module header comment states purpose and public API | Pass | All modules: purpose, public API, contract |
| Maintainability | Names consistent; dead code removed | Pass after fixes | Finding 16 fixed. `Safe`, `Time`, `PlayerUtil` and parts of `TableUtil` have no callers yet; they are M1 deliverables first used in M2 |
| Docs | Acceptance criteria addressed | Pass | See below |
| Docs | `ARCHITECTURE.md`, `DECISIONS.md` up to date | Pass | Start-up, layers, networking and module map written; D-006 to D-013 added |

### Acceptance criteria (M1)

| Criterion | Result | Evidence |
|-----------|--------|----------|
| No module has circular requires | Pass | Require graph above; layering rule in `ARCHITECTURE.md` |
| Every remote has a schema | Pass | `ClientReady` declares `args = {}` (no arguments allowed). `Remotes.InitServer` refuses to create any remote without one |
| Every module has a header comment describing its contract | Pass | Checked in all 24 files |
| No use of `wait()`/`spawn()` | Pass | None found; only `task.*` is used |

## Findings

Severity: **High** = would break at runtime or is a security hole; **Med** = likely bug or
wrong assumption; **Low** = hardening, clarity or style. Locations name the function
rather than a line number, because the fixes moved lines.

### Found by the author before the formal review

| # | Severity | File | Issue | Resolution |
|---|----------|------|-------|------------|
| A1 | Med | `Remotes/init.luau` (`InitServer`) | Nothing stopped a definition declaring a server-to-client `Function`, which the design forbids (a client could stall the server). | Fixed: `isValidDefinition` checks every definition at start-up and refuses bad ones. |
| A2 | Low | `Remotes/init.luau` (`FireClient`, `FireClients`) | Sending to a player who had already left relied on unknown engine behaviour. | Fixed: departed players are skipped. |
| A3 | Low | `PlayerSessionService` | Used `player.AncestryChanged` to detect a player leaving, an engine-specific assumption. | Fixed: uses `Players.PlayerRemoving`. (Later replaced entirely by finding 1's fix.) |
| A4 | Low | `PlayerSessionService` | Unused `PlayerUtil` import after simplifying the leave handling. | Fixed: import removed. |

### Found by the read-only review subagent

| # | Severity | File | Issue | Resolution |
|---|----------|------|-------|------------|
| 1 | Med | `PlayerSessionService` (`WhenClientReady`) | Called for a player who had already left, it would wait forever: two connections and the callback stayed in memory for the life of the server. | Fixed: callbacks are kept in a per-player list that is emptied when the player leaves, and nothing is stored for a player who has already gone. No per-call connections remain. |
| 2 | Med | `Remotes/init.luau` (`OnServerEvent`, `OnServerInvoke`) | A second handler for the same remote would each spend one of the player's rate-limit tokens (or silently replace the first handler). | Fixed: exactly one handler per remote; a second registration raises an error at start-up. |
| 3 | Low | `Remotes/Schema.luau` (`Array`) | A list with a gap could pass if its element validator accepted `nil`. | Fixed: gaps are refused before the element validator runs. |
| 4 | Low | `Remotes/RateLimiter.luau` | `os.clock()` assumed to measure real elapsed time, with no verification note. | Fixed: `TODO(verify-in-studio)` added (SV-112). |
| 5 | Low | `Flags.luau` (`IsEnabled`) | Promised "never throws" but a `nil` name would raise an error. | Fixed: non-text names are logged and treated as off. |
| 6 | Low | `Remotes/init.luau` (client functions) | If the remotes never arrived, `FireServer`/`InvokeServer` threw, contradicting "never throws". | Fixed: `FireServer` drops the message, `InvokeServer` returns `(false, "InvokeFailed")`; both log once. `OnClientEvent` still raises (it must return a real connection); documented. No retry: recorded as a known limitation in the header and `ARCHITECTURE.md`. |
| 7 | Low | `Util/Signal.luau` (`Wait`) | Resuming a waiting thread that had been cancelled would raise an error. | Fixed: only a suspended thread is resumed. |
| 8 | Low | `Remotes/init.luau` (`acceptCall`) | A client-to-server remote with no rate limiter would have been accepted unlimited ("fail open"). Not reachable, but unsafe by default. | Fixed: refuses the call ("fail closed") and logs an error. |
| 9 | Low | `Remotes/init.luau` (`isValidDefinition`) | A malformed `rateLimit` or a non-function in `args` could crash `InitServer`, leaving the game with no remotes. | Fixed: both are checked; the bad definition is skipped and logged. |
| 10 | Low | `Remotes/Definitions.luau` | Rate-limit numbers outside `Config`; table not frozen. | Accepted with a rule: `Definitions` is the documented home for per-remote limits (kept beside the schema so neither is forgotten); recorded in `CONVENTIONS.md`. The table is now frozen. |
| 11 | Low | `Remotes/Schema.luau`, `Definitions.luau` | "Never use `Schema.Table`/`Schema.Any` for client input" was only a comment. | Fixed: `Schema.IsLoose` tracks loose validators (including when wrapped in `Optional`/`Array`), and `InitServer` refuses client-to-server remotes that use them. |
| 12 | Low | `Remotes/Schema.luau` (`String`) | Length counted in bytes without saying so; invalid UTF-8 accepted. | Fixed: documented; invalid UTF-8 is now always refused. |
| 13 | Low | `Remotes/init.luau` (header) | Said failed messages are "ignored silently", but Functions answer `(false, "Rejected")`. | Fixed: header, `ARCHITECTURE.md` and D-007 reworded. |
| 14 | Low | `Util/Safe.luau`, `Util/Lifecycle.luau` | Plain `pcall` dropped the stack trace of start-up errors. | Fixed: `Lifecycle` (Init/Start) and `Safe.Spawn` use `xpcall` with `debug.traceback`. `Safe.Call`/`Safe.Retry` keep `pcall` because callers use the plain message. |
| 15 | Low | `Types/init.luau` vs `Util/Lifecycle.luau` | `Types.Service` requires `Init` and `Start`; Lifecycle called them optional. | Fixed: Lifecycle's header now says both are defined by convention and a missing one is tolerated. |
| 16 | Low | `Config/GameConfig.luau` | `Name`/`Version` broke the config naming convention. | Fixed: renamed `name`/`version`; `CONVENTIONS.md` now distinguishes config values (camelCase) from groups (PascalCase). |
| 17 | Low | Several headers | Small inaccuracies: `Time.SecondsUntilNextDay` range for fractional input; `Safe.Retry` first wait not capped; `Signal.Destroy` semantics; `PlayerSessionService` Maid never cleaned; `TableUtil.Reconcile` and lists. | Fixed: comments corrected; `Safe.Retry` now caps the first wait too. |

## Unverified assumptions (-> STUDIO_VERIFY.md)

All are recorded as SV-101 to SV-116. The ones that matter most:

- **SV-101**: strict-mode type check of every file (nothing has been through the analyser).
- **SV-102 / SV-103**: the client can see `ReplicatedStorage.Shared` and its own
  `Controllers` folder when its Bootstrap runs.
- **SV-104**: a departed `Player` has `Parent == nil` (used to drop late messages).
- **SV-112**: `os.clock()` measures real elapsed time (rate limiting depends on it).
- **SV-113 / SV-114**: `task.spawn(thread, ...)` and `xpcall(fn, debug.traceback, ...)`
  behave as the code assumes.
- **SV-115**: `ObservePlayers` reports each player exactly once under both signal modes.

## Known limitations carried forward (not defects)

- A client whose remotes never arrive has no networking and is never marked ready;
  there is no retry. To revisit if it shows up in testing (M12) or when the lobby needs
  a fallback (M3).
- `Safe`, `Time`, `PlayerUtil` and most of `TableUtil` have no callers yet. They are M1
  deliverables and are first exercised by M2.
- The team, round and puzzle shapes in `Types` are drafts, to be finalised in M3, M4
  and M6.

## Verdict

**Ready with caveats.** By reading, the server and client start-up paths and the
`ClientReady` handshake trace through cleanly end to end, and no client message can
reach game code without passing the rate limit and its schema. Every review finding was
fixed or explicitly accepted with a recorded reason. The caveat is the one that applies
to the whole handoff phase: none of this has been executed, so the 16 Studio
verification items (SV-101 to SV-116) must be worked through in M12 before the framework
is trusted.
