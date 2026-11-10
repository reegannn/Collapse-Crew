# M5 plan: Hazard system

Read [`README.md`](README.md) and [`00-game-design.md`](00-game-design.md) first.

## 1. Outcome

Runs now have pressure. A slab of water (or lava) rises under the team from the moment
the run starts. A player it covers is "caught": sent back to the checkpoint, or out of
the run once the checkpoint itself is under. Small teams and easy rooms get a slower
hazard. Adding a third hazard later means writing one module and one config entry.

## 2. Scope

**In:** the hazard interface; a shared rising-slab implementation; Rising Water and
Rising Lava; speed curves and scaling by team size and difficulty; the "slows while a
room is being solved" hook; protection rules; warning events; wiring into the round.

**Out:** puzzles (M6 supplies "is the room being solved?"; until then it is always
false); visuals and sound beyond a plain coloured slab (M9/M12).

## 3. Design

### 3.1 The interface

Every hazard is an object with these methods (acceptance: `Start`, `Update(dt)`,
`GetProgress`, `Stop`, `Reset`):

```lua
export type Hazard = {
    Start: (self: Hazard) -> (),          -- begin: the calm start delay counts down, then it moves
    Update: (self: Hazard, dt: number) -> (),   -- advance by dt seconds and check players
    GetProgress: (self: Hazard) -> number,      -- 0 (start height) to 1 (top)
    GetHeight: (self: Hazard) -> number,        -- world Y of the surface
    Stop: (self: Hazard) -> (),           -- freeze where it is
    Reset: (self: Hazard) -> (),          -- back to the start height, timers cleared, not running
    Destroy: (self: Hazard) -> (),
}
```

The round talks only to this interface. It never names a specific hazard.

### 3.2 How "adding a third hazard needs only a module and a config entry" is met

- `HazardConfig.Hazards[<id>]` describes it (data).
- `src/server/Hazards/Types/<id>.luau` implements it; the **file name is the hazard id**.
- `HazardRegistry.Create(id, context)` finds the module by name. The round calls only
  the registry. Nothing in `Round/` or `RoundService` mentions "water" or "lava".

Water and lava share almost everything, so both are thin modules over one shared
implementation, `RisingVolume`, differing only in their config.

### 3.3 Speed

Speed is not a fixed "studs per second" (that would make a tall location take longer
than a short one). Each location says how long the hazard should take to reach the top
at normal pace, and everything else is a multiplier:

```
baseSpeed = (endY - startY) / location.hazardBaseSeconds       -- studs per second
speed = baseSpeed
      x definition.speedFactor                                 -- water 1.0, lava 0.9
      x curve(progress)                                        -- from definition.speedCurve
      x HazardConfig.teamSizeSpeedMultiplier[active players]   -- 1 to 4
      x HazardConfig.difficultySpeedMultiplier[current room difficulty]   -- 1 to 5
      x (definition.solvingSlowMultiplier if the room is being solved, else 1)
      x context.getSpeedScale()                                -- 1 for now; M8 daily modifiers, M10 tuning
```

`curve(progress)` is straight-line interpolation between the points in `speedCurve`.

### 3.4 Who gets caught

Each `Update`, for every **active, unprotected** player:

- "Covered" = the player's feet are more than `definition.contactDepthStuds` below the
  surface. (Water: 2.5, about waist deep. Lava: 0.5, any real touch.)
- Covered time accumulates per player; it resets to 0 the moment they are not covered.
- When it reaches `definition.contactGraceSeconds` (water 2, lava 0) the hazard calls
  `context.onPlayerCaught(player)` and resets that player's timer.

A player is **protected** (skipped) when the round says so: eliminated, in the respawn
protection window, or standing in the exit zone. This is the "safe-zone rule".

All of this runs on the server. The client is never asked whether it was hit.

## 4. Files

