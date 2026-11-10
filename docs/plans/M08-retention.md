# M8 plan: Retention layer

Read [`README.md`](README.md) and [`00-game-design.md`](00-game-design.md) first.

## 1. Outcome

Players have reasons to come back tomorrow:

- A **Daily Expedition** pad: one location + hazard + modifier combination per day, the
  same for everyone, with a bonus for the first clear of the day.
- A **streak** that grows each day they play a run, and forgives one missed day.
- A **daily reward** to claim once per day, bigger the longer the streak.
- **Streak milestones** (3, 7, 14 days) that pay out automatically.
- A **camp** for each player in the lobby that visibly grows as they buy upgrades.

Everything works without a custom interface (a chest to claim from, a board to buy
from, signs that show state); M9 adds screens on top.

## 2. Scope

**In:** `DailyService`, `CampService`, `CampBuilder`, daily modifiers, camp upgrades,
the Daily pad, the daily chest, reward and round integration, `DailyController`.

**Out:** screens for any of this (M9); leaderboards (R1); seasonal events (R2); camp
perks or camps that earn coins while you are away (logged as ideas, not built).

## 3. Design

### 3.1 One clock

**Every date decision in the game is made on the server, in UTC, through `Util/Time`.**
No other file may call `os.time`, `os.date`, `DateTime` or `tick`. The reviewer checks
this with a search. The client is sent results and deadlines; it never decides what day
it is.

### 3.2 The Daily Expedition is a pure function of the day

```lua
local function computeExpedition(dayNumber, usableLocationIds, hazardIds, modifierIds): Types.DailyExpedition
    local random = Random.new(dayNumber * DailyConfig.seedMultiplier + DailyConfig.seedSalt)
    return {
        dayNumber = dayNumber,
        locationId = usableLocationIds[random:NextInteger(1, #usableLocationIds)],
        hazardId = hazardIds[random:NextInteger(1, #hazardIds)],
        modifierId = modifierIds[random:NextInteger(1, #modifierIds)],
        seed = dayNumber * 31 + 17,          -- the run seed: same puzzle variants for everyone today
    }
end
```

The three lists must be in a **stable order** (sorted ids), or two servers would
disagree. Because nothing but the day number goes in, every server in the world offers
the same Daily Expedition without talking to each other. Keep it a pure private
function so it can be checked by reading.

### 3.3 Streak rule (forgiving)

When a run "counts" (it succeeded, or it lasted at least `RewardConfig.minimumRunSeconds`):

```
today = Time.DayNumber()        last = streak.lastPlayedDay        gap = today - last

last == 0                      -> current = 1                                   (first ever)
gap <= 0                       -> nothing changes                               (already counted today, or a clock oddity)
gap == 1                       -> current += 1                                  (played yesterday)
2 <= gap <= 1 + graceDays      -> current += 1                                  (missed day forgiven: paused, not reset)
gap > 1 + graceDays            -> current = 1; milestonesClaimed = {}           (streak lost)

then: lastPlayedDay = today; best = max(best, current)
```

`graceDays` is `DailyConfig.Streak.graceDays` (1).

### 3.4 Edge cases, reasoned (the roadmap asks for this; copy the table into the docs)

| Situation | Result | Why |
|-----------|--------|-----|
| Plays at 23:59:59 UTC, then again at 00:00:01 | Streak +1 | The day number rose by one. Two calendar days, even if seconds apart. |
| Plays twice on the same day | No change the second time | `gap == 0` |
| Plays day N, skips N+1, plays N+2 | Streak +1 | `gap == 2`, within the grace |
| Skips two days | Streak resets to 1 | `gap == 3 > 1 + graceDays` |
| Server stays up across midnight | Correct | The day is read at the moment of each event, never cached for decisions |
| A run starts at 23:58 and ends at 00:03 | Counts for the new day | Streak uses the moment the run finishes |
| Daily Expedition run starts before midnight, ends after | Bonus counts for the day it **started** | The run carries the day number it was launched with |
| Claims the daily reward at 23:59 and 00:01 | Two rewards | Two different UTC days: allowed by design |
| Two claim requests arrive together | One reward | Check and write happen with no pause between (3.6) |
| Saved day is in the future (`gap < 0`) | Nothing changes | Never punish a player for a clock problem |
| Leap years, daylight saving | Irrelevant | Day numbers are 86,400-second UTC days |
| Player in safe mode | Works in memory, not saved | Same as everything else in safe mode |

