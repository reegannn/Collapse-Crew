# M6 plan: Puzzle framework and Location 1

Read [`README.md`](README.md) and [`00-game-design.md`](00-game-design.md) first.

This is the largest milestone. **Natural split point** if the owner agrees to two pull
requests: **M6a** = sections 5.1 to 5.9 plus Hold-the-door and Timed switches, with a
one-room test location; **M6b** = Power routing, Carry-and-place, the full Sinking
Cargo Ship and `LEVEL_DESIGN.md`. Ask before splitting.

## 1. Outcome

The signature gameplay exists. A run now takes place in the **Sinking Cargo Ship**:
three rooms, each closed by a gate that only a teamwork puzzle opens, with the water
rising underneath. There are four puzzle types. Every room can be finished by a team of
1, 2, 3 or 4, because puzzles scale to the number of players still active.

## 2. Scope

**In:** location and room definitions as data; the builder that turns a definition into
parts; gates; the puzzle interface and registry; validated interactions; pressure
plates; carrying; the four puzzle types; scaling to team size; the validator;
`LocationService`; Location 1; round integration; `LEVEL_DESIGN.md`.

**Out:** art, sound and animation (M9/M12); the tutorial room (M9, but it will reuse
Hold-the-door unchanged); Location 2 (M13); reward for speed (M7; this milestone only
stores `parSeconds`/`goldSeconds` in the location data).

## 3. Design

### 3.1 Coordinates

Each room has its own local coordinate system (all positions in content data use it):

```
            +Z (progress)                      origin = middle of the ENTRY wall's inner face, at floor level
   exit wall  ┌──────[gate]──────┐  z = D      X: -W/2 .. +W/2    (sideways)
              │                  │             Y: 0 = top of the floor (up is +)
              │      room        │             Z: 0 = entry wall .. D = exit wall
   entry wall └──────[door]──────┘  z = 0
                     x = 0
```

A position with `z > D` is **beyond the gate** (on the landing outside the exit door).

The location's rooms are laid out by the builder along `+Z`, each `connector.rise`
studs higher than the last (see the side view in `00-game-design.md` section 2). Rooms
have **no ceiling**: walls 18 studs high cannot be jumped, and an open top keeps the
camera usable on a phone.

### 3.2 Data shapes (content)

```lua
export type PuzzleType = "HoldTheDoor" | "PowerRouting" | "TimedSwitches" | "CarryAndPlace"
export type PuzzleDefinition = { id: string, type: PuzzleType, params: { [string]: any } }

export type RoomDefinition = {
    id: string, nameKey: string,
    size: Vector3,                  -- W (x), wall height (y), D (z)
    difficulty: number,             -- 1-5; feeds the hazard speed
    checkpoint: Vector3,            -- room-local
    puzzles: { PuzzleDefinition },  -- one or more VARIANTS; one is picked per run
}

export type ConnectorDefinition = { width: number, landingDepth: number, rampRun: number,
    rise: number, topLandingDepth: number, railHeight: number }

export type LocationTheme = { floorColor: Color3, wallColor: Color3, accentColor: Color3,
    floorMaterial: Enum.Material, wallMaterial: Enum.Material }

export type LocationDefinition = {
    id: string, nameKey: string,
    defaultHazardId: string,
    hazardBaseSeconds: number, timeLimitSeconds: number,
    parSeconds: number, goldSeconds: number,          -- used by M7's speed bonus
    wallThickness: number, doorWidth: number, doorHeight: number,
    connector: ConnectorDefinition,
    exitPlatformSize: Vector3, exitZoneHeight: number, spectatorOffset: Vector3,
    hazardStartDepth: number, hazardMargin: number,
    Theme: LocationTheme,
    rooms: { RoomDefinition },
}
```

`PuzzleDefinition` replaces the M1 draft (the `requiredPlayers` field is gone: each
puzzle module works it out from its own params).

**Variants** give replay value: a room lists one or more puzzles and each run picks one
using the run's seeded random generator (so a Daily Expedition is the same for everyone
that day). They also let a 3-room location use all four puzzle types.

### 3.3 What the builder makes for a room

- Floor; left and right walls; entry wall (with a doorway, except in room 1, which is
  closed); exit wall with a doorway.
- A **gate**: a slab filling the exit doorway, tagged `CC_Gate`.
- After the exit wall, a **connector**: flat landing (`landingDepth`), ramp
  (`rampRun` long, `rise` high), flat top landing (`topLandingDepth`), with side rails.
  It leads to the next room's entry doorway, or after the last room to the **exit
  platform**.
- A checkpoint marker (tagged, non-colliding).

Each puzzle builds **its own props** inside the room (plates, switches, crates,
partition walls). The builder provides the shell; the puzzle furnishes it.