| File | New/changed | Purpose |
|------|-------------|---------|
| `src/shared/Config/HazardConfig.luau` | changed | `speedFactor` replaces `baseSpeed`; contact, appearance, tick, warnings |
| `src/shared/Config/FlagConfig.luau` | changed | `LavaHazardEnabled = true` |
| `src/shared/Constants/RoundEvents.luau` | changed | `HazardStarted`, `HazardWarning` |
| `src/shared/Types/init.luau` | changed | `HazardDefinition` (updated) |
| `src/shared/Util/MathUtil.luau` | new | `EvaluateCurve`, `Clamp01` |
| `src/shared/Strings.luau` | changed | Hazard names, warning text |
| `src/server/Hazards/HazardRegistry.luau` | new | `Create`, `Validate` |
| `src/server/Hazards/RisingVolume.luau` | new | Shared implementation; exports `Hazard`, `HazardContext` |
| `src/server/Hazards/Types/RisingWater.luau` | new | |
| `src/server/Hazards/Types/RisingLava.luau` | new | |
| `src/server/Round/Round.luau` | changed | Create the hazard; real `GetHazardHeight` |
| `src/server/Round/States/Running.luau` | changed | Fill the two `HOOK(M5)` points |
| `src/server/Services/ExpeditionService.luau` | changed | Respect `LavaHazardEnabled` when choosing a hazard id |

## 5. Module specifications

### 5.1 `HazardConfig` (full replacement of the M1 file)

```lua
{
    replicationIntervalSeconds = 0.25,      -- how often HazardProgress/HazardHeight attributes are written
    warningThresholds = { 0.5, 0.8 },       -- progress values that raise a HazardWarning event
    slabDepthBelowStartStuds = 60,          -- how far the slab extends below its start height
    fallbackRootToFeetStuds = 3,            -- used if a character's own measurements are unavailable

    Hazards = {
        RisingWater = {
            id = "RisingWater", displayNameKey = "Hazard.RisingWater.Name",
            startDelaySeconds = 10,
            speedFactor = 1,
            speedCurve = { { atProgress = 0, multiplier = 1 }, { atProgress = 0.5, multiplier = 1.15 },
                           { atProgress = 1, multiplier = 1.4 } },
            solvingSlowMultiplier = 0.6,
            contactDepthStuds = 2.5,
            contactGraceSeconds = 2,
            Appearance = { color = Color3.fromRGB(40, 120, 220), transparency = 0.45,
                           material = Enum.Material.Glass },
        },
        RisingLava = {
            id = "RisingLava", displayNameKey = "Hazard.RisingLava.Name",
            startDelaySeconds = 14,
            speedFactor = 0.9,
            speedCurve = { { atProgress = 0, multiplier = 0.9 }, { atProgress = 0.6, multiplier = 1.2 },
                           { atProgress = 1, multiplier = 1.6 } },
            solvingSlowMultiplier = 0.7,
            contactDepthStuds = 0.5,
            contactGraceSeconds = 0,
            Appearance = { color = Color3.fromRGB(255, 110, 20), transparency = 0.1,
                           material = Enum.Material.Neon },
        },
    },

    teamSizeSpeedMultiplier = { 0.8, 0.9, 1, 1.05 },        -- index = active players
    difficultySpeedMultiplier = { 0.9, 1, 1.1, 1.2, 1.3 },  -- index = room difficulty 1-5
}
```

Hazards have no loop of their own: the round's tick (`RoundConfig.tickSeconds`) drives
`Update`. Say so in the config header. Update `Types.HazardDefinition` to match exactly (drop
`baseSpeed` and `displayName`; add `displayNameKey`, `speedFactor`,
`contactDepthStuds`, `Appearance`).

### 5.2 `Util/MathUtil`

```lua
MathUtil.Clamp01(value: number): number
MathUtil.EvaluateCurve(points: { Types.SpeedCurvePoint }, x: number): number
```

