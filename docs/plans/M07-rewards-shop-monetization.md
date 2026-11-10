# M7 plan: Rewards, shop and monetization

Read [`README.md`](README.md) and [`00-game-design.md`](00-game-design.md) first.

## 1. Outcome

Finishing a run pays properly: coins and XP worked out from how the team did, with
bonuses for speed, for teamwork and for a first clear. XP adds up to levels. Coins buy
cosmetics (trails, hats, death-splash effects, camp decor) which can be equipped. A
"2x Coins" game pass and Robux coin packs are wired in, safely, and stay switched off
until the owner creates them and pastes in their IDs.

Each player's own device is now sent a snapshot of their profile, ready for the
interface in M9.

## 2. Scope

**In:** `RewardService`, `ProgressionService`, `ProfileSyncService`, `CosmeticsService`,
`ShopService`, `MonetizationService`; the cosmetics catalogue; four config modules; the
Level leaderboard value; `ProfileController` on the client.

**Out:** shop and purchase screens (M9); camp decor being *displayed* (M8 builds
camps); death-splash effects being *played* (M9); Daily Expedition bonuses (M8 adds
them to the formula).

## 3. Design

### 3.1 The reward formula

For each player in a finished run (`RewardConfig` supplies every number):

```
if the run failed AND lasted less than minimumRunSeconds:  coins = 0, xp = 0   (stops quit-farming)

base        = Coins.perRoom x roomsCleared  +  (Coins.completion if success)
speed       = if success: round(Coins.speedBonusMax x clamp01((par - duration) / (par - gold)))   else 0
noOneLeft   = Coins.noOneCaughtBonus   if success and nobody was eliminated   else 0
teamSize    = floor((base + speed) x Coins.teamSizeBonusPercent[team size at start] / 100)
firstClear  = Coins.firstClearBonus    if success and this player never cleared this location   else 0

coins = base + speed + noOneLeft + teamSize + firstClear
xp    = Xp.perRoom x roomsCleared  +  (Xp.completion if success, else Xp.participation)
```

`par` and `gold` come from the location definition (`parSeconds`, `goldSeconds`). For
the placeholder location, which has none, use `par = timeLimitSeconds` and
`gold = timeLimitSeconds / 2`. If `par <= gold`, the speed bonus is 0 (never divide by
zero).

The 2x Coins pass is **not** part of this formula. It is applied inside
`EconomyService.AddCoins` (3.3), so it cannot be forgotten or applied twice.

The results screen needs a breakdown, so the result carries a `bonuses` list:
`Base`, `Speed`, `NoOneLeftBehind`, `TeamSize`, `FirstClear`, and `DoubleCoins` (the
extra amount the pass added).

### 3.2 Why every grant is safe to repeat

| Grant | Why it cannot be given twice |
|-------|------------------------------|
| Run reward | `RewardService` records each `roundId` it has paid and refuses a second call; and a round only reaches `Results` once (M4). |
| First-clear bonus | Decided by `firstClears[locationId]`, which is set in the same uninterrupted step that pays it. |
| Shop purchase | "Already owned" is checked, coins taken and ownership written with no pause in between. A double-click's second request finds the item owned. |
| Robux coin pack | Each Roblox receipt has a unique `PurchaseId`. Coins and the receipt record are written together; Roblox is only told "granted" after the save succeeds (3.4). |
| Game pass | Not a grant: ownership is asked from Roblox, and only changes a multiplier. |

Write these arguments into the module headers (M11 collects them).

### 3.3 The 2x Coins pass

`EconomyService` (M2) gains a pluggable multiplier so it never needs to know about
game passes:

```lua
EconomyService.SetMultiplierProvider(provider: (player: Player, reason: string) -> number)
EconomyService.GetMultiplier(player, reason): number     -- 1 when no provider; clamped to 1..EconomyConfig.Coins.maxMultiplier
EconomyService.AddCoins(player, amount, reason): (boolean, number | string, number?)
                                                         -- now also returns the amount actually granted
```