### 3.4 Puzzle lifecycle

```
Round created  ->  for every room: puzzle = Registry.Create(type, context); puzzle:Setup(room, definition)
Running starts ->  puzzles[1]:Activate()
each tick      ->  puzzles[roomIndex]:Tick(dt)
puzzle solved  ->  gate locks open; puzzle:Deactivate(); round:AdvanceRoom(); next puzzle:Activate()
Round ends     ->  everything destroyed with the round's Maid
```

Only the **current** room's puzzle is active (accepts input, ticks). Later rooms are
unreachable anyway, because their gates are shut.

### 3.5 Scaling rule

Every puzzle scales to the **active player count** (not eliminated, not left), and is
told when that changes. A change may only make the puzzle **easier**: helpers are added,
never removed; timers lengthen, never shorten. This guarantees a team is never stranded
by losing a member mid-room.

## 4. Files

| File | New/changed | Purpose |
|------|-------------|---------|
| `src/shared/Config/PuzzleConfig.luau` | new | Interaction, plates, carrying, per-type tunables |
| `src/shared/Config/FlagConfig.luau` | changed | `UsePlaceholderLocation = false` |
| `src/shared/Constants/Tags.luau`, `Attributes.luau`, `RoundEvents.luau` | changed | New names |
| `src/shared/Constants/PuzzleTypes.luau` | new | The four type names |
| `src/shared/Content/Locations/init.luau` | new | Map of location id -> definition |
| `src/shared/Content/Locations/SinkingCargoShip.luau` | new | Location 1 |
| `src/shared/Types/init.luau` | changed | Shapes in 3.2; `RoundState.objectiveParams` |
| `src/shared/Strings.luau` | changed | Objectives, prompts, names |
| `src/server/World/Gate.luau` | new | |
| `src/server/World/LocationBuilder.luau` | new | |
| `src/server/World/LocationValidator.luau` | new | |
| `src/server/Services/LocationService.luau` | new | |
| `src/server/Puzzles/PuzzleRegistry.luau` | new | |
| `src/server/Puzzles/PuzzleBase.luau` | new | Shared behaviour every puzzle needs |
| `src/server/Puzzles/Interaction.luau` | new | The only door for player input |
| `src/server/Puzzles/Plate.luau` | new | |
| `src/server/Puzzles/Carry.luau` | new | |
| `src/server/Puzzles/Types/{HoldTheDoor,TimedSwitches,PowerRouting,CarryAndPlace}.luau` | new | |
| `src/server/Services/ExpeditionService.luau` | changed | Build real locations |
| `src/server/Round/Round.luau`, `States/Running.luau` | changed | Fill the `HOOK(M6)` points |
| `src/server/Bootstrap.server.luau` | changed | Add `LocationService` |
| `docs/LEVEL_DESIGN.md` | changed | Every puzzle type and room, with walkthroughs |

`LocationService` goes after `LobbyService` in `SERVICE_ORDER`.

## 5. Module specifications

### 5.1 `PuzzleConfig`

```lua
{
    assumedWalkSpeed = 16,            -- studs per second; used by the validator's travel estimates
    travelSlack = 1.5,                -- validator: required window = travel time x this
    solvingGraceSeconds = 4,          -- "being solved" lasts this long after the last interaction

    Interaction = { defaultMaxDistance = 10, distanceToleranceStuds = 4, cooldownSeconds = 0.25 },
    Gate = { openTransparency = 0.85 },
    Plate = { size = Vector3.new(8, 0.6, 8), zoneHeight = 7, pressedDropStuds = 0.3 },
    Carry = { walkSpeed = 9, defaultWalkSpeed = 16, holdOffset = CFrame.new(0, 0.5, -2.5),
              dropForwardStuds = 3, objectSize = Vector3.new(3, 3, 3), hazardReturnMarginStuds = 1 },

    HoldTheDoor = { minLeverBeyondGateStuds = 8, leverMaxDistance = 8 },
    TimedSwitches = { minWindowSeconds = 3, switchSize = Vector3.new(3, 4, 3) },
    PowerRouting = { stepCount = 4, minSpacingStuds = 10, valveSize = Vector3.new(4, 4, 1) },
    CarryAndPlace = { barrierDepthStuds = 6, hatchMaxDistance = 8, hatchHeight = 3 },

    Colors = { idle = Color3.fromRGB(170, 170, 170), active = Color3.fromRGB(80, 220, 120),
               warning = Color3.fromRGB(240, 180, 50), blocked = Color3.fromRGB(230, 70, 70) },
}
```

### 5.2 `World/Gate`

