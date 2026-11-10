# M3 plan: Lobby and teams

Read [`README.md`](README.md) and [`00-game-design.md`](00-game-design.md) first
(especially sections 2, 5, 6 and 15).

## 1. Outcome

Players spawn in a generated lobby. Standing on a launch pad joins that pad's team (up
to 4). A console on the pad lets each member mark themselves ready. When everyone is
ready a countdown runs, the team is moved into a private arena, and (for now) a
"Return to lobby" prompt in the arena brings them back. Teams of 1, 2, 3 and 4 all
work. Leaving, disconnecting and "no arena free" are handled.

There is no run yet: M4 adds the round on top of the seam this milestone creates.

## 2. Scope

**In:** lobby geometry and spawning; pads; team membership, ready state and countdown;
arena slot pool; moving a team to an arena and back; a placeholder location; team state
sent to clients; quick play, join and leave messages; the "followed a friend" invite.

**Out:** the round state machine (M4); hazards (M5); real locations (M6); Daily pad
(M8); any custom on-screen UI (M9; M3 uses world-space signs and built-in prompts).

## 3. Design

### 3.1 Four services, four jobs

| Service | Owns | Knows nothing about |
|---------|------|---------------------|
| `ArenaService` | The pool of arena slots: allocate, release | Teams, rounds, what is built in a slot |
| `TeamService` | Who is in which team, ready flags, the countdown | Pads' geometry, arenas |
| `LobbyService` | The lobby's physical side: geometry, spawning, pad zones, prompts, signs | Arenas, rounds |
| `ExpeditionService` | The logistics of a launch: get an arena, build the location, move players in and out | Rules of a run |

**The seam for M4:** `ExpeditionService` fires `ExpeditionStarted(teamId)` once a team
is standing in its arena, and offers `ExpeditionService.Return(teamId)`. In M3 a
temporary prompt calls `Return`. In M4 `RoundService` listens to `ExpeditionStarted`
and calls `Return` itself; the temporary prompt is deleted. Nothing else changes.

### 3.2 The placeholder location and the `BuiltLocation` shape

M4 and M5 need somewhere to run before real locations exist (M6). `PlaceholderLocation`
builds a start platform, a long ramp and an exit platform, and returns a
`Types.BuiltLocation`: the **one description of a built location that the rest of the
game uses** (spawn points, rooms with checkpoints, exit zone, spectator point, hazard
bounds, time limits). M6's `LocationBuilder` returns the same shape, so `RoundService`
never needs to know which builder made the location.

### 3.3 Membership is physical

One rule: **you are in a pad's team while you stand on the pad.** A server loop checks
positions with maths (`ZoneUtil`), not touch events. The exit zone is slightly larger
than the enter zone so a player standing on the edge does not flicker in and out.
`TeamJoin` / `TeamQuickPlay` / `TeamLeave` messages just move the player on or off a
pad; the loop then applies the same rule.

## 4. Files

| File | New/changed | Purpose |
|------|-------------|---------|
| `src/shared/Config/LobbyConfig.luau` | new | Lobby geometry, pads, launch, signs |
| `src/shared/Config/ArenaConfig.luau` | new | Slots, placeholder location, teleport |
| `src/shared/Config/FlagConfig.luau` | changed | `SoloPlayAllowed = true` |
| `src/shared/Constants/Tags.luau` | new | Tag names (`00-game-design.md` section 10) |
| `src/shared/Constants/Attributes.luau` | new | Attribute names |
| `src/shared/Constants/TeamModes.luau` | new | `Standard` (M8 adds `Daily`, M9 `Tutorial`) |
| `src/shared/Constants/NoticeKeys.luau` | changed | New keys (5.9) |
| `src/shared/Util/ZoneUtil.luau` | new | Point-in-box maths |
| `src/shared/Util/CharacterUtil.luau` | new | Safe access to a player's character |
| `src/shared/Types/init.luau` | changed | Final `TeamState`; `Zone`, `BuiltRoom`, `BuiltLocation`, `PadDefinition`, `ExpeditionSpec` |
| `src/shared/Strings.luau` | changed | New keys (5.9) |
| `src/shared/Remotes/Definitions.luau` | changed | 6 remotes (5.8) |
| `src/server/World/PartFactory.luau` | new | One place that creates parts with safe defaults |
| `src/server/World/Teleport.luau` | new | The only way to move a player |
| `src/server/World/LobbyBuilder.luau` | new | Builds the lobby from `LobbyConfig` |
| `src/server/World/PlaceholderLocation.luau` | new | Builds the stand-in location |
| `src/server/Services/ArenaService.luau` | new | |
| `src/server/Services/TeamService.luau` | new | |
| `src/server/Services/LobbyService.luau` | new | |
| `src/server/Services/ExpeditionService.luau` | new | |
| `src/client/Controllers/TeamController.luau` | new | Holds the latest team state |
| `src/client/Controllers/NoticeController.luau` | changed | Add `ShowWithAction` |
| Both Bootstraps | changed | Order lists |