`AddCoins` multiplies `amount` by `GetMultiplier(player, reason)` (rounded down) before
granting. The provider is called inside `pcall`; on error the multiplier is 1.
`MonetizationService` registers the provider: it returns the pass's multiplier when the
player owns the pass **and** the reason is listed in the pass's config (`RunReward`
only), else 1. Bought coins, daily rewards and refunds are never multiplied.

### 3.4 Robux coin packs (`ProcessReceipt`)

Roblox calls `ProcessReceipt` when a purchase needs fulfilling, and **keeps calling it
(now or in a later session) until told `PurchaseGranted`**. So the handler must be safe
to run any number of times:

```
1. Monetization flag off, unknown product, or player not in this server  -> NotProcessedYet
2. Player's profile is not "Loaded" (loading, or safe mode)                -> NotProcessedYet
3. If receipts[PurchaseId] is not recorded yet:
       AddCoins(player, product.coins, "Purchase")       } no pause between
       record receipts[PurchaseId] = now; prune old ones } these two steps
4. SaveNow(player)                                       (this pauses)
5. Save succeeded -> PurchaseGranted.   Otherwise -> NotProcessedYet.
```

Trace the failure cases to see it is consistent: if the save fails, Roblox asks again
later; the receipt is already recorded in memory, so step 3 is skipped and only the
save is retried. If the server dies before any save, the coins **and** the receipt
record are both lost together, so the retry correctly grants again. There is no path
where the coins are saved without the receipt, or the receipt without the coins,
because they live in the same saved document.

Wrap the whole handler in `pcall`; any error returns `NotProcessedYet`.
`MarketplaceService.ProcessReceipt` is assigned in exactly one place in the codebase.

### 3.5 Nothing is random

Every purchase gives exactly what it says. There are no loot boxes or paid chances
(handoff section 4). Keep it that way; SV-006 stays open for the owner to confirm
policy before going live.

## 4. Files

| File | New/changed | Purpose |
|------|-------------|---------|
| `src/shared/Config/RewardConfig.luau` | new | The reward formula's numbers |
| `src/shared/Config/ProgressionConfig.luau` | new | Level curve, unlock levels |
| `src/shared/Config/ShopConfig.luau` | new | The pricing table |
| `src/shared/Config/MonetizationConfig.luau` | new | Pass and product IDs (all `0` = not configured) |
| `src/shared/Config/EconomyConfig.luau` | changed | `Coins.maxMultiplier`; new reasons if needed |
| `src/shared/Config/RoundConfig.luau` | changed | Remove `PlaceholderRewards` |
| `src/shared/Config/FlagConfig.luau` | changed | `ShopEnabled`, `MonetizationEnabled` |
| `src/shared/Constants/Slots.luau` | new | `Trail`, `Hat`, `DeathSplash`, `CampDecor` |
| `src/shared/Content/Cosmetics.luau` | new | The catalogue (12 items) |
| `src/shared/Types/init.luau` | changed | `CosmeticDefinition`, `ProfileSnapshot`, `RoundSummary`; `PlayerData.firstClears` |
| `src/shared/Remotes/Definitions.luau` | changed | `ProfileSnapshot`, `ShopPurchase`, `ShopEquip` |
| `src/shared/Strings.luau` | changed | Item names, bonus labels, shop reasons |
| `src/server/Data/ProfileTemplate.luau` | changed | `firstClears = {}` |
| `src/server/Services/EconomyService.luau` | changed | Multiplier provider (3.3) |
| `src/server/Services/ProgressionService.luau` | new | |
| `src/server/Services/LeaderstatsService.luau` | changed | Add `Level` |
| `src/server/Services/ProfileSyncService.luau` | new | |
| `src/server/Services/CosmeticsService.luau` | new | |
| `src/server/Services/ShopService.luau` | new | |
| `src/server/Services/MonetizationService.luau` | new | |
| `src/server/Services/RewardService.luau` | new | |
| `src/server/Round/States/Results.luau` (or wherever the `REPLACED(M7)` function is) | changed | Call `RewardService` |
| `src/client/Controllers/ProfileController.luau` | new | |
| Both Bootstraps | changed | Order lists (see `00-game-design.md` sections 6-7) |