```lua
export type Gate = { ... }
Gate.new(part: BasePart): Gate
gate:SetOpen(isOpen: boolean)    -- temporary; ignored once locked
gate:LockOpen()                  -- permanent for this run
gate:IsOpen(): boolean
gate:IsLocked(): boolean
gate:Reset()                     -- closed and unlocked
```

Open = `CanCollide = false`, `CanQuery = false`, `Transparency = Gate.openTransparency`,
attribute `Open = true`. Closed = the reverse. (M9 animates on the client from the
attribute.)

### 5.3 `World/LocationBuilder`

```lua
export type RoomDetail = { index: number, definition: Types.RoomDefinition,
    puzzleDefinition: Types.PuzzleDefinition, origin: CFrame, size: Vector3,
    model: Model, gate: Gate.Gate, floorY: number }

LocationBuilder.Build(definition: Types.LocationDefinition, arena, options:
    { teamSize: number, random: Random }): (Types.BuiltLocation, { RoomDetail })
```

- Creates one `Model` named `Location` (parented to `arena.folder` **last**, given to
  `arena.maid`), with one child `Model` per room and one per connector.
- Layout, in location-local space, starting with room 1 at `(0, 0, 0)`:
  `nextOrigin.Z = origin.Z + D + wallThickness + landingDepth + rampRun +
  topLandingDepth + wallThickness`, `nextOrigin.Y = origin.Y + rise`. Convert to world
  with `arena.origin:ToWorldSpace(...)`. `RoomDetail.origin` is the world CFrame of the
  room's local origin, so `origin:PointToWorldSpace(localPosition)` places any prop.
- Walls with a doorway are three blocks: left of the door, right of the door, and the
  lintel above it. Reuse the ramp maths from `PlaceholderLocation` (move it into a
  shared helper in `PartFactory`, e.g. `PartFactory.Ramp(startPoint, run, rise, width,
  thickness)`, and make `PlaceholderLocation` use it too).
- Picks each room's puzzle variant with `options.random:NextInteger(1, #room.puzzles)`.
- Returns a `Types.BuiltLocation` filled exactly as `PlaceholderLocation` does (4 spawn
  points in room 1 near the entry; one `BuiltRoom` per room with a world-space
  checkpoint and bounds; exit zone over the exit platform; spectator point; hazard
  bounds covering every room and connector plus `hazardMargin`, `startY` =
  first floor minus `hazardStartDepth`, `endY` = exit platform top minus 2;
  `hazardBaseSeconds`; `timeLimitSeconds`) plus the list of `RoomDetail`.
- Pure construction: no connections, no loops, no yielding.

### 5.4 `Puzzles/Interaction`

The single path by which a player's action reaches a puzzle.

```lua
Interaction.CreatePrompt(parent: BasePart, options: { actionKey: string, objectKey: string?,
    maxDistance: number? }): ProximityPrompt
Interaction.Bind(prompt: ProximityPrompt, context: PuzzleContext, onAllowed: (player: Player) -> (),
    extraCheck: ((player: Player) -> boolean)?): RBXScriptConnection
Interaction.IsAllowed(player: Player, part: BasePart, maxDistance: number, context: PuzzleContext): boolean
```

`CreatePrompt`: `RequiresLineOfSight = false`, `HoldDuration = 0`, text from `Strings`.
Created **disabled**; puzzles enable their prompts in `Activate`.

`IsAllowed` (all must hold): `context.isActiveMember(player)`; the player is alive; the
distance from the player's root to `part.Position` is at most `maxDistance +
distanceToleranceStuds`; at least `cooldownSeconds` since this player's last accepted
interaction. Keep the per-player "last interaction" table in this module and clear the
entry on `Players.PlayerRemoving`. Mark a `-- HOOK(M11)` where `GuardService` will add
its plausibility check.

`Bind` connects `prompt.Triggered`; when `IsAllowed` and `extraCheck` (if any) pass, it
calls `onAllowed(player)`. The returned connection goes in the puzzle's Maid.

Why bother, when Roblox already limits prompt distance? Because the trigger request
comes from the player's device, and the server should not assume the device was honest.

### 5.5 `Puzzles/PuzzleBase`, the interface, and `PuzzleRegistry`

```lua
export type PuzzleContext = {
    teamId: string,
    random: Random,
    getActivePlayers: () -> { Player },
    getActiveCount: () -> number,
    isActiveMember: (player: Player) -> boolean,
    getHazardHeight: () -> number,
    onEvent: (kind: string, data: { [string]: any }?, onlyForPlayer: Player?) -> (),
    onObjectiveChanged: () -> (),
}

