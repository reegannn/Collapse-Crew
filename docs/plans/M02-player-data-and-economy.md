# M2 plan: Player data and economy

Read [`README.md`](README.md) and [`00-game-design.md`](00-game-design.md) first.

## 1. Outcome

A player's progress is saved when they leave and loaded when they return. Coins exist,
can only be changed by one server module, and show on the Roblox leaderboard. If
Roblox's storage is unavailable, the player still plays in "safe mode": nothing is
saved, they are told so clearly, and their real saved data is never overwritten.

## 2. Scope

**In:** `DataService`, the save-data template and migrations, the low-level store with
session locking, `EconomyService`, `LeaderstatsService`, `NoticeService` +
`NoticeController`, the `Strings` text table, `DataConfig`.

**Out (later milestones):** XP changes and levels (M7; M2 only stores the fields),
purchases and receipts logic (M7; M2 only stores the field), sending the profile to the
client (M7 `ProfileSyncService`; the leaderboard is enough for now), custom toast UI
(M9; M2 uses Roblox's built-in notification).

## 3. Design

### 3.1 What is stored

One DataStore key per player: `DataConfig.keyPrefix .. userId` in the store
`DataConfig.storeName`. The value is a **document** that wraps the profile:

```lua
{
    formatVersion = 1,                       -- shape of this wrapper
    lock = { sessionId = "...", lockedAt = 1731234567 },  -- absent when no server holds it
    data = { ...Types.PlayerData... },
}
```

### 3.2 Session lock (why and how)

**Problem:** if a player hops from server A to server B, B may load the profile before
A has finished saving. B's later save would then wipe out what A saved (lost progress),
or the same coins could be spent on both.

**Solution:** whoever loads the profile writes a `lock` naming its own server session.
Other servers refuse to load a profile that carries a fresh lock from someone else.
Saving refreshes the lock; the final save on leave removes it. A lock older than
`DataConfig.Lock.timeoutSeconds` is treated as abandoned (the server that held it
probably crashed) and may be taken over.

`sessionId` is one `HttpService:GenerateGUID(false)` generated when the server starts.
(`game.JobId` is empty in Studio, so it is not used.)

### 3.3 Statuses a player can be in

| Status | Meaning | Saved? |
|--------|---------|--------|
| `Loading` | Load in progress | - |
| `Loaded` | Real profile in memory, we hold the lock | Yes |
| `SafeMode` | Load failed; a fresh default profile is used in memory only | **Never** |
| `None` | No entry (not joined, or already left) | - |

Safe mode gives every other service a normal-looking profile to work with, so gameplay
code never needs a special case. Only `DataService` knows it will not be saved.

### 3.4 The acceptance rule, made structural

"No path writes to the DataStore without a successful prior load." Enforce it by
construction: **`ProfileStore.Save` is only ever called from one private function in
`DataService`, and that function returns immediately unless the player's status is
`Loaded`.** There is no other call site. The reviewer must be able to confirm this with
one search.

## 4. Files

| File | New/changed | Purpose |
|------|-------------|---------|
| `src/shared/Config/DataConfig.luau` | new | All data tunables |
| `src/shared/Config/EconomyConfig.luau` | changed | Add `Reasons`, `transactionLogSize` |
| `src/shared/Config/UIConfig.luau` | changed | Add `Notice` group |
| `src/shared/Strings.luau` | new | Text table and `Strings.Get` |
| `src/shared/Types/init.luau` | changed | `ProfileStatus`, `LoadResult`, `Transaction`; confirm `PlayerData` |
| `src/shared/Remotes/Definitions.luau` | changed | Add `Notice` |
| `src/server/Data/ProfileTemplate.luau` | new | Default profile + current schema version |
| `src/server/Data/Migrations.luau` | new | Upgrade older saves |
| `src/server/Data/ProfileStore.luau` | new | DataStore access with locking, retries, budget |
| `src/server/Services/DataService.luau` | new | Per-player profile lifecycle |
| `src/server/Services/EconomyService.luau` | new | Coins |
| `src/server/Services/LeaderstatsService.luau` | new | Leaderboard values |
| `src/server/Services/NoticeService.luau` | new | Send a notice to a player |
| `src/client/Controllers/NoticeController.luau` | new | Show notices |
| `src/server/Bootstrap.server.luau` | changed | `SERVICE_ORDER` |
| `src/client/Bootstrap.client.luau` | changed | `CONTROLLER_ORDER` |

`SERVICE_ORDER` after M2: `PlayerSessionService`, `DataService`, `EconomyService`,
`LeaderstatsService`, `NoticeService`.
`CONTROLLER_ORDER` after M2: `NoticeController`, `SessionController`.

## 5. Module specifications

### 5.1 `Config/DataConfig`

```lua
{
    storeName = "PlayerProfiles_v1",
    keyPrefix = "Player_",
    documentFormatVersion = 1,

    autosaveIntervalSeconds = 120,
    shutdownSaveTimeoutSeconds = 25,   -- Roblox allows 30s at shutdown; leave headroom
    saveQueuePollSeconds = 0.2,        -- how often a waiting save re-checks "is one running?"

    Budget = { pollSeconds = 1, maxWaitSeconds = 20 },
    Retry = { attempts = 4, baseDelaySeconds = 1, maxDelaySeconds = 8, backoffFactor = 2 },
    Lock = { timeoutSeconds = 300, retryAttempts = 6, retryDelaySeconds = 5 },

    maxStoredReceipts = 50,            -- used in M7
}
```

`Lock.timeoutSeconds` must stay comfortably larger than `autosaveIntervalSeconds` plus
the worst-case retry time, because each autosave is what keeps a live lock fresh.
State that relationship in a comment.

### 5.2 `Data/ProfileTemplate`

- `ProfileTemplate.CURRENT_VERSION = 1`
- `ProfileTemplate.New(): Types.PlayerData` returns a **fresh deep copy** each call (so
  two players never share a table), with `schemaVersion = CURRENT_VERSION` and
  `coins = EconomyConfig.Coins.startingAmount`.
- `ProfileTemplate.Defaults(): Types.PlayerData` returns the frozen template used by
  `Reconcile`.
- Fields: exactly the M1/M2 fields in `00-game-design.md` section 12. All list/dictionary
  fields start **empty** (required by `TableUtil.Reconcile`).

### 5.3 `Data/Migrations`

- `Migrations.Run(data: any): (boolean, string?)` mutates `data` in place.
  1. If `type(data.schemaVersion) ~= "number"`, fail with `"BadVersion"`.
  2. While `data.schemaVersion < CURRENT_VERSION`: look up `STEPS[data.schemaVersion]`
     (a function that upgrades from that version to the next). Missing step: fail with
     `"MissingMigration"`. Run it inside `pcall`; on error fail with `"MigrationError"`.
     Then set `data.schemaVersion += 1`.
  3. `TableUtil.Reconcile(data, ProfileTemplate.Defaults())` to add any new fields.
  4. Return `true`.
- `STEPS` is an empty table in v1, with a commented example showing how to write the
  first step. The function must exist and be exercised on every load (acceptance).
- A version **newer** than `CURRENT_VERSION` is never passed in: `ProfileStore` refuses
  it earlier (5.4), because it means a newer build of the game wrote the data and this
  build must not touch it.

### 5.4 `Data/ProfileStore`

Server only. The only module that touches `DataStoreService`.

```lua
ProfileStore.Init(): boolean                       -- gets the DataStore (pcall). false = unavailable
ProfileStore.Load(userId: number): Types.LoadResult
ProfileStore.Save(userId: number, data: Types.PlayerData, releaseLock: boolean): (boolean, string?)
```

`Types.LoadResult`:

```lua
{ status: "Loaded", data: PlayerData, isNew: boolean }
| { status: "Locked" }          -- another server holds a fresh lock
| { status: "Failed", reason: string }   -- store unavailable, call errored after retries,
                                         -- corrupt document, or newer schema version
```

**`Load` algorithm.** One `UpdateAsync` reads the document and takes the lock in the
same atomic step. Wrap the call in `Safe.Retry(DataConfig.Retry, ...)`, and wait for
request budget before each attempt (below).

Inside the transform function (it **must not yield** and may run more than once, so it
sets an `outcome` variable each time; the last run is the one that counts):

1. `stored == nil` -> new player. `outcome = Loaded, isNew = true` with
   `ProfileTemplate.New()`. Return a new document with our lock.
2. `stored` is not a table, or `stored.data` is not a table -> `outcome = Failed
   ("Corrupt")`. **Return nil** (this cancels the write; the stored value is untouched).
3. `stored.data.schemaVersion` is not a number, or is greater than `CURRENT_VERSION`
   -> `outcome = Failed("NewerVersion")`. Return nil.
4. `stored.lock` exists, its `sessionId` is not ours, and
   `now - lockedAt < Lock.timeoutSeconds` -> `outcome = Locked`. Return nil.
5. Run `Migrations.Run(stored.data)` (pure Luau, never yields, so it is safe here).
   If it fails -> `outcome = Failed(reason)`, log at Error level, return nil. A
   migration failure is a programming error that must never ship; refusing here means
   the saved data stays exactly as it was.
6. Otherwise set `stored.lock` to our lock, `outcome = Loaded, isNew = false`, return
   `stored`. (The migrated data is written back in the same step.)

Every "refuse" check happens **before** any write, so a refused load never leaves our
lock behind and never alters the saved data. Return the player's `userId` as the second
transform result (`return document, { userId }`) so the key is tagged for Roblox's
data-erasure tools.

`stored` is a fresh copy each time the transform runs, so changing it in place is safe.

**`Save` algorithm.** `UpdateAsync` again, with retries and budget wait:

- Snapshot first: `local snapshot = TableUtil.DeepCopy(data)` and set
  `snapshot.lastSeenAt = Time.Now()`, so retries always write the same consistent copy
  even if the live table changes while the call is in flight.
- In the transform: if `stored` is a table with a `lock` whose `sessionId` is **not**
  ours -> another server has taken this profile over. Set `lockLost = true` and
  **return nil** (never overwrite it). Otherwise return
  `{ formatVersion, lock = (not releaseLock) and ourLock or nil, data = snapshot }, { userId }`.
- Return `(true)`, or `(false, "LockLost")`, or `(false, <error text>)`.

**Budget wait** (private): loop while
`DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync) < 1`,
`task.wait(Budget.pollSeconds)`, giving up (and letting the call proceed) after
`Budget.maxWaitSeconds`.

**Clock for locks:** `Time.Now()` (server UTC seconds). Different servers' clocks may
differ by a few seconds; the 300-second timeout makes that irrelevant. Note it.

### 5.5 `Services/DataService`

```lua
DataService.Init()
DataService.Start()

DataService.GetStatus(player): Types.ProfileStatus       -- "Loading" | "Loaded" | "SafeMode" | "None"
DataService.IsReady(player): boolean                     -- Loaded or SafeMode
DataService.IsSafeMode(player): boolean
DataService.Read(player): Types.PlayerData?              -- the live table; callers must treat it as read-only
DataService.Update(player, reason: string, mutator: (data: Types.PlayerData) -> ()): boolean
DataService.SaveNow(player): (boolean, string?)          -- yields. (false, "SafeMode") in safe mode
DataService.WhenReady(player, callback: (player, data, isSafeMode) -> ())

DataService.ProfileReady    : Signal<Player, Types.PlayerData, boolean>   -- boolean = isSafeMode
DataService.ProfileChanged  : Signal<Player, string>                      -- string = reason
DataService.ProfileReleasing: Signal<Player>                              -- just before the final save
```

Private per-player record:

```lua
{ status, data, safeModeReason: string?, isSaving: boolean, isReleasing: boolean, finalSaveDone: boolean }
```

**Join** (`PlayerUtil.ObservePlayers` in `Start`, so players already present are
handled):

1. Record `{ status = "Loading" }`.
2. If `ProfileStore.Init()` failed at start-up -> safe mode, reason `"StoreUnavailable"`.
3. Otherwise loop up to `Lock.retryAttempts`: `ProfileStore.Load(userId)`.
   - `Loaded` -> break.
   - `Locked` -> if the player has left, stop; else `task.wait(Lock.retryDelaySeconds)`
     and try again. Still locked at the end -> safe mode, reason `"Locked"`.
   - `Failed` -> safe mode with that reason. **Do not retry here**: `Load` already
     retried the network call, and `Corrupt`/`NewerVersion` will not fix themselves.
4. **The player may have left during the wait.** If `player.Parent == nil`: if we
   loaded successfully, immediately `ProfileStore.Save(userId, data, true)` to release
   the lock; then drop the record and return.
5. `Loaded`: if `data.firstJoinAt == 0`, set it to `Time.Now()`. Set status, fire
   `ProfileReady(player, data, false)`.
6. Safe mode: `data = ProfileTemplate.New()`, set status, record the reason, log at
   Warn level, fire `ProfileReady(player, data, true)`. Telling the player is
   `NoticeService`'s job (5.8): it subscribes to `ProfileReady`. `DataService` never
   calls `NoticeService`, because `NoticeService` is below it in the load order.

**`Update(player, reason, mutator)`**: return false if not ready. Run
`mutator(record.data)` inside `pcall`; on error, log at Error level and return false
(the data may be half-changed; say so in the log). On success fire
`ProfileChanged(player, reason)` and return true. Document loudly: **the mutator must
not yield**.

**Saving** (one private function `saveProfile(player, record, release)`; the only caller
of `ProfileStore.Save`):

1. Return `(false, "SafeMode")` unless `record.status == "Loaded"`.
2. If a save is already running for this player, wait for it
   (`while record.isSaving do task.wait(saveQueuePollSeconds) end`), so saves for one
   player never overlap and the **final** save is always the last one written.
3. `record.isSaving = true`; call `ProfileStore.Save`; `record.isSaving = false`.
4. On `"LockLost"`: log at Error level, switch the record to `SafeMode` with reason
   `"LockLost"` (stop trying to save), and fire `ProfileChanged(player, "LockLost")`.

**Autosave** (one loop in `Start`): every `autosaveIntervalSeconds`, take a snapshot
list of players with status `Loaded` and save each in turn (`release = false`), with a
`task.wait(saveQueuePollSeconds)` between players to spread the calls out. Save every
loaded player each cycle **even if nothing changed**, because the save is what keeps the
lock fresh. Skip a player whose record has `isReleasing` set (their final save is
already under way).

**Leave** (`PlayerRemoving`):

1. No record, or status `Loading`: mark the record so step 4 of Join releases the lock;
   return.
2. Fire `ProfileReleasing(player)` (other services write their last values now, without
   yielding).
3. `record.isReleasing = true`; `saveProfile(player, record, true)`;
   `record.finalSaveDone = true`; remove the record.

**Shutdown** (`game:BindToClose`): for every record that is `Loaded` and not yet
`isReleasing`, start the same leave path in its own thread. Then wait until every
record has `finalSaveDone` or `shutdownSaveTimeoutSeconds` has passed. `PlayerRemoving`
also fires for each player at shutdown; the `isReleasing` flag guarantees the final save
runs exactly once per player.

**`WhenReady`**: call the callback now if ready; otherwise keep it in a per-player list
that is run when `ProfileReady` fires and cleared on leave. Same leak-proof pattern as
`PlayerSessionService.WhenClientReady` (store nothing for a player whose `Parent` is nil).

### 5.6 `Services/EconomyService`

```lua
EconomyService.GetCoins(player): number                      -- 0 if no profile
EconomyService.CanAfford(player, amount: number): boolean
EconomyService.AddCoins(player, amount: number, reason: string): (boolean, number | string)
EconomyService.SpendCoins(player, amount: number, reason: string): (boolean, number | string)
EconomyService.GetRecentTransactions(): { Types.Transaction }  -- newest last; for debugging

EconomyService.CoinsChanged: Signal<Player, number, number, string>   -- balance, delta, reason
```

Both `AddCoins` and `SpendCoins` return `(true, newBalance)` or `(false, reasonCode)`.

Validation, in order (each failure returns a code and logs at Warn level):

1. `amount` is a number, not NaN, not infinite, a whole number, `>= 1` and
   `<= EconomyConfig.Coins.maxPerTransaction` -> else `"BadAmount"`.
2. `reason` is a key of `EconomyConfig.Reasons` -> else `"BadReason"`. (Forcing every
   caller to use a listed reason is what makes the transaction log an audit trail.)
3. `DataService.IsReady(player)` -> else `"NoProfile"`.
4. Spend only: `balance >= amount` -> else `"NotEnoughCoins"`.

Then **one** `DataService.Update` call does the change (no yield between the check and
the change). Adding clamps the result to `Coins.maxBalance` and logs if it clamped.
After the update: append to the transaction log, log one Info line, fire `CoinsChanged`.

`EconomyConfig.Reasons` (a set, so later milestones only add keys):
`RunReward`, `DailyReward`, `MilestoneReward`, `TutorialReward`, `Purchase` (Robux coin
pack), `ShopPurchase`, `CampPurchase`, `AdminAdjust`.

**Transaction log:** an in-memory list capped at `EconomyConfig.transactionLogSize`
(200); when full, drop the oldest. Entry: `{ userId, delta, balance, reason, at }`.
It holds user ids only (no names), and is never sent to clients.

**Hook for M7 (leave a clearly marked extension point, do not build it):** the 2x Coins
game pass will multiply some `AddCoins` reasons. M7 adds
`EconomyService.SetMultiplierProvider(fn)`. In M2, just keep the "work out the final
amount" step in one small private function so M7 has one place to change.

**Rule for the whole codebase:** nothing but `EconomyService` assigns `data.coins`.

### 5.7 `Services/LeaderstatsService`

- On `DataService.ProfileReady` (and for players already ready at `Start`, via
  `WhenReady` over `Players:GetPlayers()`): create a `Folder` named exactly
  `leaderstats` under the player containing an `IntValue` named `Coins` set to the
  profile's coins. Set the value before parenting; parent the folder last. If the
  folder already exists (defensive), reuse it.
- On `EconomyService.CoinsChanged`: update the value.
- Nothing to clean up: the folder is destroyed with the player.
- There is no "earlier standalone leaderstats script" in this repo to remove; note in
  the review that the roadmap line "supersedes the earlier script" is satisfied by this
  being the only leaderstats code.

### 5.8 `Services/NoticeService` and `Controllers/NoticeController`

```lua
NoticeService.Send(player, key: string, params: { any }?)
```

- Waits for the client via `PlayerSessionService.WhenClientReady`, then
  `Remotes.FireClient("Notice", player, key, params)`.
- In `Start`, subscribes to `DataService.ProfileReady`: when `isSafeMode`, sends key
  `DataSafeMode`. (`NoticeService` is below `DataService` in the load order, so it is
  allowed to require it.)
- Keys are constants in `Shared/Constants/NoticeKeys.luau`
  (`DataSafeMode` for now); the text lives in `Strings` under
  `Notice.<Key>.Title` and `Notice.<Key>.Body`.

`NoticeController` (client): on `Notice`, look up the two strings (formatting the body
with `params` if given) and show them with Roblox's built-in notification:

```lua
StarterGui:SetCore("SendNotification", { Title = title, Text = body, Duration = seconds })
```

`SetCore` can fail if called before Roblox has registered it, so wrap it in `pcall` and
retry up to `UIConfig.Notice.setCoreRetryAttempts` times, `setCoreRetrySeconds` apart.
Expose `NoticeController.Show(title, body)` so other controllers can reuse it. M9
replaces the display with the custom toast but keeps this controller's interface.

`UIConfig.Notice = { durationSeconds = 6, setCoreRetryAttempts = 8, setCoreRetrySeconds = 0.5 }`.

### 5.9 `Shared/Strings`

```lua
Strings.Get(key: string, ...: any): string
Strings.Has(key: string): boolean
```

A frozen `EN` table of `key -> text`. `Get` returns the formatted text; for a missing
key it returns the key itself and warns once per key (same "report once" pattern as
`Flags`). Formatting uses `pcall(string.format, ...)` and falls back to the unformatted
text. Requires `Logger` only.

Initial keys:

| Key | Text |
|-----|------|
| `Notice.DataSafeMode.Title` | `Progress not saving` |
| `Notice.DataSafeMode.Body` | `We could not load your saved data, so this session will not be saved. Your earlier progress is safe. Try rejoining in a few minutes.` |

## 6. Types to add

```lua
export type ProfileStatus = "Loading" | "Loaded" | "SafeMode" | "None"
export type LoadResult = { status: "Loaded" | "Locked" | "Failed", data: PlayerData?, isNew: boolean?, reason: string? }
export type Transaction = { userId: number, delta: number, balance: number, reason: string, at: number }
```

`PlayerData` already matches the M2 field list; double-check it against the template
field by field.

## 7. Build order

1. `DataConfig`, `EconomyConfig`/`UIConfig` additions, `Types` additions, `Constants/NoticeKeys`.
2. `Strings`.
3. `ProfileTemplate`, `Migrations`, `ProfileStore`.
4. `DataService`.
5. `EconomyService`, `LeaderstatsService`.
6. `Notice` remote, `NoticeService`, `NoticeController`.
7. Bootstrap order lists. Docs. Review.

## 8. Engine assumptions (add `TODO(verify-in-studio)` + `STUDIO_VERIFY` rows, SV-2xx)

- `DataStoreService:GetDataStore` and `UpdateAsync` fail (throw) in Studio unless the
  place is published **and** "Enable Studio Access to API Services" is on; until then
  every player is in safe mode. Row for the owner: turn that setting on.
- `UpdateAsync`: returning `nil` from the transform cancels the write; the transform may
  be called more than once; returning `(value, { userId })` tags the key.
- `GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)` exists and
  returns the remaining budget.
- `game:BindToClose` callbacks may yield for up to about 30 seconds, including in Studio
  when a play test stops.
- `PlayerRemoving` fires for every player at shutdown, before or alongside
  `BindToClose`.
- A `Folder` named `leaderstats` containing an `IntValue` appears on the built-in
  leaderboard.
- `StarterGui:SetCore("SendNotification", ...)` and the need to retry it early.
- `HttpService:GenerateGUID(false)` works on the server without HTTP requests enabled.
- End-to-end checks to list for M12: leave and rejoin keeps coins; two quick rejoins do
  not lose coins; stopping the server saves; with API access off, the safe-mode notice
  appears and nothing is written.

## 9. Docs to update

- `ARCHITECTURE.md`: module map rows; remotes table (`Notice`); a short "Saving and
  loading" section (the document shape, the lock, the statuses, safe mode).
- `DECISIONS.md`: section 11 below.
- `STUDIO_VERIFY.md`: SV-2xx rows.
- `ROADMAP.md`: tick M2; add the additions below.

## 10. Additions to the roadmap (features not in the original brief)

- `Strings` text table (the brief asks for strings to be kept in a table; this is its home).
- `Notice` message + `NoticeService`/`NoticeController` (needed to deliver the "clear
  message" for safe mode).

## 11. Decisions to record (plain language)

- **Session lock written in-house** rather than using a library: what it protects
  against, the 5-minute timeout, and that M12 will reconsider a battle-tested library.
- **Safe mode instead of kicking the player** when data cannot be loaded, and that a
  safe-mode session earns nothing permanent.
- **Locked profile -> wait up to 30 seconds, then safe mode** (never steal a fresh lock).
- **Adding a field needs no migration; changing one does** (the migration rule).
- **Every coin change needs a listed reason.**
- **Known limitation:** if a server crashes without releasing a lock, that player is in
  safe mode on other servers for up to 5 minutes.

## 12. Acceptance and review focus

Roadmap acceptance:

- [ ] No path writes to the DataStore without a successful prior load.
- [ ] All coin changes go through `EconomyService`.
- [ ] A migration function exists even though v1 is the only version.

Review focus (give this list to the read-only reviewer):

1. Search for every call to `ProfileStore.Save` and every `UpdateAsync`. Confirm the
   only save path is `DataService`'s private save function and that it refuses unless
   status is `Loaded`.
2. Confirm nothing inside either `UpdateAsync` transform can yield (no `task.wait`, no
   service calls, no logging that could yield; `Logger` does not yield, but keep the
   transforms minimal anyway).
3. Walk these timelines by hand: leaves while loading; leaves while an autosave is in
   flight; server shuts down with 4 players; load returns `Locked` six times; DataStore
   throws on every call; `LockLost` during autosave.
4. Search for assignments to `.coins` outside `EconomyService` and `ProfileTemplate`.
5. Check `AddCoins`/`SpendCoins` with: 0, negative, 1.5, NaN, infinity, a string, a
   huge number, an unlisted reason, a player with no profile.
6. Per-player tables in `DataService`, and the `WhenReady` lists, are cleared on leave
   and never re-created afterwards.
7. The profile template contains only plain data (no Vector3, no mixed tables).
