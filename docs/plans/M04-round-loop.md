# M4 plan: Round loop

Read [`README.md`](README.md) and [`00-game-design.md`](00-game-design.md) first
(sections 3 and 4 are the rules this milestone implements).

## 1. Outcome

A team that launches now plays a complete run: a short briefing, a timed climb to the
exit, a win or a loss, a results payload with coins, and a clean return to the lobby.
There are no puzzles or hazard yet; the "placeholder objective" is simply to reach the
exit of the placeholder location before the clock runs out. Dying sends a player back
to the checkpoint.

## 2. Scope

**In:** the round state machine; the round tick; timer; checkpoints and respawn rules;
elimination and the spectator ledge; win and lose conditions; results payload with
placeholder coin rewards; round state and events sent to clients; cleanup. Removing the
M3 temporary return prompt.

**Out:** the hazard (M5: M4 leaves a clearly marked hook); puzzles and real rooms (M6);
the real reward formula and XP (M7: M4 uses fixed placeholder coins and reports
`xpEarned = 0`); any on-screen UI (M9).

## 3. Design

### 3.1 Structure

```
RoundService (service)          owns the list of rounds, the single tick loop, replication, public signals
  └─ Round (object, one per team in a run)     all state for one run; owns a Maid
       ├─ Transitions (data)                   THE table of allowed phase changes
       └─ States/<Phase> (one module each)     Enter(round, detail) / Tick(round, dt) / Exit(round)
```

Acceptance asks for "every state has an entry and exit function; all transitions are in
one table". Make both literally true: six state modules each exporting `Enter`, `Tick`
and `Exit` (an empty function where there is nothing to do), and one `Transitions`
module that is the only place a phase change is authorised.

### 3.2 Transitions

```lua
-- src/server/Round/Transitions.luau
return TableUtil.DeepFreeze({
    Lobby    = { Briefing = true },
    Briefing = { Running = true, Lobby = true },
    Running  = { Success = true, Failure = true, Lobby = true },
    Success  = { Results = true, Lobby = true },
    Failure  = { Results = true, Lobby = true },
    Results  = { Lobby = true },
})
```

`-> Lobby` from any phase is the **abandon** path (everyone left, or an internal error).
`Lobby` is both the starting state of a new `Round` object and its final,
cleaned-up state.

### 3.3 One rule for changing phase

`round:TransitionTo(nextPhase, detail?)`:

1. If `Transitions[round.phase][nextPhase]` is not true: log at Warn level, return false.
2. Call `States[current].Exit(round)` inside `xpcall`.
3. Set `round.phase`, `round.phaseEndsAt` (cleared to 0; `Enter` sets it if the phase is timed).
4. Call `States[next].Enter(round, detail)` inside `xpcall`.
5. Call the `onPhaseChanged` callback supplied by `RoundService` (which replicates state
   and fires public signals).

**`Enter` and `Exit` must never call `TransitionTo`.** Phase changes are requested only
from a state's `Tick` or from an outside event (a member leaving). This keeps
transitions from nesting.

## 4. Files

| File | New/changed | Purpose |
|------|-------------|---------|
| `src/shared/Config/RoundConfig.luau` | changed | Tick, phase lengths, respawn, placeholder rewards |
| `src/shared/Constants/RoundEvents.luau` | new | Event kinds for `RoundEvent` |
| `src/shared/Constants/FailureReasons.luau` | new | `TimeUp`, `AllCaught` |
| `src/shared/Constants/RunStatus.luau` | new | `Lobby`, `Active`, `Eliminated` |
| `src/shared/Types/init.luau` | changed | Final `RoundState`, `RoundResults`, `RoundMember`, `RoundInfo` |
| `src/shared/Remotes/Definitions.luau` | changed | `RoundStateChanged`, `RoundEvent`, `RoundResults` |
| `src/shared/Strings.luau` | changed | Objective and outcome text |
| `src/server/Round/Transitions.luau` | new | |
| `src/server/Round/Round.luau` | new | The round object |
| `src/server/Round/States/{Lobby,Briefing,Running,Success,Failure,Results}.luau` | new | |
| `src/server/Services/RoundService.luau` | new | |
| `src/client/Controllers/RoundController.luau` | new | Latest round state, events, results |
| `src/server/World/PlaceholderLocation.luau` | changed | Remove the temporary prompt |
| `src/server/Services/ExpeditionService.luau` | changed | Remove the temporary prompt wiring |
| Both Bootstraps | changed | Order lists |