export type Puzzle = {
    Solved: Signal.Signal<>,
    Setup: (self: Puzzle, room: RoomDetail, definition: Types.PuzzleDefinition) -> (),
    Activate: (self: Puzzle) -> (),
    Deactivate: (self: Puzzle) -> (),
    OnPlayerAction: (self: Puzzle, player: Player, action: string, target: Instance?) -> (),
    Tick: (self: Puzzle, dt: number) -> (),
    IsSolved: (self: Puzzle) -> boolean,
    IsBeingSolved: (self: Puzzle) -> boolean,
    GetObjective: (self: Puzzle) -> (string, { any }?),   -- Strings key and format arguments
    OnActiveCountChanged: (self: Puzzle, count: number) -> (),
    Reset: (self: Puzzle) -> (),
    Destroy: (self: Puzzle) -> (),
}
```

The roadmap's required names (`Setup(room, definition)`, `OnPlayerAction`, `IsSolved`,
`Reset`, `Destroy`, a `Solved` signal) are all present with those exact names.

Every puzzle module also exposes two **static** functions used by the validator:

```lua
Module.GetRequiredPlayers(definition): number          -- players needed with NO helpers
Module.Validate(definition, room: Types.RoomDefinition, location: Types.LocationDefinition): { string }
```

`PuzzleBase` holds what all four share, so each type file contains only its own rules:
the context, a Maid, the `Solved` signal, `isActive`, `isSolved`,
`MarkActivity()` / recent-activity check (for `IsBeingSolved`), `SetPromptsEnabled`,
and `Solve()` which (once only) sets `isSolved`, calls `gate:LockOpen()`, fires the
`PuzzleSolved` event and the `Solved` signal. How the sharing is done (helper functions
that take the puzzle table, or a base table the types build on) is _developer's choice_;
keep it simple and readable.

**All prompt handlers route through `OnPlayerAction`:** a puzzle binds each prompt with
`Interaction.Bind(prompt, context, function(player) self:OnPlayerAction(player,
"<Action>", part) end)`. `OnPlayerAction` returns immediately unless the puzzle is
active and unsolved.

`PuzzleRegistry.Create(puzzleType, context): Puzzle?` and
`PuzzleRegistry.GetModule(puzzleType)`: find `Types/<puzzleType>` by name, exactly as
`HazardRegistry` does.

### 5.6 `Puzzles/Plate`

```lua
Plate.new(part: BasePart, zone: Types.Zone): Plate
plate:Update(players: { Player }, weights: { BasePart }): boolean   -- true if pressed
plate:IsPressed(): boolean
plate:Reset()
```

Pressed if any listed player's position (root X and Z, feet Y) is inside `zone`, **or**
any listed weight part's `Position` is inside it. The zone is the plate's footprint
extended `Plate.zoneHeight` upward. On a change: set attribute `Pressed`, change colour,
and move the part down or up by `pressedDropStuds`. Pure maths; no touch events.

### 5.7 `Puzzles/Carry`

One instance per puzzle that uses carried objects.

```lua
Carry.new(context: PuzzleContext, room: RoomDetail): CarrySystem
carry:AddObject(part: BasePart, homeCFrame: CFrame): Carriable
carry:PickUp(player, carriable): boolean
carry:Drop(player): Carriable?                      -- onto the floor just in front of the player
carry:PlaceAt(player, cframe: CFrame): Carriable?   -- exact placement (socket, hatch, plate)
carry:TakeFrom(player, carriable): boolean          -- pick up something that was placed
carry:GetCarried(player): Carriable?
carry:IsCarrying(player): boolean
carry:AnyoneCarrying(): boolean
carry:GetLooseParts(): { BasePart }                 -- objects not being carried (for plates)
carry:ReturnHome(carriable)
carry:SetLocked(carriable, isLocked: boolean)       -- locked objects cannot be picked up
carry:Tick(dt)
carry:Reset()
carry:Destroy()
```

Rules:

- **Not carried = anchored.** A loose object is an anchored part the server fully
  controls. There is no physics to go wrong.
- **Pick up:** only if the player carries nothing and the object is loose and unlocked.
  Unanchor, `CanCollide = false`, `Massless = true`, position at `root.CFrame *
  holdOffset`, join to the root with a `WeldConstraint`, set `Humanoid.WalkSpeed =
  Carry.walkSpeed`, attribute `Carried = true`.
- **Drop / place:** destroy the weld, anchor, `CanCollide = true`, restore
  `WalkSpeed = Carry.defaultWalkSpeed`. `Drop` puts it `dropForwardStuds` ahead of the
  player at floor height (`room.floorY` + half the object's height), **clamped inside
  the room's bounds**.
- **The server never reads a carried object's position** (it is physically owned by the
  carrier's device). It knows who carries what from its own tables.
- **One prompt per object**, whose text is "Pick up" when loose and "Drop" when carried.
- **`Tick` returns an object home** when: its carrier is no longer an active member, has
  no character, or is dead; its carrier has walked out of the room's bounds; or it is
  loose and below `getHazardHeight() - hazardReturnMarginStuds` while its home is still
  dry.
- Restore the carrier's walk speed in every one of those cases, and in `Destroy`.

### 5.8 The four puzzles

Each subsection gives: params (content data), rules, scaling, objective text, and the
**reset path** (required by the roadmap; copy it into the module header and
`LEVEL_DESIGN.md`).

#### Hold-the-door (`HoldTheDoor`)

*One player holds a pressure plate to keep the gate open while a teammate goes through
and pulls the lever that locks it open.*

- **Params:** `plates: { Vector3 }` (1 or 2), `lever: Vector3` (beyond the gate),
  `crateSpawns: { Vector3 }` (at least as many as plates).
- **Rules:** each tick, the gate is open exactly while **every** plate is pressed
  (`gate:SetOpen`). The lever's prompt can be used at any time, but only by a player
  who is **beyond the gate** (`extraCheck`: the player's room-local `z > D`), within
  `leverMaxDistance`. Pulling it calls `Solve()`.
- **Why the lever works even when the gate has closed again:** if the plate-holder is
  eliminated after a teammate has gone through, that teammate must still be able to
  finish. The plate is what gets someone *through*; the lever is what *finishes*.
- **Scaling:** required players = `#plates + 1`. Helper **crates** needed =
  `max(0, #plates + 1 - activeCount)`. Crates are carriable weights that hold a plate
  like a player would. Spawn any that are missing whenever the count changes; never
  remove one.