### 3.5 Modifiers

Data in `Content/DailyModifiers.luau`. Each has every field (no optional fields, so the
code needs no "if missing" branches):

```lua
{ id = "SwiftTide",  nameKey = "...", descriptionKey = "...",
  hazardSpeedMultiplier = 1.15, timeLimitMultiplier = 1,    startDelayBonusSeconds = 0,  coinMultiplier = 1.25, xpMultiplier = 1 },
{ id = "ShortFuse",  hazardSpeedMultiplier = 1,    timeLimitMultiplier = 0.85, startDelayBonusSeconds = 0,  coinMultiplier = 1.2,  xpMultiplier = 1 },
{ id = "CalmStart",  hazardSpeedMultiplier = 1,    timeLimitMultiplier = 1,    startDelayBonusSeconds = 15, coinMultiplier = 1,    xpMultiplier = 1 },
{ id = "DoubleXp",   hazardSpeedMultiplier = 1,    timeLimitMultiplier = 1,    startDelayBonusSeconds = 0,  coinMultiplier = 1,    xpMultiplier = 2 },
{ id = "HighStakes", hazardSpeedMultiplier = 1.25, timeLimitMultiplier = 1,    startDelayBonusSeconds = 0,  coinMultiplier = 1.5,  xpMultiplier = 1 },
```

Where each field is applied:

| Field | Applied in |
|-------|-----------|
| `hazardSpeedMultiplier` | The hazard context's `getSpeedScale` (the `HOOK(M8/M10)` left in M5) |
| `startDelayBonusSeconds` | Added to the hazard's start delay when the round creates it |
| `timeLimitMultiplier` | `Running.Enter`, when the deadline is set |
| `coinMultiplier`, `xpMultiplier` | `RewardService`, on the formula's result, before granting (the `HOOK(M8)`) |

A Standard run has no modifier: treat that as all multipliers 1 and bonus 0.

### 3.6 Claims that cannot be repeated

| Claim | Guard |
|-------|-------|
| Daily reward | `streak.lastDailyRewardDay >= today` -> refuse. Otherwise set it to today and add coins, with no pause between. |
| Daily first clear | `daily.lastClearDay >= roundDayNumber` -> no bonus. Otherwise set it and return the bonus, in one step. |
| Streak milestone | `streak.milestonesClaimed[id]` -> skip. Otherwise set it, then pay. Cleared only when the streak resets. |
| Camp upgrade | Level is read, coins taken and the new level written with no pause between. |

## 4. Files