`EvaluateCurve`: `points` are sorted by `atProgress`. Before the first point return its
`multiplier`; after the last return its `multiplier`; otherwise find the two
neighbouring points and blend linearly. An empty list returns 1. Guard against two
points with the same `atProgress` (avoid dividing by zero: return the later one's value).

### 5.3 `RisingVolume`

```lua
export type HazardContext = {
    definition: Types.HazardDefinition,
    arenaFolder: Folder,                 -- attributes are written here
    parent: Instance,                    -- where the slab part goes (the location model)
    bounds: Types.HazardBounds,          -- world space
    baseSeconds: number,                 -- location.hazardBaseSeconds
    getActivePlayers: () -> { Player },
    getActiveCount: () -> number,
    getDifficulty: () -> number,         -- current room's difficulty, 1-5
    isSolving: () -> boolean,
    isPlayerProtected: (player: Player) -> boolean,
    getSpeedScale: () -> number,
    onPlayerCaught: (player: Player) -> (),
    onEvent: (kind: string, data: { [string]: any }?) -> (),
}

RisingVolume.new(context: HazardContext): Hazard
```

State: `height` (starts at `bounds.startY`), `isRunning`, `delayRemaining`,
`coveredSeconds` (`[Player] = number`), `nextThresholdIndex`, `replicationTimer`, the
slab `Part`.

**The slab.** One anchored part, `CanCollide = false`, `CanTouch = false`,
`CanQuery = false`, colour/transparency/material from `Appearance`, tagged `CC_Hazard`
with attribute `HazardId`. Size `(bounds.size.X, thickness, bounds.size.Z)` where
`thickness = (bounds.endY - bounds.startY) + slabDepthBelowStartStuds`. Its position is
set so its **top face** is at `height`:
`Vector3.new(bounds.center.X, height - thickness / 2, bounds.center.Z)`.

**`Start()`**: `isRunning = true`, `delayRemaining = definition.startDelaySeconds`,
event `HazardStarted { hazardId, delaySeconds }`.

**`Update(dt)`** (does nothing unless running):

1. If `delayRemaining > 0`: subtract `dt`; if still positive, go to step 4 (still check
   players, since they can jump into a stationary hazard).
2. Compute `speed` (3.3). Look up the two multiplier tables with the index clamped to
   the table's range (so 0 players or difficulty 6 cannot index out of range).
   `height = math.min(bounds.endY, height + speed * dt)`. Move the slab.
3. Warnings: while `nextThresholdIndex` is valid and progress has reached that
   threshold, fire `HazardWarning { threshold }` and advance the index.
4. Players: apply 3.4 to `getActivePlayers()`. Use `CharacterUtil.GetFeetY(player)`
   (fall back to root Y minus `fallbackRootToFeetStuds`); skip players with no
   character. Collect the players to catch in a list first, then call
   `onPlayerCaught` for each **after** the loop (the callback changes who is active).
5. Replication: every `replicationIntervalSeconds`, write `HazardProgress` and
   `HazardHeight` attributes on `arenaFolder`.
6. Forget `coveredSeconds` entries for players no longer in the active list, so the
   table cannot grow.

**`GetProgress()`**: `Clamp01((height - startY) / (endY - startY))`; 1 if the range is
zero. **`Stop()`**: `isRunning = false`. **`Reset()`**: height back to start, timers and
`coveredSeconds` cleared, threshold index back to 1, not running, slab moved, attributes
written. **`Destroy()`**: destroy the slab, clear the attributes.

### 5.4 `Types/RisingWater` and `Types/RisingLava`

Each is a few lines:

```lua
local RisingVolume = require(script.Parent.Parent.RisingVolume)
local RisingWater = {}
function RisingWater.new(context: RisingVolume.HazardContext): RisingVolume.Hazard
    return RisingVolume.new(context)
end
return RisingWater
```

Their header comments must say what makes each one different (it is all in the config:
water is forgiving, lava is instant) and that a hazard needing genuinely different
behaviour would implement the interface itself instead of delegating.

### 5.5 `HazardRegistry`

```lua
HazardRegistry.Create(hazardId: string, context): Hazard?     -- nil + Error log if unknown or it fails to build
HazardRegistry.Validate(): { string }                          -- problems found; empty = all good
HazardRegistry.GetDefinition(hazardId: string): Types.HazardDefinition?
```

`Create`: definition from `HazardConfig.Hazards[id]`; module from
`script.Parent.Types:FindFirstChild(id)`; `require` and call `.new(context)` inside
`pcall`. `Validate` checks every config entry has a module and a sane definition (curve
sorted and starting at 0, multipliers positive, grace not negative). `RoundService.Start`
calls `Validate` once and logs each problem at Error level.

### 5.6 Wiring into the round

- **`Round.new`**: after the location is known, build the context from the round's own
  methods and create the hazard with `HazardRegistry.Create(spec.hazardId, context)`.
  Give it to `round.maid`. If creation fails, log and continue with no hazard (the run
  is still playable on the timer alone).
  - `getDifficulty` -> `location.rooms[roomIndex].difficulty`
  - `isSolving` -> `false` for now, marked `-- HOOK(M6)`
  - `isPlayerProtected` -> `round:IsPlayerProtected(player)` **or** the player's root is
    inside `location.exitZone`
  - `getSpeedScale` -> `1`, marked `-- HOOK(M8/M10)`
  - `onPlayerCaught` -> `round:OnPlayerCaught(player, "Hazard")`
  - `onEvent` -> the round's event callback
- **`Round:GetHazardHeight()`**: `hazard and hazard:GetHeight() or -math.huge`.
- **`Running.Enter`**: `hazard:Start()`. **`Running.Tick`**: `hazard:Update(dt)`.
  **`Running.Exit`**: `hazard:Stop()`.
- **Choosing the hazard** (`ExpeditionService`, where the spec is built): the default is
  `RisingWater`. If the chosen id is `RisingLava` and `LavaHazardEnabled` is off, use
  `RisingWater`. (M6 makes the id come from the location; M8 from the Daily Expedition.)

### 5.7 Client hooks

No new remote. `RoundController` already relays `RoundEvent`; the two new kinds
(`HazardStarted`, `HazardWarning`) flow through it. Visuals and sounds attach in M9.
The slab itself replicates as an ordinary part, and the two attributes on the arena
folder give the HUD its progress bar.

## 6. Build order

1. `HazardConfig`, `Types`, `MathUtil`, constants, strings, flag.
2. `RisingVolume`.
3. The two type modules and `HazardRegistry`.
4. Round wiring. `ExpeditionService` flag check.
5. Docs. Review.

## 7. Engine assumptions (SV-5xx)

- Moving an anchored part by setting `Position`/`CFrame` ten times a second looks
  smooth enough to clients at these speeds (if not, M9 smooths it on the client).
- `Enum.Material.Glass` with partial transparency reads as water; `Neon` as lava
  (placeholder look until the art pass).
- `Humanoid.HipHeight` plus half the root part's height gives the feet position for
  both R6 and R15 characters.
- Attributes written on a `Folder` in `workspace` replicate to all clients.
- End-to-end checks for M12: stand in rising water for 2 seconds (caught); touch lava
  (caught at once); get caught with a dry checkpoint (respawn, protected); get caught
  with a flooded checkpoint (eliminated to the ledge); standing in the exit zone is
  safe; a solo run's hazard is visibly slower than a four-player run's; the hazard
  stops at the top and when the run ends.

## 8. Docs to update

`ARCHITECTURE.md` (a "Hazards" section: the interface, the registry rule, the speed
formula, who gets caught), `DECISIONS.md`, `STUDIO_VERIFY.md`, `ROADMAP.md`,
`LEVEL_DESIGN.md` (a short "Hazards" section: the two hazards and how they differ, in
plain language).

## 9. Additions to the roadmap

- `MathUtil`.
- Hazard pace defined per location as "seconds to reach the top".

## 10. Decisions to record (plain language)

- **One rising slab, checked by height, not by touch.** Simple, cheap and impossible to
  dodge with a network trick.
- **Hazard pace is set per location** as time-to-the-top, so locations of different
  heights feel equally urgent.
- **Water forgives, lava does not.** Two hazards that feel different from one shared
  implementation.
- **The hazard slows while the team is working a puzzle** (the tuning hook the brief
  asks for), so thinking is not punished as hard as dawdling.

## 11. Acceptance and review focus

Roadmap acceptance:

- [ ] Adding a third hazard requires only a new module + config entry, no changes to the
      round loop.
- [ ] Elimination logic is server-only.

Review focus:

1. Search `src/server/Round` and `RoundService` for the words `Water`, `Lava` and
   `RisingVolume`: there must be none.
2. Search `src/client` for anything that decides a catch: there must be none.
3. Check `Update` with: `dt = 0`; a huge `dt`; zero active players; a player with no
   character; `endY == startY`; a difficulty or team size outside the table.
4. `onPlayerCaught` is called after the loop over players, never during it.
5. The `coveredSeconds` table loses entries for players who leave or are eliminated.
6. `Destroy` removes the slab and the attributes; the hazard is owned by `round.maid`.
7. The speed formula in the code matches section 3.3 term for term, and every number
   comes from `HazardConfig` or the location.