- **Being solved:** any plate pressed, anyone carrying, or recent activity.
- **Objective:** plate not held -> `Objective.HoldTheDoor.Plate` (or `.PlateSolo` when
  a crate exists: "Put the crate on the plate"); gate open ->
  `Objective.HoldTheDoor.Lever`.
- **Reset path:** gate closed and unlocked; lever back; plates up; every crate home.
- **Validate:** 1-2 plates inside the room; lever `z >= D + wallThickness +
  minLeverBeyondGateStuds` and within the landing; crate spawns inside the room and at
  least `#plates`; required players <= 4.

#### Timed switches (`TimedSwitches`)

*Switches around the room each stay lit for a few seconds. Light them all at once.*

- **Params:** `switches: { Vector3 }` (2 to 4), `windowSecondsByTeamSize: { number }`
  (exactly 4 entries, index = active players).
- **Rules:** pressing a switch lights it until `now + window`, where `window =
  windowSecondsByTeamSize[activeCount]` (index clamped 1-4). `Tick` puts out expired
  switches. When all are lit at the same moment -> `Solve()`. Each switch shows
  attributes `Lit` and `LitUntil` (a synced time, so M9 can draw a countdown).
- **Scaling:** purely the window table. With fewer players than switches the window is
  long enough for one player to run between them; with enough players it is short and
  demands coordination. When the count changes, switches already lit are extended to
  the new, longer window (never shortened).
- **Being solved:** any switch lit.
- **Objective:** `Objective.TimedSwitches.Light` with the switch count.
- **Reset path:** every switch unlit.
- **Validate:** 2-4 switches inside the room; table has 4 entries, each
  `>= minWindowSeconds`; and for each team size `n` smaller than the switch count:
  `n == 1` -> window >= (total path length through the switches in listed order /
  `assumedWalkSpeed`) x `travelSlack`; `n > 1` -> window >= (longest single leg /
  `assumedWalkSpeed`) x `travelSlack`.

#### Power routing (`PowerRouting`)

*Turn every valve to its marked position. Each crew member can only keep a limited
number lined up at once, so the valves must be shared out.*

- **Params:** `valves: { { position: Vector3, targetStep: number } }` (3 or 4;
  `targetStep` 0-3).
- **Rules:** a valve has a `step` 0-3; its prompt advances it by one (wrapping). It is
  **aligned** when `step == targetStep`. When a player aligns a valve it becomes
  **held by** that player (remember the order). `holdLimit = ceil(valveCount /
  activeCount)`. If a player now holds more than `holdLimit`, their **oldest** held
  valve "slips": it is set to a random non-target step and released (event
  `ValveSlipped`, sent to that player). Turning an aligned valve away un-aligns and
  releases it. All valves aligned at once -> `Solve()`.
- **Start:** every valve starts at a random step that is not its target
  (`context.random`).
- **Scaling:** the hold limit. Four players, four valves: one each. Two players, four
  valves: two each. Solo: all of them (it becomes a simple "set each valve" room). When
  a holder is eliminated or leaves, their valves stay aligned and simply stop counting
  against anyone.