| File | New/changed | Purpose |
|------|-------------|---------|
| `src/shared/Config/DailyConfig.luau` | new | Seeds, reward, streak, milestones |
| `src/shared/Config/CampConfig.luau` | new | Plots, prices, board |
| `src/shared/Config/LobbyConfig.luau` | changed | `Pad4` mode `Daily`; daily chest position |
| `src/shared/Config/ShopConfig.luau` | changed | `Exclusive` set (items deliberately not for sale) |
| `src/shared/Config/FlagConfig.luau` | changed | `DailyExpeditionEnabled`, `CampEnabled` |
| `src/shared/Constants/TeamModes.luau` | changed | Add `Daily` |
| `src/shared/Content/DailyModifiers.luau` | new | |
| `src/shared/Content/CampUpgrades.luau` | new | |
| `src/shared/Content/Cosmetics.luau` | changed | One milestone-only item (`Hat_Captain`) |
| `src/shared/Types/init.luau` | changed | `DailyExpedition`, `DailyModifier`, `DailyState`, `CampUpgradeDefinition`; save-data fields; `ExpeditionSpec` and `RoundSummary` gain `modifierId`, `dayNumber` |
| `src/shared/Remotes/Definitions.luau` | changed | `DailyStateChanged`, `DailyClaim`, `CampPurchase` |
| `src/shared/Strings.luau` | changed | |
| `src/server/Data/ProfileTemplate.luau` | changed | `streak.milestonesClaimed = {}`, `daily = { lastClearDay = 0 }` |
| `src/server/World/CampBuilder.luau` | new | |
| `src/server/World/LobbyBuilder.luau` | changed | Daily chest; camp plot bases |
| `src/server/Services/DailyService.luau` | new | |
| `src/server/Services/CampService.luau` | new | |
| `src/server/Services/TeamService.luau` | changed | Join guards per mode |
| `src/server/Services/LobbyService.luau` | changed | Pad subtitle; chest prompt signal |
| `src/server/Services/ExpeditionService.luau` | changed | Daily spec |
| `src/server/Services/RewardService.luau` | changed | Fill `HOOK(M8)` |
| `src/server/Round/Round.luau`, `States/Running.luau` | changed | Apply modifier |
| `src/server/Hazards/RisingVolume.luau` | changed | `startDelayBonusSeconds` in the context |
| `src/client/Controllers/DailyController.luau` | new | |
| Both Bootstraps | changed | Order lists |

No migration is needed for the two new save fields: they are additions with defaults
(the rule in `00-game-design.md` section 12).

## 5. Module specifications

### 5.1 Config

```lua
-- DailyConfig
{
    seedMultiplier = 7919, seedSalt = 104729,
    dayCheckSeconds = 30,                 -- how often the server looks for a new UTC day
    firstClearBonusCoins = 75,
    Reward = { baseCoins = 25, perStreakDayCoins = 5, streakCap = 10 },   -- 25 + 5 per streak day, up to 75
    Streak = { graceDays = 1 },
    Milestones = {
        { id = "Streak3", days = 3, coins = 100, cosmeticId = "" },
        { id = "Streak7", days = 7, coins = 300, cosmeticId = "Hat_Captain" },
        { id = "Streak14", days = 14, coins = 600, cosmeticId = "" },
    },
    Chest = { offset = Vector3.new(0, 0, 30), promptDistance = 10 },      -- lobby-local
}

-- CampConfig
{
    plotCount = 16,
    plotSize = Vector3.new(18, 1, 18),
    edgeInsetStuds = 12,                  -- plots sit this far in from the lobby edge
    Prices = {                            -- index = the level being bought
        Tent = { 100, 300, 800 }, Campfire = { 75, 250, 600 }, Flag = { 150, 500 },
        Workbench = { 200, 700 }, Fence = { 120, 400 },
    },
    Board = { promptDistance = 8 },
}
```

Plot positions: 16 plots along the lobby's west, south (`-Z`) and east edges, none
overlapping a pad, the spawn ring or the chest, at least 2 studs apart. Generate the
list in one function from `plotCount`, `plotSize`, `edgeInsetStuds` and
`LobbyConfig.Platform.size`; the exact arrangement is _developer's choice_.

### 5.2 `DailyService`

```lua
DailyService.GetDayNumber(): number
DailyService.GetExpedition(): Types.DailyExpedition
DailyService.GetModifier(modifierId: string?): Types.DailyModifier     -- unknown or nil -> the neutral modifier
DailyService.IsUnlockedFor(player): boolean                            -- flag on AND level >= ProgressionConfig.Unlocks.DailyExpedition
DailyService.ClaimDailyReward(player): (boolean, { coins: number, streak: number } | string)
DailyService.RecordPlay(player)                                        -- applies 3.3 and pays any milestones
DailyService.ConsumeDailyClear(player, dayNumber: number): number      -- bonus coins to add (0 if already had it)
DailyService.GetStateFor(player): Types.DailyState

DailyService.DayChanged        : Signal<number>
DailyService.DailyRewardClaimed: Signal<Player, number, number>          -- coins, streak
DailyService.StreakChanged     : Signal<Player, number, number, string>  -- current, previous, "Advanced" | "Forgiven" | "Reset" | "Started"
DailyService.MilestoneReached  : Signal<Player, string>
```