`SERVICE_ORDER` after M3: `PlayerSessionService`, `DataService`, `EconomyService`,
`LeaderstatsService`, `NoticeService`, `ArenaService`, `TeamService`, `LobbyService`,
`ExpeditionService`.
`CONTROLLER_ORDER` after M3: `NoticeController`, `TeamController`, `SessionController`.

## 5. Module specifications

### 5.1 Config

```lua
-- LobbyConfig
{
    origin = Vector3.new(0, 100, 0),          -- centre of the lobby floor's top surface
    Platform = { size = Vector3.new(160, 4, 160), railHeight = 6, railThickness = 1 },
    Spawn = { centreOffset = Vector3.new(0, 0, -40), ringRadius = 10, pointCount = 8,
              heightOffset = 3, rootWaitSeconds = 10 },
    Pads = {                                   -- offsets from origin, on the floor
        { id = "Pad1", mode = "Standard", offset = Vector3.new(-54, 0, 55) },
        { id = "Pad2", mode = "Standard", offset = Vector3.new(-18, 0, 55) },
        { id = "Pad3", mode = "Standard", offset = Vector3.new(18, 0, 55) },
        { id = "Pad4", mode = "Standard", offset = Vector3.new(54, 0, 55) },
    },
    Pad = { size = Vector3.new(22, 1, 22), zoneHeight = 14, exitMarginStuds = 3,
            checkIntervalSeconds = 0.25, standSpacing = 6, fullNoticeCooldownSeconds = 5 },
    Console = { offset = Vector3.new(0, 0, 13), size = Vector3.new(4, 5, 2),
                promptDistance = 12 },
    Sign = { heightStuds = 12, sizeStuds = Vector2.new(16, 7), refreshSeconds = 1 },
    Launch = { countdownSeconds = 5, minPlayers = 1 },
}

-- ArenaConfig
{
    slotCount = 6,
    origin = Vector3.new(0, 100, 4000),
    slotSpacing = Vector3.new(2500, 0, 0),
    folderName = "Arenas",
    Teleport = { streamTimeoutSeconds = 5, heightOffset = 3 },
    Placeholder = {
        locationId = "Placeholder",
        startPlatformSize = Vector3.new(50, 2, 50),
        rampWidth = 20, rampRun = 120, rampThickness = 2,
        exitHeight = 60,
        exitPlatformSize = Vector3.new(30, 2, 30),
        exitZoneHeight = 12,
        spectatorOffset = Vector3.new(45, 12, 0),   -- from the exit platform centre
        hazardStartDepth = 10,                       -- hazard starts this far below the start floor
        hazardMargin = 40,                           -- how far the hazard slab extends past the geometry
        hazardBaseSeconds = 240,
        timeLimitSeconds = 300,
    },
}
```

### 5.2 Small shared helpers

**`Util/ZoneUtil`** (requires nothing):

