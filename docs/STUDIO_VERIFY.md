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

_Rows are added here by each milestone, grouped by milestone._
