# Milestone self-reviews

One file per milestone: `M<N>-review.md`. Each is the written result of the Self-Review
Gate described in [`../CONVENTIONS.md`](../CONVENTIONS.md) and `handoff.md` section 9.

These are **static reviews**: the code was read, not run.

## Template

```
# M<N> Self-Review
Date: <date>   Reviewer: Claude Code (static read-only review)

## Scope
Files reviewed: <list>

## Checklist results
<table of checklist items with Pass/Fail/N/A and notes>

## Findings
| # | Severity (High/Med/Low) | File:line | Issue | Resolution |
|---|-------------------------|-----------|-------|------------|

## Unverified assumptions (-> STUDIO_VERIFY.md)
- <item>

## Verdict
<Ready / Ready with caveats / Not ready> and why
```

## Checklist used in every review

**Correctness**
- Every `require` path resolves to a file that exists; no circular requires
- Every function referenced exists with matching arguments and return types
- All code paths return/handle values (no accidental `nil` returns)
- Edge cases: 0/1/4 players, player leaves mid-action, empty tables, missing config keys

**Roblox-specific**
- Server/client boundaries respected (no server-only APIs on client and vice versa)
- No deprecated globals (`wait`, `spawn`, `delay`); `task` library used
- Players existing before `PlayerAdded` connects are handled
- Yielding calls (`DataStore`, `MarketplaceService`, `WaitForChild`) are protected (`pcall`/timeouts) and never block critical loops
- Anything dependent on engine behaviour has `TODO(verify-in-studio)` and is logged in `STUDIO_VERIFY.md`

**Security and fairness**
- Every remote validates arguments and is rate-limited
- Client never decides rewards, timers, puzzle results or ownership
- Reward/purchase paths are idempotent

**Resource safety**
- Every connection, instance and task created at runtime is cleaned up (Maid or equivalent)
- No per-frame work that could be event-driven; no unbounded tables

**Maintainability**
- `--!strict` where practical; types exported from `Types`
- No magic numbers (moved to Config)
- Module header comment states purpose and public API
- Names are consistent; dead code removed

**Docs**
- Acceptance criteria for the milestone are each addressed
- `ARCHITECTURE.md`, `DECISIONS.md`, `LEVEL_DESIGN.md` (if relevant) are up to date