```lua
ZoneUtil.Contains(zone: Types.Zone, position: Vector3): boolean
ZoneUtil.Expand(zone: Types.Zone, margin: Vector3): Types.Zone   -- returns a new, larger zone
```

`Contains`: `local p = zone.cframe:PointToObjectSpace(position)`, then
`math.abs(p.X) <= zone.size.X / 2` and the same for Y and Z.

**`Util/CharacterUtil`** (requires nothing). Every function tolerates a missing
character and returns `nil`/`false` instead of throwing:

```lua
CharacterUtil.GetRoot(player): BasePart?          -- HumanoidRootPart
CharacterUtil.GetHumanoid(player): Humanoid?
CharacterUtil.IsAlive(player): boolean            -- has root and humanoid.Health > 0
CharacterUtil.GetFeetY(player): number?           -- root Y minus (root half-height + humanoid.HipHeight)
```

**`World/PartFactory`**: `PartFactory.Block(properties): Part`. Defaults applied before
the caller's properties: `Anchored = true`, `CanCollide = true`, smooth top and bottom
surfaces, `Material = Enum.Material.SmoothPlastic`. Sets every property **before**
`Parent` (parent is applied last, and only if given). Also
`PartFactory.Tag(instance, tagName)` wrapping `CollectionService:AddTag`.

**`World/Teleport`**:

```lua
Teleport.ToCFrame(player, cframe: CFrame): boolean   -- may yield (streaming). false if it could not move them
```

Steps: get character, root and humanoid (return false if missing) -> if seated, unseat
-> if `workspace.StreamingEnabled`, `pcall` `player:RequestStreamAroundAsync(position,
ArenaConfig.Teleport.streamTimeoutSeconds)` -> **after that yield, re-check** the
player is still here and still has the same character -> `character:PivotTo(cframe +
Vector3.new(0, heightOffset, 0))` -> zero the root's linear and angular velocity.

### 5.3 `ArenaService`

```lua
export type Arena = { slotIndex: number, teamId: string, origin: CFrame, folder: Folder,
                      maid: Maid.Maid, isReleased: boolean }

ArenaService.Init()                       -- creates workspace.<folderName> and one empty Folder per slot
ArenaService.Start()
ArenaService.Allocate(teamId: string): Arena?    -- nil when every slot is in use
ArenaService.Release(arena: Arena)               -- safe to call twice
ArenaService.GetFreeCount(): number
ArenaService.ArenaReleased: Signal<number>       -- slotIndex
```

(`Arena` is an object that owns a Maid, not plain data, so its type is exported from
this module rather than from `Types`. Same for `Expedition`, and later `Round`,
`Hazard` and `Puzzle`.)

- Slot `i` (0-based) origin: `CFrame.new(ArenaConfig.origin + ArenaConfig.slotSpacing * i)`.
- `Allocate`: first free slot -> new `Maid`, set folder attribute `TeamId`, mark used.
- `Release`: if `isReleased`, return. Set it. `maid:Destroy()`. Then
  `folder:ClearAllChildren()` as a safety net, and **log at Warn level if anything was
  still there** (that would mean something was built without being given to the Maid).
  Clear the attribute, mark free, fire `ArenaReleased`.
- **Symmetry rule (acceptance):** everything built inside an arena is given to
  `arena.maid`. `Release` is the only way a slot becomes free.

### 5.4 `TeamService`

Pure state. Does not know where pads are.

```lua
TeamService.JoinPad(player, padId: string, mode: string): (boolean, string?)
TeamService.LeavePad(player)                          -- no-op unless Forming/Countdown
TeamService.SetReady(player, ready: boolean): boolean
TeamService.ToggleReady(player): boolean
TeamService.GetTeamIdOf(player): string?
TeamService.GetTeamOf(player): Types.TeamState?       -- a fresh snapshot each call
TeamService.GetTeam(teamId: string): Types.TeamState?
TeamService.GetMembers(teamId: string): { Player }    -- a copy, in join order
TeamService.GetOpenTeamIdOnPad(padId: string): string?
TeamService.BeginRun(teamId: string): boolean         -- Launching -> InRun
TeamService.Disband(teamId: string, reason: string)   -- any phase

TeamService.TeamChanged     : Signal<string>                  -- teamId
TeamService.LaunchRequested : Signal<string>                  -- teamId; phase is now Launching
TeamService.MemberRemoved   : Signal<string, Player, string>  -- teamId, player, reason
TeamService.TeamDisbanded   : Signal<string>                  -- teamId
```