`SERVICE_ORDER` adds `RoundService` after `ExpeditionService`.
`CONTROLLER_ORDER`: `NoticeController`, `TeamController`, `RoundController`, `SessionController`.

## 5. Module specifications

### 5.1 `RoundConfig`

```lua
{
    tickSeconds = 0.1,
    Phases = { briefingSeconds = 6, outcomeSeconds = 3, resultsSeconds = 12 },
    maxRunSeconds = 480,                 -- cap; a location's own limit is clamped to this
    Respawn = {
        protectionSeconds = 3,           -- after a respawn the player cannot be caught again for this long
        minHeadroomStuds = 1,            -- checkpoint must be at least this far above the hazard to be usable
    },
    fallOutMarginStuds = 60,             -- below the hazard's start height by this much = fell out of the world
    PlaceholderRewards = { coinsOnSuccess = 25, coinsOnFailure = 5 },   -- replaced by RewardConfig in M7
}
```

### 5.2 `Round` (object)

Exports `Round.new(expedition, members: { Player }, callbacks): Round` and the `Round`
type. `callbacks` are functions supplied by `RoundService` so that `Round` never
requires a service: `onPhaseChanged(round)`, `onStateChanged(round)` (something in the
snapshot changed), `onEvent(round, kind, data, onlyForPlayer?)`, `onFinished(round)`.

Fields:

| Field | Meaning |
|-------|---------|
| `id` | A GUID; identifies this run for rewards and analytics |
| `teamId`, `expedition`, `location`, `spec` | From `ExpeditionService` |
| `phase`, `phaseEndsAt` | Current phase; its deadline as `Time.SyncedNow()` (0 = untimed) |
| `runStartedAt`, `runSeconds` | `os.clock()` at `Running` start; duration fixed at `Running` exit |
| `roomIndex`, `roomsCleared` | Current room (1-based); rooms solved |
| `initialTeamSize` | Members at start |
| `members` | `[Player] = MemberState` |
| `memberOrder` | Players in join order (for stable listings) |
| `outcome` | `{ success: boolean, failureReason: string? }` once decided |
| `hazard` | `nil` in M4 (**M5 hook**) |
| `objectiveKey` | Strings key of the current objective |
| `resultsGranted` | Guard so rewards are granted once |
| `maid` | Owns everything the round creates |

`MemberState`: `{ player, status ("Active" | "Eliminated" | "Left"), protectedUntil
(os.clock), caughtCount, isRespawning }`.

Methods:

```lua
round:TransitionTo(phase, detail?): boolean
round:Tick(dt)                            -- delegates to States[phase].Tick
round:Abandon(reason: string)             -- TransitionTo("Lobby") from any phase
round:OnMemberLeft(player)
round:OnPlayerCaught(player, cause: string)   -- "Hazard" | "Died" | "Fell"
round:AdvanceRoom()                       -- M6 calls this when a room's puzzle is solved
round:GetActivePlayers(): { Player }
round:GetActiveCount(): number
round:IsPlayerProtected(player): boolean  -- not Active, or inside the protection window
round:GetHazardHeight(): number           -- M4: -math.huge. M5 replaces the body.
round:GetCurrentCheckpoint(): CFrame
round:GetSpawnCFrameFor(player): CFrame?  -- Active: checkpoint. Eliminated: spectator point.
round:GetSnapshot(): Types.RoundState
round:GetInfo(): Types.RoundInfo
round:Destroy()                           -- maid:Destroy()
```

**`OnPlayerCaught(player, cause)`** (this is the rule in `00-game-design.md` section 4):

1. Ignore unless phase is `Running`, the member is `Active`, not `isRespawning`, and
   `os.clock() >= protectedUntil`.
2. `caughtCount += 1`; event `PlayerCaught { userId, cause }`.
3. If `GetCurrentCheckpoint().Position.Y >= GetHazardHeight() + Respawn.minHeadroomStuds`
   -> **respawn**: set `isRespawning = true`. If the character is alive, in a new
   thread `Teleport.ToCFrame(player, checkpoint)` then finish; if it is dead, do nothing
   more now (the spawn override will place the new character). "Finish" (also called
   when a new character appears, see below): `protectedUntil = os.clock() +
   protectionSeconds`, `isRespawning = false`, add a `ForceField` instance to the
   character for `protectionSeconds` (a visible cue; destroy it with `task.delay`, and
   give it to the round Maid), event `PlayerRespawned { userId }`.
