# Architecture

How the code is organised and why. Updated in the same commit as any change that affects
it. Plain-language explanations of individual choices are in
[`DECISIONS.md`](DECISIONS.md).

> **Status:** the M0 skeleton. The sections below describe the agreed design. They are
> filled in with real module names as each milestone lands.

## The big picture

A Roblox game runs in two places at once:

- **The server** (Roblox's computers) is the referee. It owns everything that matters:
  coins, XP, inventory, timers, puzzle state and who won.
- **The client** (each player's device) is the screen and the controller. It draws the
  interface and sends requests ("I pressed this switch") to the server. The server
  decides whether the request is valid.

This split is called **server-authoritative** design. It exists because anything on a
player's device can be tampered with by cheaters; the server cannot.

```
 Player's device (client)                    Roblox server
 ┌───────────────────────────┐   requests    ┌────────────────────────────┐
 │ Controllers               │ ────────────> │ Remotes: validate + limit  │
 │  (screen, input, sounds)  │               │ Services: rules + truth    │
 │                           │ <──────────── │                            │
 └───────────────────────────┘    updates    └────────────────────────────┘
              \                                     /
               \________ Shared (both sides) ______/
                 Config, Types, Util, Remotes, Content
```

## Where code lives

| Repo folder | In the Roblox game | Contains |
|-------------|--------------------|----------|
| `src/server` | `ServerScriptService.Server` | `Bootstrap.server.luau`, `Services/` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | `Bootstrap.client.luau`, `Controllers/` |
| `src/shared` | `ReplicatedStorage.Shared` | `Config/`, `Types/`, `Util/`, `Remotes/`, `Content/` |

## Building blocks

- **Services** (server) and **controllers** (client) are modules that each own one job.
  Each exposes `Init()` then `Start()`.
- **Bootstrap**: exactly one script per side. It loads the services/controllers in a
  fixed, written-down order, calls every `Init()`, then every `Start()`.
- **Remotes**: the single doorway for client-to-server messages. Every message type is
  declared with a schema (what arguments are allowed) and a rate limit (how often a
  player may send it). Invalid or excessive calls are ignored.
- **State machines** run rounds: a fixed list of states and a single table of allowed
  transitions between them.
- **Config** holds every tunable number. **Content** holds locations, rooms, puzzles and
  cosmetics as data. Code reads both; it hard-codes neither.
- **Maid** tracks everything created at runtime (connections, instances, tasks) so it can
  all be cleaned up in one call.
- **CollectionService tags** mark puzzle and hazard objects, so code finds them by tag
  rather than by a fixed path in the game tree.

## Rules that keep the design honest

1. The client never decides rewards, timers, puzzle results or ownership.
2. Services talk to each other through public functions and signals only.
3. Maps are generated from data definitions, so layouts are reproducible from the repo.
4. UI is built in code from small data-driven modules; no UI module makes gameplay
   decisions.
5. Anything depending on real engine behaviour is marked `TODO(verify-in-studio)` and
   listed in [`STUDIO_VERIFY.md`](STUDIO_VERIFY.md).

## Module map

_Filled in from M1 onward: each module, its job, and what it depends on._