Internal team record: `id` (`"T" .. counter`), `padId`, `mode`, `phase`, `members`
(list of `Player`), `ready` (`[Player] = boolean`), `leaderUserId`, `maxSize`,
`countdownEndsAt` (synced time, 0 when none), `countdownToken` (number).

Rules:

- **`JoinPad`** fails with `"AlreadyInTeam"` if the player has a team. If the pad has
  no open team, create one (`Forming`, this player is leader). If the open team is full
  -> `"PadFull"`. Otherwise append, `ready = false`, cancel any countdown.
- **`LeavePad`** removes the player if their team is `Forming`/`Countdown`: cancel
  countdown, fire `MemberRemoved(..., "LeftPad")`, reassign leader to `members[1]`, and
  if the team is now empty, delete it and fire `TeamDisbanded`. Then re-check whether a
  countdown should start (the remaining members may all be ready).
- **`SetReady`** only in `Forming`/`Countdown`. Un-readying cancels a countdown.
- **Countdown start condition** (checked after every change): phase is `Forming`, the
  team size is allowed (below), and every member is ready. Then phase = `Countdown`,
  `countdownEndsAt = Time.SyncedNow() + countdownSeconds`, `countdownToken += 1`, and
  `task.delay(countdownSeconds, ...)` whose callback **does nothing unless the team
  still exists, is still in `Countdown`, and its token is unchanged**.
- **Cancel** = `countdownToken += 1`, phase back to `Forming`, `countdownEndsAt = 0`.
- **Launch** (countdown callback): phase = `Launching`, forget the pad's link to this
  team (the pad is now free for a new team), fire `LaunchRequested`.
- **Allowed sizes, as explicit code paths (acceptance):** one function
  `isLaunchSizeAllowed(count)` with a branch per size: `1` -> `Flags.IsEnabled
  ("SoloPlayAllowed")`; `2`, `3`, `4` -> true; anything else -> false. Also compare
  with `LobbyConfig.Launch.minPlayers`.
- **Disconnect** (`Players.PlayerRemoving`): remove the player from their team in *any*
  phase with reason `"Disconnected"`, firing the same signals. An empty team is
  disbanded.
- **`Disband`**: fire `MemberRemoved(..., reason)` for each member, clear all records,
  fire `TeamDisbanded`.
- **Replication:** after every change, send each current member
  `TeamStateChanged(snapshot)`; send `TeamStateChanged(nil)` to a player who was just
  removed and is still in the server. Use `Remotes.FireClient` (it skips departed
  players).
- **`TeamSetReady` remote**: handler calls `SetReady(player, ready)`.

All team state lives in this module's local tables (acceptance: "all queue state lives
on the server").

### 5.5 `LobbyService`

```lua
LobbyService.Init()                                  -- builds the lobby (creates instances; does not yield)
LobbyService.Start()
LobbyService.GetSpawnCFrame(): CFrame                -- next point on the spawn ring (round-robin)
LobbyService.SendToLobby(player): boolean            -- teleport to a spawn point
LobbyService.SetSpawnOverride(player, provider: (() -> CFrame?)?)
LobbyService.GetPadStandCFrame(padId: string, index: number): CFrame?
LobbyService.GetPads(): { Types.PadDefinition }
```

**`World/LobbyBuilder.Build(parent): BuiltLobby`** creates, under one `Model` named
`Lobby` in `workspace`: the floor; four rails; and, for each entry in
`LobbyConfig.Pads`, a pad base part (tagged `CC_LobbyPad`, attributes `PadId`, `Mode`),
a console part carrying one `ProximityPrompt`, and a `BillboardGui` sign with a single
`TextLabel`. It returns the pad parts, prompts, sign labels, enter/exit zones and the
spawn ring CFrames so `LobbyService` holds direct references (no searching the tree).