## 5. Module specifications

### 5.1 Config

```lua
-- RewardConfig
{
    minimumRunSeconds = 20,
    Coins = { perRoom = 15, completion = 40, speedBonusMax = 40, noOneCaughtBonus = 15,
              firstClearBonus = 100, teamSizeBonusPercent = { 0, 10, 20, 30 } },
    Xp = { perRoom = 10, completion = 30, participation = 5 },
    maxRememberedRounds = 200,     -- how many paid round ids RewardService remembers
}

-- ProgressionConfig
{
    maxLevel = 50,
    Curve = { base = 100, perLevel = 50 },   -- XP to go from level L to L+1 = base + perLevel x (L - 1)
    maxXpPerGrant = 10000,
    Reasons = { RunReward = true, TutorialReward = true },
    Unlocks = { DailyExpedition = 2 },       -- feature -> level needed (read in M8)
}

-- ShopConfig
{
    Items = {
        Trail_Blue = { price = 150, requiredLevel = 1 },
        Trail_Sunset = { price = 400, requiredLevel = 3 },
        Trail_Gold = { price = 900, requiredLevel = 6 },
        Hat_Cone = { price = 200, requiredLevel = 1 },
        Hat_Crate = { price = 500, requiredLevel = 4 },
        Hat_Buoy = { price = 1200, requiredLevel = 8 },
        Splash_Bubbles = { price = 300, requiredLevel = 2 },
        Splash_Sparks = { price = 700, requiredLevel = 5 },
        Splash_Confetti = { price = 1500, requiredLevel = 10 },
        Decor_Lantern = { price = 250, requiredLevel = 2 },
        Decor_Anchor = { price = 600, requiredLevel = 5 },
        Decor_Flagpole = { price = 1400, requiredLevel = 9 },
    },
}

-- MonetizationConfig        (0 = "not created yet": the feature stays off for that entry)
{
    GamePasses = {
        DoubleCoins = { id = 0, multiplier = 2, reasons = { RunReward = true } },
    },
    Products = {
        CoinsSmall = { id = 0, coins = 500 },
        CoinsMedium = { id = 0, coins = 1500 },
        CoinsLarge = { id = 0, coins = 4000 },
    },
    ownershipRetry = { attempts = 3, baseDelaySeconds = 2, maxDelaySeconds = 8, backoffFactor = 2 },
}
```

`EconomyConfig.Coins.maxMultiplier = 4`. The owner creates the pass and products in the
Creator Dashboard and pastes the IDs here; **never invent an ID**.

### 5.2 `ProgressionService`

```lua
ProgressionService.AddXp(player, amount: number, reason: string): (boolean, number | string)   -- ok, new level or reason code
ProgressionService.GetXp(player): number
ProgressionService.GetLevel(player): number
ProgressionService.GetLevelProgress(player): (number, number)   -- XP into the current level, XP needed for the next
ProgressionService.IsUnlocked(player, feature: string): boolean
ProgressionService.XpToAdvance(level: number): number           -- pure
ProgressionService.LevelForXp(totalXp: number): number          -- pure; capped at maxLevel

ProgressionService.XpChanged   : Signal<Player, number, number>   -- total, delta
ProgressionService.LevelChanged: Signal<Player, number, number>   -- new level, old level
```

`xp` is the lifetime total. The level is always re-derived from it with `LevelForXp`
and stored alongside (so the client never has to work it out). `AddXp` validates like
`AddCoins` (whole number, 1 to `maxXpPerGrant`, a listed reason, a ready profile),
changes both fields in **one** `DataService.Update`, then fires the signals. Nothing
else in the codebase assigns `data.xp` or `data.level`. `LevelForXp` is a simple loop
subtracting `XpToAdvance(level)` until it cannot; note it is at most `maxLevel` steps.