- **Being solved:** recent activity.
- **Objective:** `Objective.PowerRouting.Align` with the valve count and the hold limit.
- **Reset path:** every valve re-scrambled; nobody holds anything.
- **Validate:** 3-4 valves inside the room, at least `minSpacingStuds` apart; each
  `targetStep` a whole number 0-3.
- **Readability note for M12:** this is the least obvious puzzle. Each valve needs a
  clear target marker and a clear "held by <name>" label; check it reads in 10 seconds
  and simplify if it does not.

#### Carry-and-place (`CarryAndPlace`)

*Power cells are on one side of a wall; their sockets are on the other. Cargo is not
allowed through the door, so cells must be handed through a hatch.*

- **Params:** `cellSpawns: { Vector3 }`, `sockets: { Vector3 }`, `partitionZ: number`,
  `doorwayX: number`, `hatchX: number`, `cellsByTeamSize: { number }` (4 entries).
- **Setup builds:** a partition wall across the room at `z = partitionZ` with a doorway
  at `doorwayX` and a waist-high **hatch** counter at `hatchX`; the cells (carriable);
  the sockets; an invisible **barrier zone** `barrierDepthStuds` deep centred on the
  doorway, with a visible coloured frame.
- **Rules:** `needed = cellsByTeamSize[activeCount]`, capped by the number of sockets
  and spawns. A socket's prompt inserts the cell the player is carrying (the cell is
  then locked). The hatch's prompt **puts down** a carried cell if the hatch is empty,
  or **picks up** the cell on it if the player's hands are empty; it is in reach from
  both sides. While the barrier is on, any carrier whose root enters the barrier zone
  loses the cell: it returns home (event `CargoBlocked` to that player). `Solve()` when
  filled sockets >= `needed`.
- **Scaling:** the barrier is **on only when `activeCount >= 2`** (solo players just
  carry cells through the door, slowly); and `needed` falls with team size. If the
  count drops, re-check: the puzzle may now be solved already.
- **Being solved:** anyone carrying, or recent activity.
- **Objective:** `Objective.CarryAndPlace.Hatch` (barrier on) or `.Carry` (barrier
  off), with the number needed and the number done.
- **Reset path:** every cell home and unlocked; sockets and hatch empty.
- **Validate:** `0 < partitionZ < D`; doorway and hatch fit in the wall and do not
  overlap; every cell spawn has `z < partitionZ` and every socket `z > partitionZ`;
  table has 4 entries; spawns and sockets each >= the largest entry.

### 5.9 `World/LocationValidator` and `LocationService`

```lua
LocationValidator.Validate(definition: Types.LocationDefinition): { string }   -- problems; empty = valid
```

Static checks ("assertions written as code"), each producing a readable message that
names the location, room and puzzle:

- Ids present and unique; at least one room; every room has at least one puzzle variant.
- Sizes positive; the doorway is narrower than the room and lower than the wall; the
  connector is at least as wide as the doorway; `rise > 0`.
- Checkpoint inside its room.
- **Every puzzle `type` exists in `PuzzleRegistry`.**
- **Every puzzle's `GetRequiredPlayers` is at most `GameConfig.Team.maxSize`.**
- Every puzzle's own `Validate` passes.
- `defaultHazardId` exists in `HazardConfig`; `hazardBaseSeconds > 0`;
  `timeLimitSeconds > 0`; `goldSeconds < parSeconds <= timeLimitSeconds`.

`LocationService`:

```lua
LocationService.Init()            -- validates every definition in Content.Locations; logs problems at Error level
LocationService.Start()
LocationService.GetDefinition(locationId): Types.LocationDefinition?
LocationService.IsUsable(locationId): boolean
LocationService.GetUsableIds(): { string }          -- sorted, so results are stable
LocationService.PickStandard(random: Random): string?
```

A location with problems is **not usable** and is never picked; the game falls back to
the placeholder rather than building something broken.

### 5.10 Integration

**`ExpeditionService`** (launch step 2-3): choose `locationId` with
`LocationService.PickStandard(Random.new(seed))`. If `UsePlaceholderLocation` is on, or
nothing is usable, or `LocationBuilder.Build` throws: fall back to
`PlaceholderLocation` (log why). Set `spec.hazardId = definition.defaultHazardId`
(then apply the lava flag). Store the returned `RoomDetail` list on the expedition
(`expedition.roomDetails`, nil for the placeholder).

**`Round`**:

- `Round.new`: if the expedition has room details, create and `Setup` one puzzle per
  room, each with a `PuzzleContext` built from the round's methods; connect its
  `Solved` signal to `round:OnPuzzleSolved(index)`. Everything goes in `round.maid`.
- `OnPuzzleSolved(index)`: ignore unless `index == roomIndex` and the phase is
  `Running`. `Deactivate` it, `AdvanceRoom()`, then `Activate` the next puzzle if there
  is one. Refresh the objective.