`ProximityPrompt` settings (set in `PartFactory` or a small helper so M6 reuses them):
`RequiresLineOfSight = false`, `HoldDuration = 0`, `MaxActivationDistance =
Console.promptDistance`, `ActionText`/`ObjectText` from `Strings`.

**Spawning.** For every player (via `PlayerUtil.ObservePlayers`), keep a per-player
Maid (destroyed on `PlayerRemoving`) holding a `CharacterAdded` connection; also handle
a character that already exists. On each new character:

1. `character:WaitForChild("HumanoidRootPart", Spawn.rootWaitSeconds)`; give up if nil.
2. `task.defer` one step (see pitfalls), then confirm it is still the player's current
   character.
3. Destination = the player's spawn override (if set and it returns a CFrame), else
   `GetSpawnCFrame()`.
4. `Teleport.ToCFrame`.

`SetSpawnOverride` is how `ExpeditionService` (and later `RoundService`) make a
respawning player appear in their arena instead of the lobby, without `LobbyService`
knowing anything about arenas. Overrides are cleared on `PlayerRemoving`.

**Pad loop** (one loop, every `Pad.checkIntervalSeconds`). For each player:

- In a `Forming`/`Countdown` team: if they have no root, or the root is outside that
  pad's **exit** zone -> `TeamService.LeavePad(player)`.
- In no team: for each pad, if the root is inside the pad's **enter** zone ->
  `TeamService.JoinPad(player, pad.id, pad.mode)`. On `"PadFull"` send the `PadFull`
  notice at most once per `fullNoticeCooldownSeconds` per player. Stop at the first pad
  matched.
- In a `Launching`/`InRun` team: ignore.

**Ready prompt.** `prompt.Triggered` gives the player: if their team is the open team
on *this* pad, `TeamService.ToggleReady(player)`; otherwise ignore.

**Signs.** On `TeamService.TeamChanged`/`TeamDisbanded`, rewrite that pad's label; a
slow loop (`Sign.refreshSeconds`) rewrites labels only for pads whose team is in
`Countdown` (to show the seconds remaining). Text comes from `Strings`:
empty pad -> "Step on to join"; forming -> "Crew 2/4 - Ready 1/2"; countdown ->
"Launching in 3". The label shows each member's display name with a ready mark using
both a shape and a colour.

**Remote handlers** (connected at the top of `Start`):

- `TeamQuickPlay`: ignore if the player is in a team. Choose among `Standard` pads the
  open team with the most members that is not full (ties: lowest pad index); if none,
  the first pad with no open team; if every pad is full, send `PadFull`. Teleport the
  player to a free stand position on that pad.
- `TeamJoin(teamId)`: ignore unless that team exists, is `Forming`/`Countdown`, has
  room and the player has no team; then teleport onto its pad.
- `TeamLeave`: if in a `Forming`/`Countdown` team, `TeamService.LeavePad(player)` then
  `SendToLobby(player)`.

**Followed a friend.** On `PlayerSessionService.WhenClientReady(player)`: if
`player.FollowUserId ~= 0`, find that player; if they are in a `Forming`/`Countdown`
team with room, `Remotes.FireClient("TeamInvite", player, teamId, friend.DisplayName)`.

### 5.6 `PlaceholderLocation`

```lua
PlaceholderLocation.Build(arena: ArenaService.Arena, teamSize: number): Types.BuiltLocation
```

All positions below are local to the arena origin; convert with
`arena.origin:ToWorldSpace(CFrame.new(x, y, z))`. Build under one `Model` named
`Location`, parented to `arena.folder` last, and give the model to `arena.maid`.

