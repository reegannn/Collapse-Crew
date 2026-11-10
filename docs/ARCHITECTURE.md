# Architecture

How the code is organised and why. Updated in the same commit as any change that affects
it. Plain-language explanations of individual choices are in
[`DECISIONS.md`](DECISIONS.md).

> **Status:** current as of M1 (core framework). Nothing described here has been run yet;
> see [`STUDIO_VERIFY.md`](STUDIO_VERIFY.md).

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
                 Config, Types, Util, Remotes, Flags, Content
```

## Where code lives

| Repo folder | In the Roblox game | Contains |
|-------------|--------------------|----------|
| `src/server` | `ServerScriptService.Server` | `Bootstrap.server.luau`, `Services/` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | `Bootstrap.client.luau`, `Controllers/` |
| `src/shared` | `ReplicatedStorage.Shared` | `Config/`, `Types/`, `Util/`, `Remotes/`, `Flags`, `Content/` (from M6) |

## Start-up sequence

Exactly one script runs by itself on each side: the **Bootstrap**. Everything else is a
module that the Bootstrap loads from a written-down list.

**Server** (`src/server/Bootstrap.server.luau`)

1. Set the log detail level from `GameConfig.Logging`.
2. `Remotes.InitServer()` creates the network remotes.
3. `Lifecycle.Run` loads each Service in `SERVICE_ORDER`, calls every `Init()`, then
   every `Start()`.
4. `Remotes.ReportUnhandled()` warns about any client-to-server remote with no listener.

**Client** (`src/client/Bootstrap.client.luau`)

1. Wait for the game to finish loading, so the shared modules exist.
2. Set the log detail level.
3. `Remotes.InitClient()` waits for the remotes the server created.
4. `Lifecycle.Run` loads each Controller in `CONTROLLER_ORDER`, `Init()` then `Start()`.
5. The last Controller (`SessionController`) tells the server "this client is ready".

### The two start-up steps

| Step | Meaning | Rules |
|------|---------|-------|
| `Init()` | "Get yourself ready." Create your own state and signals. | Must not pause (yield). Must not call other Services/Controllers. |
| `Start()` | "Begin working." Everyone has finished `Init` by now. | May call others, connect to their signals, connect remote handlers, start loops. May pause. |

All `Init()` calls finish, in list order, before any `Start()` runs. Each `Start()` runs
in its own thread, launched in list order. A module that fails to load or errors in
`Init` is logged and skipped; the rest still start.

**Convention:** connect remote handlers at the top of `Start()`, before anything that
pauses, so they are in place before any client can call them.

## Dependency layers (how circular requires are prevented)

A "circular require" is when module A needs B and B needs A; Roblox cannot load either.
The rule that prevents it: **a module may only require modules in its own layer or a
layer above it in this table.** (Within `Util`, the only cross-requires are onto
`Logger`.)

| Layer | Modules | May require |
|-------|---------|-------------|
| 1 | `Types`, `Util/*` | `Util/Logger` only (`Types` requires nothing) |
| 2 | `Config/*` | Layer 1 |
| 3 | `Flags` | Layers 1-2 |
| 4 | `Remotes` (+ `Definitions`, `Schema`, `RateLimiter`) | Layers 1-3 |
| 5 | `Content/*` (from M6) | Layers 1-2 |
| 6 | Server `Services/*`, client `Controllers/*` | Any shared layer; peers via public API only |
| 7 | `Bootstrap` scripts | Anything on their own side |

Services call each other only inside functions (from `Start()` onward), never while a
module is first loading, and only through public functions and signals.

## Networking

All client/server messages go through `Shared.Remotes`. No other code creates or touches
a `RemoteEvent`.

- **Declared:** every message is listed in `Remotes/Definitions.luau` with its kind,
  direction, argument schema, rate limit and a description. Undeclared messages do not
  exist.
- **Checked on the server, in this order:** sender still in the game -> per-player rate
  limit -> argument count and types. Only then does game code see the message.
- **Silent rejection:** a message that fails is ignored and noted only in the Debug log.
- **Requests with replies** (`Function` remotes) only go client -> server and always
  answer `(ok, payload)`. The server never waits on a client.
- **Principle:** clients send *what the player did* ("pressed switch X"), never *what
  should happen* ("give me 50 coins").

Remotes declared so far:

| Name | Direction | Kind | Purpose |
|------|-----------|------|---------|
| `ClientReady` | Client -> Server | Event | Client finished starting; safe to send it state |

## Building blocks

- **Services** (server) and **controllers** (client): modules that each own one job and
  expose `Init()` / `Start()`.
- **Signals** (`Util/Signal`): how a service announces events to others without knowing
  who listens.
- **Maid** (`Util/Maid`): tracks everything created at runtime (connections, instances,
  tasks) so it can all be cleaned up in one call.
- **State machines** run rounds: a fixed list of states and a single table of allowed
  transitions (M4).
- **Config** holds every tunable number, frozen (read-only) at runtime. **Content** holds
  locations, rooms, puzzles and cosmetics as data (M6+). Code reads both; it hard-codes
  neither.
- **Flags**: named on/off switches for features, read through `Shared.Flags`.
- **CollectionService tags** mark puzzle and hazard objects, so code finds them by tag
  rather than by a fixed path in the game tree (M5/M6).

## Rules that keep the design honest

1. The client never decides rewards, timers, puzzle results or ownership.
2. Services talk to each other through public functions and signals only.
3. Maps are generated from data definitions, so layouts are reproducible from the repo.
4. UI is built in code from small data-driven modules; no UI module makes gameplay
   decisions.
5. Anything saved or sent over the network is plain data: lists, or dictionaries with
   string keys (see `Types`).
6. All calendar logic goes through `Util/Time`, in UTC, on the server.
7. Anything depending on real engine behaviour is marked `TODO(verify-in-studio)` and
   listed in [`STUDIO_VERIFY.md`](STUDIO_VERIFY.md).

## Module map

### Shared (`src/shared` -> `ReplicatedStorage.Shared`)

| Module | Job | Requires |
|--------|-----|----------|
| `Types` | Every shared data shape (PlayerData, TeamState, RoundState, HazardDefinition, PuzzleDefinition ...) | nothing |
| `Util/Logger` | Levelled logging (`Debug`/`Info`/`Warn`/`Error`); never throws | nothing |
| `Util/Signal` | Lightweight events (`Connect`, `Once`, `Wait`, `Fire`) | nothing |
| `Util/Maid` | Cleanup tracker | `Logger` |
| `Util/Safe` | `pcall` helpers: `Call`, `Retry` (with backoff), `Spawn` | `Logger` |
| `Util/TableUtil` | `DeepCopy`, `Reconcile`, `DeepFreeze`, `Count`, `Keys`, `Values`, `Shuffle` | nothing |
| `Util/Time` | UTC clock and day-number helpers | nothing |
| `Util/PlayerUtil` | `ObservePlayers`: never miss players who joined early | nothing |
| `Util/Lifecycle` | Ordered load + `Init()` + `Start()` used by both Bootstraps | `Logger` |
| `Config/GameConfig` | Game-wide settings (team size, logging, remote limits) | `TableUtil` |
| `Config/RoundConfig` | Phase durations, run time limit | `TableUtil` |
| `Config/EconomyConfig` | Coin limits | `TableUtil` |
| `Config/HazardConfig` | Hazard definitions and speed scaling | `TableUtil`, `Types` |
| `Config/UIConfig` | Tap-target and text-size minimums | `TableUtil` |
| `Config/FlagConfig` | Default value of every feature flag | `TableUtil` |
| `Flags` | `IsEnabled(name)`; the only way to read a flag | `FlagConfig`, `Logger` |
| `Remotes` | The network doorway (see Networking) | `Flags`, `GameConfig`, `Logger`, own children |
| `Remotes/Definitions` | Declarative list of every remote | `Schema` |
| `Remotes/Schema` | Argument validators | `GameConfig` |
| `Remotes/RateLimiter` | Per-player token-bucket limiter | nothing |

### Server (`src/server` -> `ServerScriptService.Server`)

| Module | Job | Requires |
|--------|-----|----------|
| `Bootstrap.server` | Starts the server (see Start-up sequence) | `GameConfig`, `Lifecycle`, `Logger`, `Remotes` |
| `Services/PlayerSessionService` | Tracks which clients have reported ready; `ClientReady` signal, `IsClientReady`, `WhenClientReady` | `Maid`, `Remotes`, `Signal` |

### Client (`src/client` -> `StarterPlayerScripts.Client`)

| Module | Job | Requires |
|--------|-----|----------|
| `Bootstrap.client` | Starts the client (see Start-up sequence) | `GameConfig`, `Lifecycle`, `Logger`, `Remotes` |
| `Controllers/SessionController` | Sends `ClientReady` once all controllers have started | `Remotes` |