- Objective: `objectiveKey`/`objectiveParams` come from the active puzzle's
  `GetObjective()`; once the last room is solved, `Objective.ReachExit`. The puzzle
  calls `onObjectiveChanged` when its objective text should change; the round then
  re-reads it and replicates.
- Whenever the active count changes (a catch that eliminates, a member leaving):
  `activePuzzle:OnActiveCountChanged(GetActiveCount())`.
- Hazard hook: `isSolving` -> `activePuzzle ~= nil and activePuzzle:IsBeingSolved()`.

**`Running`**: `Enter` activates puzzle 1; `Tick` step 3 ticks the active puzzle;
`Exit` deactivates it.

### 5.11 Location 1: Sinking Cargo Ship (first-draft data)

```lua
{
    id = "SinkingCargoShip", nameKey = "Location.SinkingCargoShip.Name",
    defaultHazardId = "RisingWater",
    hazardBaseSeconds = 360, timeLimitSeconds = 480, parSeconds = 420, goldSeconds = 240,
    wallThickness = 2, doorWidth = 8, doorHeight = 10,
    connector = { width = 14, landingDepth = 18, rampRun = 30, rise = 16, topLandingDepth = 6, railHeight = 4 },
    exitPlatformSize = Vector3.new(36, 2, 36), exitZoneHeight = 12, spectatorOffset = Vector3.new(48, 12, 0),
    hazardStartDepth = 10, hazardMargin = 40,
    Theme = { ...steel greys with an orange accent... },
    rooms = {
        { id = "CargoHold", nameKey = "...", difficulty = 1, size = Vector3.new(48, 18, 56),
          checkpoint = Vector3.new(0, 0, 8),
          puzzles = {
            { id = "CargoHold_Door", type = "HoldTheDoor", params = {
                plates = { Vector3.new(0, 0, 44) },
                lever = Vector3.new(5, 0, 70),                 -- D 56 + wall 2 + 12
                crateSpawns = { Vector3.new(-14, 0, 22) } } },
          } },
        { id = "EngineRoom", nameKey = "...", difficulty = 2, size = Vector3.new(64, 18, 64),
          checkpoint = Vector3.new(0, 0, 8),
          puzzles = {
            { id = "EngineRoom_Switches", type = "TimedSwitches", params = {
                switches = { Vector3.new(-26, 0, 12), Vector3.new(26, 0, 32), Vector3.new(-26, 0, 52) },
                windowSecondsByTeamSize = { 14, 8, 5, 5 } } },
            { id = "EngineRoom_Doors", type = "HoldTheDoor", params = {
                plates = { Vector3.new(-16, 0, 52), Vector3.new(16, 0, 52) },
                lever = Vector3.new(5, 0, 78),                 -- D 64 + wall 2 + 12
                crateSpawns = { Vector3.new(-24, 0, 20), Vector3.new(24, 0, 20) } } },
          } },
        { id = "PumpDeck", nameKey = "...", difficulty = 3, size = Vector3.new(64, 18, 72),
          checkpoint = Vector3.new(0, 0, 8),
          puzzles = {
            { id = "PumpDeck_Cells", type = "CarryAndPlace", params = {
                cellSpawns = { Vector3.new(-24, 0, 12), Vector3.new(-8, 0, 12), Vector3.new(8, 0, 12), Vector3.new(24, 0, 12) },
                sockets = { Vector3.new(-24, 0, 64), Vector3.new(-8, 0, 64), Vector3.new(8, 0, 64), Vector3.new(24, 0, 64) },
                partitionZ = 36, doorwayX = 20, hatchX = -12,
                cellsByTeamSize = { 2, 3, 3, 4 } } },
            { id = "PumpDeck_Valves", type = "PowerRouting", params = {
                valves = { { position = Vector3.new(-26, 0, 12), targetStep = 1 },
                           { position = Vector3.new(26, 0, 12), targetStep = 3 },
                           { position = Vector3.new(-26, 0, 60), targetStep = 2 },
                           { position = Vector3.new(26, 0, 60), targetStep = 0 } } } },
          } },
    },
}
```

**Check the numbers against the validator by hand** before committing. For the switch
room: legs are about 56 studs each, 111 in total. Solo needs `111 / 16 x 1.5 = 10.4`
seconds (the window is 14: passes). Duo needs `56 / 16 x 1.5 = 5.2` (window 8: passes).

Pacing, as a first guess to tune in M12: floors are at heights 0, 16 and 32, the exit
at 48; the water starts 10 below room 1 and needs about 360 seconds to the top. Room
1's floor goes under at roughly 75 seconds and becomes unsafe (waist deep) at about 90;
room 2's floor at about 3 minutes; room 3's at about 4.5 minutes.