- **Start platform**: top surface at `y = 0`, centred on `(0, 0, 0)`.
- **Ramp**: from the platform's `+Z` edge, rising `exitHeight` over `rampRun`. A single
  rotated block: `direction = Vector3.new(0, exitHeight, rampRun).Unit`, length
  `= math.sqrt(exitHeight^2 + rampRun^2)`, size `(rampWidth, rampThickness, length)`,
  CFrame `= CFrame.lookAt(mid, mid + direction) * CFrame.new(0, -rampThickness / 2, 0)`
  where `mid` is the midpoint of the ramp's top surface. Low side rails.
- **Exit platform**: top surface at `y = exitHeight`, at the top of the ramp.
- **Spectator ledge**: a small railed platform at `spectatorOffset` from the exit
  platform, not reachable on foot.
- Returns: 4 `spawnPoints` in a 2 x 2 grid on the start platform; one `BuiltRoom`
  (`index = 1`, `id = "Placeholder"`, `difficulty = 1`, checkpoint at the start
  platform centre, tagged marker part); `exitZone` (a box `exitZoneHeight` tall over
  the exit platform, with a tagged, invisible, non-colliding marker part);
  `spectatorPoint`; `hazardBounds` (`startY = -hazardStartDepth`, `endY = exitHeight -
  2`, centre and size covering all geometry plus `hazardMargin`; all in **world** space);
  `hazardBaseSeconds`; `timeLimitSeconds`.
- **Temporary for M3 only:** a `ProximityPrompt` on the exit platform, returned as
  `location.temporaryReturnPrompt`, labelled from `Strings`. Mark the code
  `-- TEMPORARY(M3): removed in M4 when RoundService takes over`.

### 5.7 `ExpeditionService`

```lua
export type Expedition = { teamId: string, arena: ArenaService.Arena,
                           location: Types.BuiltLocation, spec: Types.ExpeditionSpec }

ExpeditionService.GetExpedition(teamId: string): Expedition?
ExpeditionService.Return(teamId: string)              -- safe to call twice
ExpeditionService.ExpeditionStarted: Signal<string>   -- teamId
ExpeditionService.ExpeditionEnded  : Signal<string>
```

**On `TeamService.LaunchRequested(teamId)`:**

1. `ArenaService.Allocate(teamId)`. If nil: append `teamId` to a FIFO `waitingTeams`
   list, send the `ArenaQueue` notice to the members, stop.
2. Build the spec: `{ mode = team.mode, locationId = "Placeholder", hazardId =
   "RisingWater", seed = <random integer> }` (M6 and M8 fill this in properly).
3. `PlaceholderLocation.Build(arena, #members)` inside `pcall`. On failure: release the
   arena, `TeamService.Disband(teamId, "LaunchFailed")`, send the `LaunchFailed` notice,
   stop.
4. Store the expedition. For each member `i` (explicit for 1 to 4; the location
   guarantees 4 spawn points): first `LobbyService.SetSpawnOverride(member, ...)` to
   that member's spawn point, **then** `Teleport.ToCFrame`. (Override first, so a
   member who is mid-respawn still lands in the arena.) Teleports run one after another;
   each may yield, so re-check the team still exists afterwards.
5. `TeamService.BeginRun(teamId)`; fire `ExpeditionStarted(teamId)`.

**`Return(teamId)`:** look up the expedition; if none, return. **Remove it from the
table first** (this is what makes a second call harmless). For each member still in
the server: clear the spawn override, `LobbyService.SendToLobby`. Then
`ArenaService.Release(arena)`, `TeamService.Disband(teamId, "RunEnded")`, fire
`ExpeditionEnded`.

**Other subscriptions:**

- `ArenaService.ArenaReleased`: while there is a waiting team and a free slot, pop the
  first waiting team; skip it if it no longer exists or is not `Launching`; otherwise
  run the launch steps.
- `TeamService.TeamDisbanded(teamId)`: remove it from `waitingTeams`; if it has an
  expedition, `Return(teamId)` (everyone left mid-run).
- `TeamService.MemberRemoved(teamId, player, reason)`: clear that player's spawn
  override.