- **Today's expedition** is cached with the day number it was computed for.
  `GetExpedition()` recomputes if `Time.DayNumber()` has moved on. The hazard list
  comes from `HazardConfig.Hazards` (sorted ids), minus lava when `LavaHazardEnabled`
  is off; the location list from `LocationService.GetUsableIds()`. If there is no
  usable location, the Daily Expedition is unavailable (`IsUnlockedFor` returns false).
- **Day-change loop:** `task.wait(math.min(dayCheckSeconds, Time.SecondsUntilNextDay() + 1))`;
  when the day number differs from the cached one: recompute, fire `DayChanged`, update
  the pad subtitle, push `DailyStateChanged` to every ready player.
- **`ClaimDailyReward`**: `NoProfile` -> `AlreadyClaimed` (3.6) -> work out the coins
  -> one `DataService.Update` sets `lastDailyRewardDay` -> `EconomyService.AddCoins(...,
  "DailyReward")`. If `AddCoins` fails, undo the day with another `Update` and return
  its reason. **No yield anywhere.** Fire the signal; push state.
- **`RecordPlay`**: one `DataService.Update` applies 3.3 and, inside the same mutator,
  marks every newly reached milestone as claimed and collects them in a local list.
  After the update, for each collected milestone: `AddCoins(..., "MilestoneReward")`,
  `ShopService.GrantItem` if `cosmeticId ~= ""`, a notice, and the signal. Push state.
- **`ConsumeDailyClear`**: one `Update`; returns `firstClearBonusCoins` or 0.
- **Remote** `DailyClaim`: returns `ClaimDailyReward(player)`.
- **Chest:** `LobbyService` exposes the chest's prompt as a signal
  (`LobbyService.ChestTriggered: Signal<Player>`); `DailyService` subscribes, calls
  `ClaimDailyReward` and sends a notice with the result (`DailyClaimed` with the coin
  amount, or `DailyAlreadyClaimed`).
- **State push:** on `PlayerSessionService.WhenClientReady` + `DataService.WhenReady`,
  and after any change above.

`Types.DailyState` (plain data): `{ dayNumber, resetsAt (unix seconds of the next UTC
midnight), expedition = { locationId, hazardId, modifierId }, isUnlocked,
rewardClaimedToday, nextRewardCoins, clearedToday, streak = { current, best } }`.
The client turns `resetsAt` into a countdown using `Time.SyncedNow()`.

### 5.3 The Daily pad

- `LobbyConfig.Pads[4].mode = "Daily"`. When `DailyExpeditionEnabled` is off,
  `LobbyBuilder` treats it as `Standard`.
- **Who may join:** `LobbyService`/`TeamService` are above `DailyService` and cannot ask
  it. So `TeamService` gains join guards:

  ```lua
  TeamService.SetJoinGuard(mode: string, guard: (player: Player) -> (boolean, string?))   -- string = notice key
  ```

  `JoinPad` calls the guard for the pad's mode (if one is set) before adding the
  player; on refusal it returns `(false, "Guarded")` and `LobbyService` shows the
  notice key the guard returned (rate-limited like `PadFull`). `DailyService.Start`
  registers the guard for `Daily`: unlocked -> true, else `(false, "DailyLocked")`.
- **Sign subtitle:** `LobbyService.SetPadSubtitle(padId, text)` adds a line under the
  pad title. `DailyService` sets it to the modifier's name at start and on `DayChanged`.
- **Building the run:** in `ExpeditionService`, when `team.mode == "Daily"`, the spec
  comes from `DailyService.GetExpedition()` (`locationId`, `hazardId`, `modifierId`,
  `seed`, `dayNumber`). If that location is somehow unusable now, fall back exactly as
  for a Standard run and clear the modifier.