### 5.12 `LEVEL_DESIGN.md`

Fill in the template for the location and **every room variant** (five of them):
layout, the 10-second goal, a solve walkthrough for 4 players and for solo/duo with the
helper mechanics, the reset path, and hazard notes. Add a section for each of the four
puzzle types in plain language. The walkthroughs are also a design check: writing them
out step by step is how to catch a room that cannot actually be finished.

## 6. Build order

1. `PuzzleConfig`, constants, types, `Gate`, `PartFactory.Ramp`.
2. `LocationBuilder` (shell only), a one-room test definition.
3. `Interaction`, `PuzzleBase`, `PuzzleRegistry`, `Plate`, `Carry`.
4. `HoldTheDoor`, then `TimedSwitches`. Round and Expedition integration.
5. `LocationValidator`, `LocationService`. _(M6a ends here if split.)_
6. `PowerRouting`, `CarryAndPlace`.
7. Sinking Cargo Ship data; remove the test definition. Strings.
8. `LEVEL_DESIGN.md`, other docs. Review.

## 7. Engine assumptions (SV-6xx)

- A `WeldConstraint` between a character's root and an unanchored, massless,
  non-colliding part carries the part with the character without affecting movement.
- `Humanoid.WalkSpeed` set on the server takes effect for that player.
- A `ProximityPrompt` on a part welded to a moving character still works.
- `RequiresLineOfSight = false` lets a prompt be used through a thin wall or counter
  (needed for the hatch).
- Changing `ProximityPrompt.Enabled` and `ActionText` on the server replicates.
- `Random.new(seed)` gives the same sequence for the same seed on every server.
- A 28-degree ramp is walkable; an 8-stud doorway is comfortable; 18-stud walls cannot
  be jumped or climbed.
- Open-top rooms give a workable camera on phones.
- Tags added with `CollectionService:AddTag` on the server replicate to clients.
- End-to-end checks for M12: finish each of the five room variants with 1, 2, 3 and 4
  players; lose a player mid-room in each and still finish; try to pull the lever from
  the wrong side; try to carry a cell through the barrier; drop a crate off the edge of
  a room.

## 8. Docs to update

`LEVEL_DESIGN.md` (5.12), `ARCHITECTURE.md` (a "Locations and puzzles" section: data ->
builder -> puzzles; the interface; the interaction path; the scaling rule),
`DECISIONS.md`, `STUDIO_VERIFY.md`, `ROADMAP.md`.

## 9. Additions to the roadmap

- Puzzle variants per room.
- `Interaction`, `PuzzleBase`, `Plate`, `Carry`, `Gate`, `LocationService`.
- Objectives that change as a puzzle progresses.

## 10. Decisions to record (plain language)

- **Interactions use Roblox's built-in prompts, checked again by the server.**
- **Loose objects are frozen in place** (anchored) rather than physically simulated: no
  crates rolling into the water or getting stuck.
- **Puzzles scale to the players still active and only get easier**, with the reason.
- **Each of the four puzzles**: one or two sentences on how it forces teamwork and how
  it scales down.
- **Rooms have no ceilings.**
- **A location that fails validation is never used.**
- **Room variants** and why (replay value; all four puzzle types in a three-room location).

## 11. Acceptance and review focus

Roadmap acceptance:

- [ ] Each puzzle is data-driven and has a documented reset path.
- [ ] All puzzle state is server-side.
- [ ] `LEVEL_DESIGN.md` documents every room with a solve walkthrough.

Review focus:

1. **Finishability, by reasoning.** For every room variant and every team size 1-4, and
   for "a member is eliminated at the worst moment", trace that the puzzle can still be
   solved. Pay special attention to: the plate-holder being eliminated; a carrier being
   eliminated; the count dropping while switches are lit; the count dropping to 1 with
   the barrier on.
2. Every prompt handler goes through `Interaction.Bind` and `OnPlayerAction`. Search for
   `.Triggered:Connect` outside `Interaction`: there should be none in `Puzzles/`.
3. No puzzle logic reads the position of a carried object.
4. Walk speed is restored on every path that ends a carry (drop, place, return home,
   eliminated, left, puzzle destroyed, round destroyed).
5. Everything a puzzle creates is in its Maid, and the puzzle is in the round's Maid.
6. Search `src/client` for puzzle state or decisions: there must be none.
7. Run each of the five definitions through `Validate` by hand, including the travel
   arithmetic.
8. `LocationBuilder` and `PlaceholderLocation` return the same `BuiltLocation` fields,
   and `Round` works with either.
9. Scaling only ever eases: search for anywhere a helper is removed or a window shortened.