### 5.3 `RewardService`

```lua
RewardService.GrantForRound(summary: Types.RoundSummary): { [number]: Types.RoundResults }   -- keyed by userId. Does not yield.
RewardService.RewardsGranted: Signal<Types.RoundSummary, { [number]: Types.RoundResults }>
```

`Types.RoundSummary`: `{ roundId, mode, locationId, success, failureReason,
durationSeconds, roomsCleared, roomCount, teamSize, anyoneEliminated, timeLimitSeconds,
members: { { player: Player, wasEliminated: boolean, caughtCount: number } } }`.

Steps: if `roundId` was already paid, log at Warn level and return an empty table.
Record it (a list capped at `maxRememberedRounds`, oldest dropped). For each member
still in the server with a ready profile: work out the formula (3.1); call
`EconomyService.AddCoins(player, coins, "RunReward")` and use the **granted** amount it
returns for `coinsEarned` (the `DoubleCoins` bonus line is `granted - coins`); call
`ProgressionService.AddXp`; then one `DataService.Update` to set
`firstClears[locationId]` (if this was a first clear) and the stats counters. Build the
`Types.RoundResults` and return them all.

Keep the arithmetic in a pure private function `computeRewards(summary, member,
hasClearedBefore, location)` that returns numbers and the bonus list and touches no
service, so it can be checked by reading. Mark `-- HOOK(M8)` where the Daily
Expedition's multipliers and first-clear-of-the-day bonus will be applied.

**Round integration:** replace the `REPLACED(M7)` placeholder: build the
`RoundSummary` from the round and call `RewardService.GrantForRound`. Delete
`RoundConfig.PlaceholderRewards`.

### 5.4 `ProfileSyncService` and `ProfileController`

`Types.ProfileSnapshot` (plain data): `{ coins, xp, level, xpIntoLevel, xpForNextLevel,
ownedCosmetics: { string } (a sorted list), equippedCosmetics: { [slot]: id },
campUpgrades: { [id]: level }, streak: { current, best, lastDailyRewardDay },
settings, tutorialCompleted, isSafeMode, coinMultiplier }`.

- Mark a player "dirty" on `DataService.ProfileReady` and `DataService.ProfileChanged`.
- Expose `ProfileSyncService.MarkDirty(player)` for changes that are not profile
  changes. `MonetizationService` calls it when pass ownership changes.
  (`ProfileSyncService` is above `MonetizationService` in the load order, so it must not
  require it; the call goes downward instead.)
- One loop, every `UIConfig.Profile.syncIntervalSeconds` (0.5): for each dirty player
  whose client is ready, build the snapshot and `Remotes.FireClient("ProfileSnapshot",
  ...)`. This coalesces bursts of changes into at most two messages a second.
- Clear the dirty entry on `PlayerRemoving`.

`ProfileController` (client): `GetSnapshot(): Types.ProfileSnapshot?`, signal
`Changed(snapshot)`. Nothing else.

### 5.5 `Content/Cosmetics` and `CosmeticsService`

```lua
export type CosmeticDefinition = { id: string, slot: string, nameKey: string, Visual: { [string]: any } }
```

Twelve items, three per slot, ids matching `ShopConfig.Items`. `Visual` per slot:

| Slot | `Visual` fields | Shown by |
|------|-----------------|----------|
| `Trail` | `color: Color3`, `lifetime: number`, `width: number` | `CosmeticsService` (a `Trail` between two attachments on the root part) |
| `Hat` | `shape: "Cone" | "Block" | "Ring"`, `color: Color3`, `size: Vector3` | `CosmeticsService` (a small part welded above the head) |
| `DeathSplash` | `effectId: string` | client effects in M9, via the player attribute `CC_DeathSplash` |
| `CampDecor` | `decorId: string` | `CampBuilder` in M8 |