4. Otherwise -> **eliminate**: `status = "Eliminated"`, set the player attribute
   `CC_RunStatus`, event `PlayerEliminated { userId }`, `onStateChanged`, and (if alive)
   teleport to `location.spectatorPoint`.

**Deaths.** In `Round.new`, for each member connect `player.CharacterAdded` (and handle
the current character): connect that character's `Humanoid.Died` to
`OnPlayerCaught(player, "Died")`, and on a *new* character call the "finish respawn"
step if the member is `Active`. All connections go in the round Maid.

**Spawn override.** At creation, for every member:
`LobbyService.SetSpawnOverride(player, function() return round:GetSpawnCFrameFor(player) end)`.
`ExpeditionService.Return` clears it at the end (already implemented in M3).

**`OnMemberLeft(player)`**: mark `Left`, drop the entry, `onStateChanged`. If no members
remain at all -> `Abandon("Empty")`. (If members remain but none is `Active`, the next
`Running` tick ends the run as `AllCaught`.)

**`AdvanceRoom()`**: `roomsCleared += 1`; event `RoomCleared { roomIndex, seconds }`;
if `roomIndex < #location.rooms` then `roomIndex += 1`; `onStateChanged`. In M4 nothing
calls it (the placeholder has one room and no puzzle); it exists so M6 only has to call it.

### 5.3 States

| State | `Enter` | `Tick` | `Exit` |
|-------|---------|--------|--------|
| `Lobby` | **Final cleanup.** If the round has run: `round:Destroy()`, reset members' `CC_RunStatus`, call `onFinished`. (On the very first `Lobby`, before any other phase, do nothing.) | - | - |
| `Briefing` | `phaseEndsAt = now + briefingSeconds`; `objectiveKey = "Objective.Briefing"`; members `Active`, attribute set | At the deadline -> `Running` | - |
| `Running` | `runStartedAt`; `phaseEndsAt = now + min(location.timeLimitSeconds, maxRunSeconds)`; `objectiveKey = "Objective.ReachExit"`; bump `stats.runsStarted` for each member; **M5 hook: start hazard** | See below | Fix `runSeconds`; **M5 hook: stop hazard** |
| `Success` | Record `outcome`; `phaseEndsAt = now + outcomeSeconds`; event `Outcome { success = true }` | At the deadline -> `Results` | - |
| `Failure` | Same with `{ success = false, reason = detail }` | At the deadline -> `Results` | - |
| `Results` | Compute and grant results once (5.4); send `RoundResults` to each member; `phaseEndsAt = now + resultsSeconds` | At the deadline -> `Lobby` | - |

**`Running.Tick(round, dt)`**, in this order:

1. Deadline passed -> `TransitionTo("Failure", "TimeUp")`; return.
2. **M5 hook:** `if round.hazard then round.hazard:Update(dt) end`.
3. **M6 hook:** tick the active puzzle.
4. Fell out: any `Active` member whose root Y is below
   `location.hazardBounds.startY - fallOutMarginStuds` -> `OnPlayerCaught(player, "Fell")`.
5. Lose: `GetActiveCount() == 0` -> `TransitionTo("Failure", "AllCaught")`; return.
6. Win: every `Active` member has a root inside `location.exitZone`
   (`ZoneUtil.Contains`) -> `TransitionTo("Success")`.

Mark the two hooks with `-- HOOK(M5)` / `-- HOOK(M6)` comments so they are easy to find.

### 5.4 Results (M4 placeholder version)

In `Results.Enter`, guarded by `round.resultsGranted`:

For each member still in the server (including eliminated ones), build a
`Types.RoundResults`:

```lua
{ roundId, mode, locationId, success, failureReason, durationSeconds, roomsCleared,
  roomCount, teamSize = initialTeamSize, wasEliminated, caughtCount,
  coinsEarned, xpEarned = 0, bonuses = {} }
```

`coinsEarned` = `PlaceholderRewards.coinsOnSuccess` or `coinsOnFailure`; grant with
`EconomyService.AddCoins(player, amount, "RunReward")` and report what was actually
granted (0 if it failed). Update stats with one `DataService.Update` per player
(`runsCompleted` on success, `roomsCleared`). Store `round.resultsByUserId`.

