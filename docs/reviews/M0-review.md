# M0 Self-Review

Date: 2026-11-10   Reviewer: Claude Code (static read-only review)

M0 contains configuration and documentation only (no Luau code), so most code-oriented
checklist items are N/A. The review was done by re-reading every file below, top to
bottom. No subagent was used for this milestone because there is no code to audit.

## Scope

Files reviewed:

- `default.project.json`
- `stylua.toml`, `selene.toml`, `wally.toml`, `.gitignore`
- `README.md`, `handoff.md` (copied unchanged from the brief)
- `.github/pull_request_template.md`
- `docs/STATUS.md`, `docs/DECISIONS.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`,
  `docs/STUDIO_VERIFY.md`, `docs/LEVEL_DESIGN.md`, `docs/CONVENTIONS.md`,
  `docs/reviews/README.md`
- `src/server/.gitkeep`, `src/client/.gitkeep`, `src/shared/.gitkeep` (placeholders so
  the three empty source folders exist in git; removed in M1 when real files arrive)

## Checklist results

| Area | Item | Result | Note |
|------|------|--------|------|
| Correctness | Every `require` path resolves; no circular requires | N/A | No code yet |
| Correctness | Functions referenced exist with matching signatures | N/A | No code yet |
| Correctness | All code paths return/handle values | N/A | No code yet |
| Correctness | Edge cases (0/1/4 players, leaves, empty tables, missing config) | N/A | No code yet |
| Roblox | Server/client boundaries respected | Pass | Project file maps server code to `ServerScriptService` (never replicated to clients), client code to `StarterPlayerScripts`, shared code to `ReplicatedStorage` |
| Roblox | No deprecated globals | N/A | No code yet |
| Roblox | Players existing before `PlayerAdded` handled | N/A | No code yet |
| Roblox | Yielding calls protected | N/A | No code yet |
| Roblox | Engine-dependent items marked and logged | Pass | Tool-config assumptions logged as SV-001 to SV-005; policy check as SV-006 |
| Security | Every remote validates and is rate-limited | N/A | No remotes yet |
| Security | Client never decides outcomes | N/A | No code yet; rule recorded in `ARCHITECTURE.md` and `CONVENTIONS.md` |
| Security | Reward/purchase paths idempotent | N/A | No code yet |
| Security | No secrets in the repo | Pass | None present; `.gitignore` blocks `.env`, `*.pem`, `*.key` |
| Resources | Runtime connections/instances/tasks cleaned up | N/A | No code yet |
| Resources | No per-frame work or unbounded tables | N/A | No code yet |
| Maintainability | `--!strict`; types exported from `Types` | N/A | No code yet; rule recorded in `CONVENTIONS.md` |
| Maintainability | No magic numbers | N/A | No code yet |
| Maintainability | Module header comments | N/A | No code yet; config files each carry an explanatory comment |
| Maintainability | Consistent names; no dead code | Pass | Naming table defined in `CONVENTIONS.md` (D-004) |
| Docs | Acceptance criteria addressed | Pass | See below |
| Docs | `ARCHITECTURE.md`, `DECISIONS.md`, `LEVEL_DESIGN.md` up to date | Pass | Skeletons created; D-001 to D-005 recorded |

### Acceptance criteria (M0)

| Criterion | Result | Evidence |
|-----------|--------|----------|
| All files exist | Pass | Every file listed under M0 in `ROADMAP.md` is present |
| Project file maps all three source folders | Pass | `default.project.json`: `src/shared` -> `ReplicatedStorage.Shared`, `src/server` -> `ServerScriptService.Server`, `src/client` -> `StarterPlayer.StarterPlayerScripts.Client` |
| `STATUS.md` lists the milestone plan | Pass | Milestone table M0-M13 with statuses |
| No executable steps were run | Pass | Only file writes, a file copy (`handoff.md`), folder creation and git commands were used |

## Findings

| # | Severity (High/Med/Low) | File:line | Issue | Resolution |
|---|-------------------------|-----------|-------|------------|
| 1 | Low | `.gitignore` | First draft ignored `*.rbxm`/`*.rbxmx` (Roblox model files). That would silently stop art assets being committed during the M12 art pass. | Fixed: only place files (`*.rbxl`, `*.rbxlx` and their lock files) are ignored; a comment explains why models are allowed. |
| 2 | Low | `docs/CONVENTIONS.md` (Branches) | The brief asks for one branch per milestone, but the hosting environment assigns one branch per session and forbids pushing elsewhere without permission. | Recorded as decision D-002 and as owner question 5 in `STATUS.md`; commits are prefixed with their milestone so history stays separable. |
| 3 | Low | `src/*/.gitkeep` | Git cannot store empty folders, so placeholder files were needed for the three source folders to exist. | Accepted for M0. The placeholders are deleted in M1 when real files are added, so they never reach a Rojo sync. |

## Unverified assumptions (-> STUDIO_VERIFY.md)

- SV-001: Rojo accepts `default.project.json` and produces the expected tree.
- SV-002: The Rojo version in use supports `.luau` and `init.luau`.
- SV-003: StyLua accepts all options in `stylua.toml`.
- SV-004: Selene loads the `roblox` standard library.
- SV-005: Wally accepts `wally.toml` (only relevant if a library is adopted).
- SV-006: Roblox policy on paid random items (owner to confirm before M7 goes live).

## Verdict

**Ready.** M0 is documentation and configuration only; all acceptance criteria are met
by inspection. The tool configs are unexecuted by design and are covered by SV-001 to
SV-005 for M12.
