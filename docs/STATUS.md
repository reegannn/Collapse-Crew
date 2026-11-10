# Status

The living status log. **Read this first at the start of every session; update it at the
end.** The full plan is in [`ROADMAP.md`](ROADMAP.md).

**Last updated:** 2026-11-10
**Phase:** Handoff phase (repo only; nothing is run, built or tested)
**Current milestone:** none in progress. M0 and M1 are done and waiting in a pull
request for the owner to confirm the merge. M2 starts after that merge.

## Milestones

| ID | Name | Status | Review |
|----|------|--------|--------|
| M0 | Repo foundation | Done (in pull request, awaiting owner's merge confirmation) | [M0-review](reviews/M0-review.md) |
| M1 | Core framework | Done (in pull request, awaiting owner's merge confirmation) | [M1-review](reviews/M1-review.md) |
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

1. **Owner:** read the M0 + M1 pull request and confirm the merge.
2. After the merge: restart the working branch from the updated `main`.
3. **M2: Player data and economy** (`DataService`, profile schema and migration,
   `EconomyService`, leaderstats, "safe mode" when data cannot be loaded).

## Blockers

- M2 cannot start until the owner confirms the M0 + M1 merge (owner's rule, see below).

## Questions for the owner

Until answered, the assumption in brackets is used. Answers get recorded in
[`DECISIONS.md`](DECISIONS.md).

1. Final game name and visual style direction? _(Assumed: "Collapse Crew"; bright, cartoon, mild.)_
2. Comfortable with a coin-only economy at launch, with no paid randomness? _(Assumed: yes.)_
3. Which Roblox account or group will own the experience? _(Unknown; no IDs are hard-coded.)_
4. When is the Studio + MCP setup expected? _(Unknown; M12 stays last unless pulled forward.)_
5. ~~Branching: one shared branch, or a branch and pull request per milestone?~~
   **Answered 2026-11-10:** one pull request per milestone, with a detailed description,
   and the owner confirms every merge before the next milestone starts (DECISIONS D-013).

## Workflow reminder (owner's rule)

After each milestone's Self-Review Gate: open a pull request with a detailed description
of all changes and new features, then **stop and ask the owner to confirm the merge**.
Do not start the next milestone until it is merged. Details in
[`CONVENTIONS.md`](CONVENTIONS.md).

## Session log

### 2026-11-10 (session 1)

**Done**
- Inspected the repo: empty apart from a one-line README, so work began at M0.
- **M0 complete.** Added `default.project.json`, `stylua.toml`, `selene.toml`,
  `wally.toml`, `.gitignore`, `README.md`, the `docs/` skeleton, the pull request
  template and `docs/CONVENTIONS.md`. Copied the brief into the repo as `handoff.md`.
- M0 Self-Review Gate passed: [`reviews/M0-review.md`](reviews/M0-review.md).
- **M1 complete.** Added the core framework: utilities (`Signal`, `Maid`, `Logger`,
  `Safe`, `TableUtil`, `Time`, `PlayerUtil`, `Lifecycle`), the `Remotes` networking
  doorway (definitions, schema validation, per-player rate limiting), `Config` modules,
  `Types`, `Flags`, the server and client Bootstrap scripts, and the client-ready
  handshake (`PlayerSessionService` / `SessionController`).
- M1 Self-Review Gate passed: [`reviews/M1-review.md`](reviews/M1-review.md). An
  independent read-only reviewer found no High-severity issues, 2 Medium and 15 Low;
  all were fixed or explicitly accepted. Verdict: Ready with caveats (untested until M12).
- The owner set the pull-request rule (one per milestone, owner confirms each merge);
  recorded as DECISIONS D-013. M0 and M1 share the first pull request because both were
  already on the working branch when the rule was made.

**Next**
- Wait for the owner to confirm the merge, then begin M2.

**Nothing was run, built, installed, linted, formatted or tested.**