### 5.4 Round and reward integration

- **The modifier travels in the spec as data.** `ExpeditionSpec` gains
  `modifier: Types.RunModifier` (the five numeric fields from 3.5) alongside
  `modifierId` and `dayNumber`. `ExpeditionService` fills it in when it builds the
  spec: `DailyService.GetModifier(id)` for a Daily run, the neutral modifier otherwise.
  The round then reads plain numbers and never needs to ask `DailyService` anything
  (M9 uses the same field for the tutorial's gentle settings).
- `Round.new`: `self.modifier = spec.modifier`. Hazard context:
  `getSpeedScale = function() return self.modifier.hazardSpeedMultiplier end` and
  `startDelayBonusSeconds = self.modifier.startDelayBonusSeconds` (add this field to
  `HazardContext`; `RisingVolume.Start` adds it to the definition's delay).
- `Running.Enter`: time limit x `modifier.timeLimitMultiplier`.
- `RoundSummary` gains `modifierId`, `dayNumber` and `modifier`.
- `RewardService` at `HOOK(M8)`, per player: multiply the formula's coins by
  `summary.modifier.coinMultiplier` and XP by `xpMultiplier` (round down; add a `DailyModifier` bonus
  line for the coin difference); if the run was `Daily` and succeeded, add
  `DailyService.ConsumeDailyClear(player, summary.dayNumber)` as a `DailyFirstClear`
  line; then, if the run counts, `DailyService.RecordPlay(player)`.

### 5.5 Camps

**`Content/CampUpgrades.luau`:** `{ id, nameKey, maxLevel }` for `Tent` (3), `Campfire`
(3), `Flag` (2), `Workbench` (2), `Fence` (2). `maxLevel` must equal the length of that
upgrade's price list; `CampService.Init` checks and logs any mismatch.

**`World/CampBuilder`:**

```lua
CampBuilder.Build(plotCFrame: CFrame, details: { ownerName: string, level: number,
    streak: number, upgrades: { [string]: number }, decorId: string? }): Model
```

Builds, from plain parts only: a base; each upgrade at its level (level 0 = absent;
higher levels are visibly bigger or more elaborate: a taller tent, a bigger fire with a
`PointLight`, a higher flag, a fence around the plot); the equipped `CampDecor`
cosmetic's shape; and a sign with the owner's display name, level and streak. This is
what "visibly grows with progress and purchases" means in practice. Pure construction,
no connections.

**`CampService`:**

```lua
CampService.Purchase(player, upgradeId: string): (boolean, string?)
CampService.GetPlotOf(player): CFrame?
CampService.UpgradePurchased: Signal<Player, string, number>   -- upgradeId, new level
```

- On `DataService.ProfileReady`: assign the first free plot (if none, log and skip:
  that player simply has no camp this session), build the camp, and build the plot's
  **upgrade board**: a small sign with one `ProximityPrompt` per upgrade, labelled with
  the upgrade's name and the price of its next level (or "MAX"). Only the plot's owner
  may use the prompts; check `player == owner` on the server.
- Rebuild the camp model (destroy the old one first) when something it shows changes.
  Subscribe to `DataService.ProfileChanged` and compare a small signature (upgrade
  levels, decor id, level, streak) with the last one built, so unrelated changes such
  as coins do not rebuild it.
- On `PlayerRemoving`: destroy the camp and board, free the plot. Each plot's contents
  are owned by a per-plot Maid.
- **`Purchase`**: `CampDisabled` -> `NoProfile` -> `UnknownUpgrade` -> `MaxLevel` ->
  `SpendCoins(player, price, "CampPurchase")` -> `DataService.Update` sets the new
  level. No yield. Then rebuild, refresh the board, fire the signal.
- Board prompt -> `Purchase`, then a notice with the result. Remote `CampPurchase` ->
  returns `Purchase`.
- When `CampEnabled` is off, do nothing at all.

### 5.6 Cosmetic for the 7-day milestone

Add `Hat_Captain` to `Content/Cosmetics` and list it in `ShopConfig.Exclusive` (a set
of ids that are deliberately not for sale). Update `ShopService.Init`'s cross-check to
accept ids in `Exclusive` as correctly unpriced. `ShopService.Purchase` already refuses
it (`NotForSale`).

### 5.7 `DailyController` (client)

`GetState(): Types.DailyState?`, signal `Changed(state)`. Nothing else.

## 6. Build order

1. Config, content, constants, types, template fields, strings, flags.
2. `DailyService`: expedition, day loop, state push, `DailyController`.
3. Streak, milestones, daily reward, chest.
4. Daily pad: join guard, subtitle, spec; round modifier; reward hook.
5. `CampBuilder`, `CampService`, board, remote.
6. Bootstrap lists. Docs. Review.

## 7. Engine assumptions (SV-8xx)

- `Random.new(seed)` with the same seed gives the same sequence on every server and
  platform.
- Server clocks agree closely enough that all servers switch day within a second or two
  of each other.
- Many `ProximityPrompt`s close together (five on a board) are individually selectable
  on touch, keyboard and gamepad. If not, M9 replaces the board with a panel.
- A `PointLight` inside a part lights its surroundings.
- End-to-end checks for M12: the Daily pad shows the same expedition on two servers;
  claiming twice pays once; a milestone pays once per streak; a camp upgrade bought
  twice quickly charges for two levels at most and never skips a level; leaving frees
  the plot. (Streak rules across real days are checked by reading 3.4 against the code,
  since waiting days is impractical; note this in `STUDIO_VERIFY.md`.)

## 8. Docs to update

`ARCHITECTURE.md` (module map; remotes; a "Daily systems" section with the one-clock
rule and the pure-function Daily Expedition), `DECISIONS.md`, `STUDIO_VERIFY.md`,
`ROADMAP.md` (tick M8; add the two ideas below to the ideas list), `LEVEL_DESIGN.md`
(a short "Daily modifiers" table).

## 9. Additions to the roadmap

- Daily chest and camp upgrade board (physical ways to claim and buy before M9).
- Join guards on `TeamService`.
- Milestone-only cosmetic.
- **Ideas list (not built):** camp perks (small coin bonuses); a camp that earns coins
  while the player is away, capped, to collect on return.

## 10. Decisions to record (plain language)

- **The Daily Expedition is worked out from the date alone**, so every server agrees
  without any shared storage.
- **The streak counts days you played a run**, not days you logged in, and **forgives
  one missed day**; with the reasoning (a streak that breaks too easily makes people
  give up; one that needs real play brings them into the game).
- **Milestones can be earned again** after a streak is lost.
- **Camps are for show in v1** (no gameplay advantage), and the two ideas that were
  left for later.
- **Everything is decided by the server's clock**, never the player's device.

## 11. Acceptance and review focus

Roadmap acceptance:

- [ ] All date logic uses UTC and a single `Time` module.
- [ ] Claim endpoints are idempotent.
- [ ] Nothing relies on client clocks.

Review focus:

1. Search the whole of `src/` for `os.time`, `os.date`, `os.clock`, `DateTime`, `tick(`
   and `time()`. Calendar decisions must only use `Util/Time`. (`os.clock` for measuring
   durations elsewhere is fine; anything that decides *what day it is* is not.)
2. Check the code against every row of the table in 3.4.
3. For each row of 3.6, find the check and the write and confirm nothing can yield
   between them.
4. `computeExpedition` uses only its arguments, and every list passed to it is sorted.
5. Search `src/client` for anything that decides a claim, a streak or the day.
6. Plots: assigned once, freed on leave, never double-assigned; a full lobby does not
   error. Camp models and boards are destroyed on leave.
7. Board prompts and the `CampPurchase` remote both check ownership/state on the server
   and both go through `CampService.Purchase`.
8. `TeamService` and `LobbyService` do not require `DailyService` (guards and subtitles
   are pushed down to them).
9. A Standard run is unaffected by modifiers (neutral values everywhere).