- M3 temporary: connect `location.temporaryReturnPrompt.Triggered` to
  `Return(teamId)`; give the connection to `arena.maid`.

**Rules for late join and drop-out (acceptance; also record as a decision):** nobody
joins a run in progress; a player who joins the server late, or rejoins after
disconnecting, starts in the lobby; a run continues with whoever remains; an empty
team's run is abandoned and its arena released.

### 5.8 Remotes to add

From `00-game-design.md` section 9: `TeamStateChanged`, `TeamInvite`, `TeamJoin`,
`TeamQuickPlay`, `TeamLeave`, `TeamSetReady`, with exactly the arguments and rate
limits listed there.

### 5.9 Types, strings, notices

```lua
export type Zone = { cframe: CFrame, size: Vector3 }
export type PadDefinition = { id: string, mode: string, offset: Vector3 }
export type TeamPhase = "Forming" | "Countdown" | "Launching" | "InRun"
export type TeamMember = { userId: number, displayName: string, isReady: boolean }
export type TeamState = { id: string, padId: string, mode: string, phase: TeamPhase,
    leaderUserId: number, members: { TeamMember }, maxSize: number, countdownEndsAt: number }
export type ExpeditionSpec = { mode: string, locationId: string, hazardId: string, seed: number }
export type BuiltRoom = { index: number, id: string, difficulty: number, checkpoint: CFrame, bounds: Zone }
export type HazardBounds = { center: Vector3, size: Vector3, startY: number, endY: number }
export type BuiltLocation = { locationId: string, model: Model, spawnPoints: { CFrame },
    rooms: { BuiltRoom }, exitZone: Zone, spectatorPoint: CFrame, hazardBounds: HazardBounds,
    hazardBaseSeconds: number, timeLimitSeconds: number, temporaryReturnPrompt: ProximityPrompt? }
```

`TeamState` replaces the M1 draft. It is sent over the network: note that it contains
only plain values (D-012).

Notice keys and strings (`Notice.<Key>.Title/Body`): `PadFull`, `ArenaQueue`,
`LaunchFailed`. Other strings: `Lobby.Pad.Standard.Title`, `Lobby.Pad.Empty`,
`Lobby.Pad.Crew` (format: count, max), `Lobby.Pad.Ready` (format: ready, total),
`Lobby.Pad.Launching` (format: seconds), `Lobby.Pad.Queued`, `Lobby.Ready.Action`,
`Lobby.Ready.Object`, `Lobby.Invite.Title`, `Lobby.Invite.Body` (format: name),
`Lobby.Invite.Join`, `Placeholder.Return.Action`.

### 5.10 Client

**`TeamController`**: `GetState(): Types.TeamState?`; signals `Changed(state?)` and
`InviteReceived(teamId, fromName)`. On `TeamInvite` it also calls
`NoticeController.ShowWithAction(title, body, buttonText, function()
Remotes.FireServer("TeamJoin", teamId) end)`.

**`NoticeController.ShowWithAction`**: the built-in notification supports one button
through a `BindableFunction` callback (`Button1 = text`, `Callback = bindable`). Create
the `BindableFunction`, set `OnInvoke`, and destroy it after the notification's
duration. M9 replaces this with a proper invite panel.

## 6. Build order

1. Config, Constants, Types, Strings, `ZoneUtil`, `CharacterUtil`.
2. `PartFactory`, `Teleport`.
3. `ArenaService`.
4. `TeamService` + `TeamSetReady` remote + `TeamStateChanged`.
5. `LobbyBuilder`, `LobbyService` (spawning, pad loop, prompt, signs, the three remotes, invite).
6. `PlaceholderLocation`, `ExpeditionService`.
7. `TeamController`, `NoticeController.ShowWithAction`. Bootstrap lists. Docs. Review.

## 7. Engine assumptions (SV-3xx)

- A character moved with `PivotTo` right after `CharacterAdded` stays moved (the defer
  step is enough); if not, M12 must adjust the wait.