Everything is built from plain parts and built-in effect objects. **No asset IDs**
(none exist yet); the art pass in M12 can swap these for real accessories.

`CosmeticsService`: `Apply(player)` removes any previous `CC_Trail` / `CC_Hat` from the
character and adds the equipped ones; sets the `CC_DeathSplash` attribute. Called on
every `CharacterAdded` (per-player Maid, plus the character that already exists), on
`DataService.ProfileReady`, and when `ShopService` reports a change through
`CosmeticsService.Refresh(player)` (`ShopService` is below it, so it calls down).

### 5.6 `ShopService`

```lua
ShopService.Purchase(player, itemId: string): (boolean, string?)
ShopService.Equip(player, slot: string, itemId: string?): (boolean, string?)   -- nil itemId = take it off
ShopService.Owns(player, itemId: string): boolean
ShopService.GrantItem(player, itemId: string): boolean     -- free grant (M8 milestone rewards); already owned = true
ShopService.ItemPurchased: Signal<Player, string, number>  -- itemId, price
ShopService.ItemEquipped : Signal<Player, string, string?> -- slot, itemId
```

`Purchase`, checked in this order, returning the code on failure: `ShopDisabled` (flag)
-> `NoProfile` -> `UnknownItem` (not in `Content.Cosmetics`) -> `NotForSale` (not in
`ShopConfig.Items`) -> `AlreadyOwned` -> `LevelTooLow` -> then
`EconomyService.SpendCoins(player, price, "ShopPurchase")` (its failure code, e.g.
`NotEnoughCoins`, is returned as is) -> `DataService.Update` sets
`ownedCosmetics[itemId] = true`. **No yield anywhere in this function.** If the final
update somehow fails, log at Error level and refund with `AddCoins(..., "AdminAdjust")`.

`Equip`: `UnknownSlot` -> for a non-nil item: `UnknownItem`, `WrongSlot` (the item's
slot differs), `NotOwned` -> update `equippedCosmetics[slot]` (or clear it) ->
`CosmeticsService.Refresh(player)`.

Remote handlers simply return these functions' results. In `Init`, cross-check the
catalogue against the price table and log an Error for any id present in one but not
the other.

### 5.7 `MonetizationService`

```lua
MonetizationService.HasPass(player, passKey: string): boolean
MonetizationService.GetProducts(): { { key: string, id: number, coins: number } }   -- configured ones only
MonetizationService.PassOwnershipChanged: Signal<Player, string, boolean>
MonetizationService.ProductPurchased    : Signal<Player, string, number>   -- product key, coins
```

- A pass or product with `id == 0` is "not configured": it is skipped everywhere, with
  one Info log at start-up listing what is not configured.
- `Start`: register the multiplier provider (3.3); assign `ProcessReceipt` (3.4);
  connect `MarketplaceService.PromptGamePassPurchaseFinished` (when `wasPurchased` and
  the id matches a configured pass: set ownership true, fire the signal, mark the
  profile dirty); observe players.
- For each joining player and each configured pass: in its own thread,
  `Safe.Retry(ownershipRetry, function() return MarketplaceService:UserOwnsGamePassAsync(
  player.UserId, id) end)`. On failure assume **not owned** (never give the bonus on a
  failed check) and log. Cache per player; clear on `PlayerRemoving`.
- If the flag `MonetizationEnabled` is off: no ownership checks, the provider returns 1,
  and `ProcessReceipt` answers `NotProcessedYet`.

### 5.8 Leaderboard

`LeaderstatsService` adds an `IntValue` named `Level`, set on `ProfileReady` and updated
on `ProgressionService.LevelChanged`.

## 6. Build order

1. Config, constants, types, template field, strings.
2. `ProgressionService`; `Level` on the leaderboard.
3. `EconomyService` multiplier; `RewardService`; round integration.
4. `Content/Cosmetics`, `CosmeticsService`, `ShopService` + its two remotes.
5. `MonetizationService`.
6. `ProfileSyncService` + `ProfileSnapshot` + `ProfileController`.
7. Bootstrap lists. Docs (including the economy balance notes). Review.

