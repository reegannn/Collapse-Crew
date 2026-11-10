# Studio verification list

Nothing in this repo has been run. This file collects **everything that must be checked
in Roblox Studio** once access exists. It is the first work list for milestone M12.

Each row matches either a `-- TODO(verify-in-studio): ...` comment in the code or an
assumption about tools or Roblox policy that could not be checked by reading.

**How to use it (M12):** work top to bottom. For each row, do the check, then set the
status to `Verified`, `Fixed` (say what changed) or `Issue #<n>` (if it needs more work).

Status values: `Open` · `Verified` · `Fixed` · `Issue #<n>`

## Tooling and project setup

| ID | Where | What to check | Status |
|----|-------|---------------|--------|
| SV-001 | `default.project.json` | Rojo builds/syncs the project without errors, and the three folders appear at `ReplicatedStorage.Shared`, `ServerScriptService.Server` and `StarterPlayer.StarterPlayerScripts.Client`. | Open |
| SV-002 | `default.project.json` | The installed Rojo version supports `.luau` files and `init.luau` (Rojo 7.3 or newer is expected to). | Open |
| SV-003 | `stylua.toml` | StyLua accepts every option in the file (option names differ slightly between StyLua versions). | Open |
| SV-004 | `selene.toml` | Selene loads the `roblox` standard library definition (some versions need it generated first). | Open |
| SV-005 | `wally.toml` | Wally accepts the manifest (package name format, `private = true`, empty dependency tables). Only matters if a library is adopted in M12. | Open |

## Roblox policy (owner to confirm)

| ID | Where | What to check | Status |
|----|-------|---------------|--------|
| SV-006 | handoff section 4, M7 | Confirm current Roblox policy on paid random items before any monetization goes live. Default in this project: **no paid randomness**. | Open |

## Code behaviour

Rows are added by each milestone, grouped by milestone. Rows marked **(comment)** have a
matching `TODO(verify-in-studio)` comment at that spot in the code; the others are
wider assumptions with no single line to attach a comment to.

### M1: Core framework

| ID | Where | What to check | Status |
|----|-------|---------------|--------|
| SV-101 | every `--!strict` file | Open Studio's Script Analysis: no type errors. Pay attention to `Util/Signal` (generic `Signal<T...>`), and the `typeof(setmetatable(...))` class pattern in `Maid`, `Logger`, `RateLimiter`. Type errors do not stop the game running but should be cleaned up. | Open |
| SV-102 | `src/client/Bootstrap.client.luau` **(comment)** | After `game.Loaded`, `ReplicatedStorage.Shared` and all its descendants exist on the client, so the direct `Shared.Util...` requires never fail. | Open |
| SV-103 | `src/client/Bootstrap.client.luau` | The `Client` folder placed in `StarterPlayerScripts` is copied to each player with `Bootstrap` and the `Controllers` folder intact, and `Bootstrap` runs exactly once per player. | Open |
| SV-104 | `src/shared/Remotes/init.luau` **(comment)** | A `Player`'s `Parent` is `nil` once they have left, so late messages from departed players are dropped by `acceptCall`. | Open |
| SV-105 | `src/shared/Remotes/init.luau` | The `NetRemotes` folder and every remote appear on the client within the timeout; `ClientReady` reaches the server; the server log shows no "declared but no handler" warning. | Open |
| SV-106 | `src/shared/Remotes/init.luau` | A message fired before the receiving side has connected its handler is queued and delivered once the handler connects (true for both directions). The ready handshake does not depend on this, but later milestones assume it as a safety net. | Open |
| SV-107 | `src/shared/Remotes/init.luau` | With a deliberately bad call from a test client (wrong argument type, too many arguments, rapid spam), the handler is not invoked and only a Debug log line appears. | Open |
| SV-108 | `src/shared/Util/Maid.luau` **(comment)** | `task.cancel` on a suspended or `task.wait`-ing thread stops it without raising an error. | Open |
| SV-109 | `src/shared/Util/Time.luau` **(comment)** | `workspace:GetServerTimeNow()` returns a Unix-epoch based clock that matches between server and clients. | Open |
| SV-110 | `src/shared/Util/Time.luau` **(comment)** | `os.date("!%Y-%m-%d", t)` returns the UTC date, e.g. `2026-11-10`. | Open |
| SV-111 | `src/shared/Util/Lifecycle.luau` | Start-up log shows "Started N of N modules" on both server and client, and a deliberately broken test module is reported and skipped without stopping the others. | Open |
