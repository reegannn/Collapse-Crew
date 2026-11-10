# Implementation plans

Detailed, milestone-by-milestone plans for everything that is left to build (M2 to M13).
The planning was done up front, in one pass, so that the whole game was designed as one
coherent thing before any more code was written. **A separate development session
implements these plans.**

If you are the developer picking this up: this folder is your brief. Read this page,
then [`00-game-design.md`](00-game-design.md), then the plan for the milestone in hand.

## Reading order for a new session

1. `CLAUDE.md` (repo root): the non-negotiable rules, in one screen.
2. `docs/STATUS.md`: where the project is right now.
3. `handoff.md` section 2 (hard rules) and section 9 (Self-Review Gate).
4. `docs/CONVENTIONS.md` and `docs/ARCHITECTURE.md`: how code is written and organised.
5. [`00-game-design.md`](00-game-design.md): the design that spans all milestones.
6. The plan for the current milestone (table below).
7. The existing code the milestone touches. **Always read the real code before trusting
   a plan's description of it.**

## The plans

| Plan | Milestone | Size | What exists when it is done |
|------|-----------|------|-----------------------------|
| [`00-game-design.md`](00-game-design.md) | all | - | Cross-milestone design: world, rules, module/remote/config catalogues |
| [`M02-player-data-and-economy.md`](M02-player-data-and-economy.md) | M2 | Medium | Progress saves; coins exist; Coins on the leaderboard |
| [`M03-lobby-and-teams.md`](M03-lobby-and-teams.md) | M3 | Large | A lobby with launch pads; teams form, ready up and are moved to a private arena |
| [`M04-round-loop.md`](M04-round-loop.md) | M4 | Large | A complete run with a start, a timer, win/lose and a results payload (no puzzles yet) |
| [`M05-hazard-system.md`](M05-hazard-system.md) | M5 | Medium | Rising water and lava that catch players and end runs |
| [`M06-puzzles-and-location-1.md`](M06-puzzles-and-location-1.md) | M6 | Very large | Four puzzle types and the 3-room Sinking Cargo Ship |
| [`M07-rewards-shop-monetization.md`](M07-rewards-shop-monetization.md) | M7 | Large | Real rewards, levels, a cosmetics shop, game pass and coin packs |
| [`M08-retention.md`](M08-retention.md) | M8 | Large | Daily Expedition, streaks, daily reward, camps |
| [`M09-ui-and-onboarding.md`](M09-ui-and-onboarding.md) | M9 | Very large | The on-screen interface and the tutorial |
| [`M10-analytics-and-tuning.md`](M10-analytics-and-tuning.md) | M10 | Medium | Event tracking and live tuning switches |
| [`M11-safety-and-anti-exploit.md`](M11-safety-and-anti-exploit.md) | M11 | Medium | Hardening pass and the security audit |
| [`M12-studio-transition.md`](M12-studio-transition.md) | M12 | Owner-led | First real run in Studio; everything verified |
| [`M13-launch-readiness.md`](M13-launch-readiness.md) | M13 | Owner-led | Location 2, store page, release checklist, soft launch |

Milestones are done strictly in order. Each depends on the ones before it.

## How to work a milestone

**Start**

1. Make sure the previous milestone's pull request is merged, then restart the working
   branch from the updated `main`.
2. Read the milestone's plan end to end, then the code it touches.
3. Copy the plan's "Additions to the roadmap" into `docs/ROADMAP.md` and note them in
   `docs/DECISIONS.md` (the brief requires new features to be recorded before they are
   built).
4. Set the milestone to "In progress" in `docs/STATUS.md`.

**Build**

5. Implement in the order given in the plan's "Build order". Commit in small steps,
   each message prefixed `m<N>:`.
6. Keep docs travelling with code: update `ARCHITECTURE.md` (module map, remotes table),
   `DECISIONS.md` (the plan's "Decisions to record", in plain language) and
   `STUDIO_VERIFY.md` (one row per `TODO(verify-in-studio)` comment) in the same commits
   as the code they describe.

**Finish**

7. Self-Review Gate (`handoff.md` section 9): re-read every changed file; run a
   **read-only** review subagent (Read/Grep/Glob only, no Bash, no edits) and give it
   the plan's "Review focus" list; fix every finding; re-read the fixes; write
   `docs/reviews/M<N>-review.md`.
8. Mark the milestone done in `STATUS.md` and `ROADMAP.md`; commit and push.
9. Open **one pull request** for the milestone with a detailed description (see
   `CONVENTIONS.md`), then **stop and ask the owner to confirm the merge**. Do not start
   the next milestone until it is merged.

## Plans versus reality

The plans are the default, not a cage. They were written without running anything, so
some details will turn out to be wrong.

- **If a plan conflicts with the real code, the code wins.** Read first.
- **If a plan is wrong, unclear or needlessly complicated,** choose the simplest
  approach that still meets the milestone's acceptance criteria in `ROADMAP.md`. Record
  the change in `DECISIONS.md` and list it under "Deviations from the plan" in the pull
  request so the owner sees it.
- **Things marked _(developer's choice)_** are deliberately left open.
- **Numbers are first guesses.** Every gameplay number in these plans is a starting
  point that cannot be play-tested until M12. Put them in `Config`, do not agonise.

What may **not** be deviated from, whatever a plan seems to imply:

1. Nothing is run, built, installed, linted, formatted or tested (handoff phase rule).
2. The server decides every outcome. The client never does.
3. All client-to-server messages go through `Shared.Remotes` with a strict schema and a
   rate limit. No loose validators for client input.
4. A service may only `require` services **above** it in the load order
   (see `00-game-design.md`). This is what prevents circular requires.
5. No invented Roblox APIs. If unsure an API exists or behaves as assumed, use the
   simplest well-known alternative and add `TODO(verify-in-studio)`.
6. One pull request per milestone; the owner confirms every merge.
7. No secrets or real IDs guessed into the repo. Game pass and product IDs stay `0`
   ("not configured") until the owner supplies them.

## How each plan is laid out

1. **Outcome**: what the game can do afterwards, in plain language.
2. **Scope**: what is in, and what is deliberately left for later.
3. **Design**: the decisions already made, with the reasoning.
4. **Files**: what to add and change.
5. **Module specifications**: public functions, behaviour rules, edge cases.
6. **Config, types, remotes, strings, flags**: exact additions.
7. **Build order**.
8. **Engine assumptions**: what needs `TODO(verify-in-studio)`.
9. **Docs to update**, **Additions to the roadmap**, **Decisions to record**.
10. **Acceptance and review focus**: the roadmap criteria and where bugs are most
    likely to hide.

## A note on size

M6 and M9 are much larger than the rest. If, when starting either, it looks too big to
review well as one pull request, ask the owner whether to split it in two (the plans
mark a natural split point). Do not split without asking: the owner's rule is one pull
request per milestone.
