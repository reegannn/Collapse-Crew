# Conventions

The working agreements for this repo: how commits, branches and pull requests are
written, how code is styled, and what "done" means. Sourced from
[`handoff.md`](../handoff.md) sections 2, 8, 9 and 10.

## The one rule that overrides everything (handoff phase)

**Nothing is run.** No game, Studio, Rojo, Wally, Selene, StyLua, analyzers, tests, build
scripts, package managers or installers. Work is done by writing files and reviewing them
by reading. If it is unclear whether something counts as "running", it is not run, and
the question goes into `docs/STATUS.md` under "Questions for owner".

## Commits

Format: `m<N>: <what changed, in the imperative>`

```
m2: add DataService load/save skeleton
m2: fix autosave skipping players in safe mode
m0: add repo skeleton, tool configs and docs
```

- The `m<N>:` prefix is the milestone the work belongs to. Use `docs:` for
  documentation-only changes that belong to no milestone, and `chore:` for housekeeping.
- Keep commits small and focused on one thing.
- **Docs travel with code:** if a commit changes behaviour or architecture, the same
  commit updates the doc that describes it.

## Branches

- The plan is one branch per milestone, named like `m1-core-framework`, and no direct
  commits to `main` unless the owner says so.
- During the Claude Code handoff phase the hosting environment assigns one working branch
  per session, so a session's milestones may share that branch. The `m<N>:` commit
  prefixes keep the milestones separable. See `DECISIONS.md` D-002.

## Pull requests

Use the template in `.github/pull_request_template.md`. Every PR description states:
what changed, why, which acceptance criteria are met, the open
`TODO(verify-in-studio)` items, and a link to the milestone review file.

## Definition of done (per milestone)

1. All features implemented, or explicitly deferred with a reason in `ROADMAP.md`.
2. Acceptance criteria checked by reading.
3. Self-Review Gate complete (below).
4. `STATUS.md` and `STUDIO_VERIFY.md` updated.

## Self-Review Gate (end of every milestone)

Static review **by reading only**.

1. Re-read every file changed in the milestone, top to bottom, as if reviewing someone
   else's pull request. A read-only review subagent may be used.
2. Walk the checklist in `handoff.md` section 9; record each item as Pass / Fail / N/A.
3. Fix every Fail, then re-read the fixed code. Repeat until clean.
4. Write `docs/reviews/M<N>-review.md` (template in `docs/reviews/README.md`).
5. Only then mark the milestone done in `STATUS.md`.

## Marking unverified Roblox behaviour

Anything that depends on how the Roblox engine really behaves gets a comment at the exact
line:

```lua
-- TODO(verify-in-studio): <what to check>
```

Every such comment also gets a row in `docs/STUDIO_VERIFY.md`. Roblox APIs are never
invented: only APIs known to exist are used, and if there is doubt the simplest
well-known alternative is used with a `TODO(verify-in-studio)`.

## Session protocol

- **Start:** read `docs/STATUS.md`.
- **End:** write what was done, what is next, blockers, and questions for the owner.

## Code style (Luau)

### Files and names

| Thing | Convention | Example |
|-------|-----------|---------|
| Module file | `PascalCase.luau` | `DataService.luau` |
| Server script | `Name.server.luau` | `Bootstrap.server.luau` |
| Client script | `Name.client.luau` | `Bootstrap.client.luau` |
| Public function / method | `PascalCase` | `EconomyService.AddCoins` |
| Constructor | lowercase `new` (Roblox habit) | `Maid.new()` |
| Local variable, parameter, private function | `camelCase` | `local roundTimer` |
| Private field on an object | `_camelCase` | `self._items` |
| Constant | `UPPER_SNAKE_CASE` | `local SECONDS_PER_DAY = 86400` |
| Config key | `camelCase` inside a `PascalCase` group | `RoundConfig.Phases.briefingSeconds` |

### Rules

- `--!strict` at the top of every module where practical.
- Every module starts with a header comment stating its purpose and public API.
- One responsibility per module. Services never reach into each other's internals; they
  use public functions and signals only.
- Services and controllers expose `Init()` then `Start()` (see `ARCHITECTURE.md`).
- Use `task.wait`, `task.spawn`, `task.defer`, `task.delay`. Never `wait()`, `spawn()`,
  `delay()`.
- No magic numbers: tunable values live in `src/shared/Config/`. Content (locations,
  rooms, puzzles, cosmetics) lives in `src/shared/Content/`. Code reads data; it does not
  hard-code it.
- Data shapes are defined once, in `src/shared/Types`.
- Use `CollectionService` tags for puzzle and hazard objects instead of hard-coded paths.
- Every connection, instance and task created at runtime is cleaned up through a `Maid`.
- Wrap I/O boundaries (DataStore, Marketplace, Teleport) in `pcall`; log failures with
  `Logger`; never swallow errors silently.
- Short functions named for what they do; early returns over deep nesting.
- Comments explain *why*, not *what*.
- The server owns truth (coins, XP, inventory, outcomes, puzzle state, timers). The
  client never decides outcomes.
- All client-to-server messages go through the `Remotes` module, which validates
  arguments and rate-limits per player.
- No secrets, API keys or credentials in the repo. Ever.
- No third-party runtime libraries in v1 (see `DECISIONS.md` D-003).
