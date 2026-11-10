# Status

The living status log. **Read this first at the start of every session; update it at the
end.** The full plan is in [`ROADMAP.md`](ROADMAP.md).

**Last updated:** 2026-11-10
**Phase:** Handoff phase (repo only; nothing is run, built or tested)
**Current milestone:** M1 (Core framework)

## Milestones

| ID | Name | Status | Review |
|----|------|--------|--------|
| M0 | Repo foundation | Done | [M0-review](reviews/M0-review.md) |
| M1 | Core framework | In progress | |
| M2 | Player data and economy | Not started | |
| M3 | Lobby and teams | Not started | |
| M4 | Round loop | Not started | |
| M5 | Hazard system | Not started | |
| M6 | Puzzles and Location 1 | Not started | |
| M7 | Rewards, shop and monetization | Not started | |
| M8 | Retention layer | Not started | |
| M9 | UI/UX and onboarding | Not started | |
| M10 | Analytics and tuning | Not started | |
| M11 | Safety and anti-exploit | Not started | |
| M12 | Studio transition | Not started | |
| M13 | Launch readiness | Not started | |

"Done" means: written, statically reviewed by reading, and the Self-Review Gate passed.
It does **not** mean tested. Nothing is tested until M12.

## What is next

1. M1: Core framework (bootstrap, utilities, remotes, config, types, feature flags).

## Blockers

None.

## Questions for the owner

Until answered, the assumption in brackets is used. Answers get recorded in
[`DECISIONS.md`](DECISIONS.md).

1. Final game name and visual style direction? _(Assumed: "Collapse Crew"; bright, cartoon, mild.)_
2. Comfortable with a coin-only economy at launch, with no paid randomness? _(Assumed: yes.)_
3. Which Roblox account or group will own the experience? _(Unknown; no IDs are hard-coded.)_
4. When is the Studio + MCP setup expected? _(Unknown; M12 stays last unless pulled forward.)_
5. Branching: the hosting environment gives each Claude Code session a single branch, so
   milestones done in one session share it (commits are prefixed `m0:`, `m1:` ...). Is
   that acceptable, or should each milestone get its own branch and pull request?
   _(Assumed: acceptable. See DECISIONS D-002.)_

## Session log

### 2026-11-10 (session 1)

**Done**
- Inspected the repo: empty apart from a one-line README, so work began at M0.
- **M0 complete.** Added `default.project.json`, `stylua.toml`, `selene.toml`,
  `wally.toml`, `.gitignore`, `README.md`, the `docs/` skeleton, the pull request
  template and `docs/CONVENTIONS.md`. Copied the brief into the repo as `handoff.md`.
- M0 Self-Review Gate passed: [`reviews/M0-review.md`](reviews/M0-review.md).

**Nothing was run, built, installed, linted, formatted or tested.**