- `Player:RequestStreamAroundAsync(position, timeout)` exists, yields, and is harmless
  when streaming is off.
- `ProximityPrompt.Triggered` fires on the server with the triggering player, for a
  prompt on an anchored part created by the server.
- `BillboardGui` created on the server and parented to a part shows for all players;
  text changes replicate.
- `Player.FollowUserId` is the user id of the friend the player followed in (0 if none).
- The built-in notification's `Button1` + `Callback` (a `BindableFunction`) works.
- The place file's default baseplate and spawn do not interfere (the lobby is at
  Y = 100 and every spawn is an explicit teleport). Owner check: remove the default
  `SpawnLocation` and baseplate from the place, or confirm they are harmless.
- Coordinates up to about 15,000 studs from the origin behave normally.
- The server's maximum player count (a Studio setting) is 16 or fewer, to match 6 arena
  slots and the camp plots added in M8.
- End-to-end checks for M12: teams of 1, 2, 3 and 4 launch; stepping off cancels a
  countdown; a 7th simultaneous team queues and launches when a slot frees; leaving
  mid-arena frees the slot when the last member goes; after a return, the slot folder
  is empty.

## 8. Docs to update

`ARCHITECTURE.md` (module map, remotes table, a "Lobby, teams and arenas" section with
the four-service split and the M4 seam), `DECISIONS.md`, `STUDIO_VERIFY.md`,
`ROADMAP.md`. Add the reserved-server note required by the roadmap (below).

## 9. Additions to the roadmap

- Physical launch pads with a ready console and a status sign (the brief asks for a
  party flow; this is the form it takes).
- Placeholder location and the `BuiltLocation` shape.
- `ExpeditionService` (logistics split out from team and round logic).
- `PartFactory`, `Teleport`, `ZoneUtil`, `CharacterUtil`, `Constants/`.

## 10. Decisions to record (plain language)

- **Pads instead of a menu** for forming teams: readable in seconds, needs no interface,
  familiar from other Roblox games, works on every device.
- **Membership by standing on the pad**, checked with maths rather than touch events.
- **Arenas on the same server, far apart** (v1), and the **design note for scaling to
  reserved servers** required by the roadmap: what would change (`ExpeditionService`
  would call `TeleportService` to a reserved server instead of `ArenaService`;
  `TeamService` and everything above it stay the same; profile session locks already
  handle the server hop), and why not now (cannot be tested in this phase; same-server
  is simpler and keeps friends visibly together). Link to roadmap R5.
- **No joining or rejoining a run in progress** in v1.
- **A full server queues launches** rather than refusing them.

## 11. Acceptance and review focus

Roadmap acceptance:

- [ ] Arena allocate/release is symmetric (no leaked instances).
- [ ] A team of 1 to 4 is handled by explicit code paths.
- [ ] All queue state lives on the server.

Review focus:

1. Every instance created for an arena is given to `arena.maid`. Search
   `PlaceholderLocation` and `ExpeditionService` for `Instance.new` / `PartFactory`
   calls and for `:Connect(` and confirm each is owned.
2. Walk these timelines: member leaves during the countdown; leader leaves; last member
   leaves during `Launching` while queued; a member disconnects during the teleport
   loop; `Return` called twice; `TeamDisbanded` arriving while `Return` is running.
3. The countdown callback cannot launch a team that was cancelled and re-started (token
   check), or one that no longer exists.
4. No service requires a service below it. In particular `TeamService` must not require
   `LobbyService`, `ArenaService` or `ExpeditionService`.
5. Every client-to-server handler re-checks state (in a team? right phase? room left?)
   and cannot be used to teleport into an arena or onto a pad in another phase.
6. Per-player tables (`TeamService`, `LobbyService` overrides, notice cooldowns,
   per-player Maids) are cleared on `PlayerRemoving`.
7. `Teleport.ToCFrame` re-checks the character after its yield.
8. Every `ProximityPrompt` and sign string comes from `Strings`; every tag and attribute
   name comes from `Constants`.