**Why this cannot double-grant:** results are granted only inside `Results.Enter`;
`Results` can be entered at most once per round (the transition table has no path back
to it); and the `resultsGranted` flag guards even that. Write this argument into the
module header (M11 will collect such arguments).

Keep the reward calculation in **one private function** with a `-- REPLACED(M7)` marker:
M7 swaps it for `RewardService`.

### 5.5 `RoundService`

```lua
RoundService.Init()
RoundService.Start()
RoundService.GetPhaseOf(player): Types.RoundPhase      -- "Lobby" when not in a round
RoundService.IsActiveMember(player): boolean
RoundService.GetRoundInfoOf(player): Types.RoundInfo?
RoundService.AbandonTeam(teamId: string, reason: string)

RoundService.RoundStarted    : Signal<Types.RoundInfo>
RoundService.PhaseChanged    : Signal<Types.RoundInfo, Types.RoundPhase>
RoundService.RoomCleared     : Signal<Types.RoundInfo, number, number>     -- roomIndex, seconds in room
RoundService.PlayerCaught    : Signal<Types.RoundInfo, Player, string>     -- cause
RoundService.PlayerEliminated: Signal<Types.RoundInfo, Player>
RoundService.RoundFinished   : Signal<Types.RoundInfo, boolean, { [number]: Types.RoundResults }>  -- success, results by userId
```

(The signals exist for `AnalyticsService` in M10 and `TutorialService` in M9. Fire them
from the callbacks.)

- **`Start`**: subscribe to `ExpeditionService.ExpeditionStarted(teamId)` -> create a
  `Round` from the expedition and `TeamService.GetMembers(teamId)`, store it by
  `teamId`, index its members by `Player`, fire `RoundStarted`, then
  `round:TransitionTo("Briefing")`.
- Subscribe to `TeamService.MemberRemoved(teamId, player, reason)` -> if that team has
  a round: remove the player from the index and call `round:OnMemberLeft(player)`.
- Subscribe to `ExpeditionService.ExpeditionEnded(teamId)` -> if a round still exists
  for it (ended from outside), `round:Abandon("ExpeditionEnded")`.
- **`onFinished(round)`**: remove the round and its player index entries, then
  `ExpeditionService.Return(round.teamId)`.
- **Tick loop** (one thread for all rounds):

  ```lua
  while true do
      local dt = task.wait(RoundConfig.tickSeconds)
      for _, round in snapshotOfRounds do
          local ok, problem = xpcall(round.Tick, debug.traceback, round, dt)
          if not ok then log:Error(...); round:Abandon("TickError") end
      end
  end
  ```

  Iterate over a copy of the list, because a tick can finish a round.
- **Replication** (`onPhaseChanged` and `onStateChanged`): send
  `RoundStateChanged(round:GetSnapshot())` to every member still in the server. When a
  round finishes, send `RoundStateChanged(nil)`.
- **Events** (`onEvent`): `Remotes.FireClients("RoundEvent", members, kind, data)`, or
  to one player when `onlyForPlayer` is given.

### 5.6 Types, constants, remotes, strings

```lua
export type RoundPhase = "Lobby" | "Briefing" | "Running" | "Success" | "Failure" | "Results"
export type RoundMember = { userId: number, displayName: string, status: string }
export type RoundState = { roundId: string, teamId: string, phase: RoundPhase, mode: string,
    locationId: string, hazardId: string, roomIndex: number, roomCount: number,
    objectiveKey: string, phaseEndsAt: number, arenaSlot: number, members: { RoundMember } }
export type RoundInfo = { roundId: string, teamId: string, mode: string, locationId: string,
    hazardId: string, teamSize: number }
export type RoundBonus = { key: string, coins: number }
export type RoundResults = { roundId: string, mode: string, locationId: string, success: boolean,
    failureReason: string?, durationSeconds: number, roomsCleared: number, roomCount: number,
    teamSize: number, wasEliminated: boolean, caughtCount: number,
    coinsEarned: number, xpEarned: number, bonuses: { RoundBonus } }
```

These replace the M1 drafts. All are plain data (they are sent over the network).

`Constants/RoundEvents`: `RoomCleared`, `PlayerCaught`, `PlayerRespawned`,
`PlayerEliminated`, `Outcome`. Export both the named constants and a `List` array for
`Schema.Enum`.

Remotes: `RoundStateChanged`, `RoundEvent`, `RoundResults` as listed in
`00-game-design.md` section 9.