## 7. Engine assumptions (SV-7xx)

- `MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)` (yields; may throw).
- `MarketplaceService.PromptGamePassPurchaseFinished` fires **on the server** with
  `(player, gamePassId, wasPurchased)`.
- `MarketplaceService.ProcessReceipt` receives a table with `PlayerId`, `ProductId` and
  `PurchaseId`, must return `Enum.ProductPurchaseDecision.PurchaseGranted` or
  `.NotProcessedYet`, may yield, and is retried by Roblox until granted.
- A `Trail` with two `Attachment`s on the root part draws while the character moves.
- A small part welded to the character's `Head` follows it and does not affect movement.
- **Owner actions before these can be verified:** create the game pass and three
  developer products, paste their IDs into `MonetizationConfig`, and test with Studio's
  test purchases. SV-006 (paid random items policy) remains open.
- End-to-end checks for M12: a win pays more than a loss; a second clear pays no
  first-clear bonus; buying an item twice fails the second time and takes coins once;
  equipping an item you do not own fails; a coin pack bought in Studio's test mode pays
  exactly once, including when the server is stopped right after buying.

## 8. Docs to update

`ARCHITECTURE.md` (module map; remotes; an "Economy" section: who may change coins/XP,
the multiplier provider, the receipt flow), `DECISIONS.md` (below, **including the
economy balance notes the roadmap asks for**), `STUDIO_VERIFY.md`, `ROADMAP.md`.

## 9. Additions to the roadmap

- `ProfileSyncService` / `ProfileSnapshot` / `ProfileController`.
- `CosmeticsService` (showing trails and hats).
- A minimum run length before rewards.

## 10. Decisions to record (plain language)

- **Economy balance notes.** With these numbers a successful three-room run pays
  roughly 85 coins as base, up to 40 more for speed, 15 if nobody was lost, and up to
  30% more in a full team: about **100 to 180 coins**. A failed run pays 15 per room
  cleared. The first clear of a location adds 100. The cheapest cosmetic costs 150, so
  a new player can buy something after one or two runs; the dearest (1,500) takes
  roughly ten to fifteen good runs. State that these are first guesses to revisit with
  real data (M10/M12).
- **The pass doubles run rewards only**, and is applied in one place on the server.
- **Coin packs are only confirmed to Roblox after the save succeeds**, and why.
- **No paid randomness.**
- **Cosmetics are built from simple shapes for now** (no art assets exist yet).
- **A run must last 20 seconds to pay anything on a loss.**

## 11. Acceptance and review focus

Roadmap acceptance:

- [ ] Every grant path is idempotent and server-side.
- [ ] Receipts are recorded.
- [ ] Ownership is checked on the server before any equip.

Review focus:

1. For each row of the table in 3.2, find the code and confirm the argument holds. In
   particular, search `Purchase`, `Equip` and step 3 of the receipt handler for any
   call that can yield (`task.wait`, `SaveNow`, any `...Async`, `WaitForChild`).
2. Walk the receipt handler for: unknown product; player gone; safe mode; save fails
   then succeeds on the retry; the same receipt delivered twice at once.
3. `ProcessReceipt` is assigned exactly once in the codebase.
4. Search for assignments to `.xp`, `.level`, `.coins`, `.ownedCosmetics[`,
   `.equippedCosmetics[`, `.receipts[` and confirm each is in its one owning service.
5. Check the formula with: 0 rooms; a failed 5-second run; `par == gold`; a team size
   outside 1-4; a location with no definition; a player who left before `Results`.
6. A failed pass-ownership check never grants the multiplier; a provider error gives 1.
7. Every id is `0` in `MonetizationConfig`; no real-looking ID was invented.
8. The snapshot and every remote payload contain only plain data.
9. `ProfileSyncService` does not require anything below it in the load order.