Strings: `Objective.Briefing` ("Get ready..."), `Objective.ReachExit`
("Reach the exit!"), `Outcome.Success`, `Outcome.Failure.TimeUp`,
`Outcome.Failure.AllCaught`.

### 5.7 `RoundController` (client)

`GetState(): Types.RoundState?`, `GetLastResults(): Types.RoundResults?`,
`GetArenaFolder(): Folder?` (looks up `workspace.<ArenaConfig.folderName>.Slot_<n>`
with `FindFirstChild`; may be nil); signals `StateChanged(state?)`,
`EventReceived(kind, data?)`, `ResultsReceived(results)`. It displays nothing (M9).

### 5.8 Removing the M3 temporary prompt

Delete the prompt from `PlaceholderLocation`, the `temporaryReturnPrompt` field from
`Types.BuiltLocation`, its wiring in `ExpeditionService`, and its string. Search for
`TEMPORARY(M3)` to confirm none remain.

## 6. Build order

1. Config, constants, types, remotes, strings.
2. `Transitions`, `Round` (without states' logic), state modules.
3. `RoundService` (creation, tick, replication, signals).
4. Results and placeholder rewards.
5. Remove the M3 temporary prompt.
6. `RoundController`. Bootstrap lists. Docs. Review.

## 7. Engine assumptions (SV-4xx)

- `Humanoid.Died` fires on the server for player characters, including a manual reset
  and falling below the world's destroy height.
- A `ForceField` instance parented to a character shows the protection effect (it does
  not need to block damage: the round's own `protectedUntil` is the real rule).
- `Player:SetAttribute` on the server replicates to all clients.
- A player respawning mid-run appears at the checkpoint (spawn override + M3's placement).
- End-to-end checks for M12: reach the exit (success); stand still until the clock
  ends (failure, `TimeUp`); reset during a run (back at the checkpoint, protected);
  one of two players leaves (run continues); the last player leaves (arena freed, no
  errors); results arrive once and coins change once.

## 8. Docs to update

`ARCHITECTURE.md` (a "Rounds" section: the structure diagram, the transition table,
the tick, the hooks for M5/M6/M7; module map; remotes), `DECISIONS.md`,
`STUDIO_VERIFY.md`, `ROADMAP.md` (tick M4; note that teammate revival stays in the
ideas list as R4).

## 9. Additions to the roadmap

- Spectator ledge for eliminated players.
- `RoundEvent` message (one channel for moment-to-moment events) and the
  `CC_RunStatus` player attribute.

## 10. Decisions to record (plain language)

- **Caught players respawn at the checkpoint while it is dry; once it floods they are
  out.** Why: keeps everyone playing while the team keeps pace, and makes falling
  behind the thing that costs you.
- **Win needs every active player in the exit at the same moment.** Why: it is a
  co-op game; nobody is left behind.
- **Eliminated players watch from a ledge** rather than returning to the lobby: they
  stay with their team and see the ending.
- **A fixed tick (10 times a second) instead of every frame**: plenty for a slow hazard,
  far cheaper.
- **XP is not granted until M7.**

## 11. Acceptance and review focus

Roadmap acceptance:

- [ ] Every state has an entry and exit function.
- [ ] All transitions are in one table.
- [ ] No round resource survives past `Results`.

Review focus:

1. Search for every assignment to `round.phase`: it must only happen inside
   `TransitionTo`. Search for `TransitionTo(` inside any `Enter`/`Exit`: there must be none.
2. Everything a round creates (connections, `ForceField`s, delayed tasks) is in
   `round.maid`, and `Lobby.Enter` destroys it. After a finished round, `RoundService`
   holds no reference to it (round list and player index both cleared).
3. Walk these timelines: caught while protected; caught twice in one tick; dies during
   `Briefing`; dies during `Results`; leaves while respawning; all leave during
   `Success`; a tick throws an error; `ExpeditionEnded` arrives from outside.
4. Results cannot be granted twice (read the argument in 5.4 against the code).
5. `RoundService` is the only module that calls `ExpeditionService.Return` for a round,
   and calls it exactly once per round (`Return` is also safe to call twice).
6. No `task.wait` inside `Tick`, `Enter` or `Exit` (the tick loop must never stall).
   Teleports, which yield, are always started in their own thread.
7. The snapshot sent to clients contains only plain data.
8. No `TEMPORARY(M3)` code remains.
