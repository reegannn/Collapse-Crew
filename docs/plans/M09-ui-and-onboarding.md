# M9 plan: UI/UX and onboarding

Read [`README.md`](README.md) and [`00-game-design.md`](00-game-design.md) first.

This milestone is very large. **Natural split point** if the owner agrees to two pull
requests: **M9a** = the UI framework, toasts, HUD, lobby panels, results screen,
settings and input (sections 5.1 to 5.8); **M9b** = shop screen, tutorial, effect hooks
(5.9 to 5.11). Ask before splitting.

## 1. Outcome

The game gets its on-screen interface, designed for phones first:

- **In a run:** a hazard progress bar, a countdown, the current objective, and each
  teammate's status.
- **In the lobby:** your coins and level, a party panel with a big Ready button, a
  Daily Expedition card with the streak and the daily reward, and buttons for the shop,
  settings and inviting friends.
- **After a run:** a results screen with the reward breakdown and "Play again".
- **A shop** to buy and equip cosmetics.
- **A first-run tutorial:** a new player is dropped into a 90-second guided room that
  teaches the core "hold the door" idea, and can skip it.

It works with touch, keyboard and gamepad, respects screen notches, never signals
anything by colour alone, and has a reduced-motion setting.

## 2. Scope

**In:** everything above; `SettingsService`; `TutorialService` and the tutorial
location; "play again"; sound and effect hook points with placeholder (silent) content.

**Out:** real sounds, music, particles and art (M12); analytics of UI use (M10);
localisation (R9; all text already goes through `Strings`).

## 3. Design

### 3.1 The one rule: screens are dumb

```
 state controllers ──> view controller ──(view model: a plain table)──> screen ──> pixels
 (TeamController,        (HudController,                                  │
  RoundController,        LobbyUiController ...)  <──(intent callback)────┘
  ProfileController,            │
  DailyController)              └──> Remotes (send the player's request to the server)
```

- A **screen** (`src/client/UI/Screens/`) only draws what it is given and reports taps.
  It must not require `Remotes`, any controller, or any `Config` that holds game rules.
  It never works out whether something is allowed.
- A **view controller** turns state into a **view model** (a plain table describing
  exactly what to show: text already looked up, booleans already decided) and handles
  the screen's intents by sending a request to the server.
- The **server** decides. A button being visible or enabled is a convenience, never a
  rule; every request is re-checked by the server as it already is.

This is how the acceptance criteria "all UI is built from small modules driven by data"
and "no UI module makes gameplay decisions" are met by construction.

### 3.2 Screen contract

```lua
Screen.new(parent: Instance, callbacks: { [string]: (...any) -> () }): Screen
screen:Update(viewModel)        -- redraw from scratch-safe data; cheap to call often
screen:SetVisible(isVisible: boolean)
screen:GetDefaultSelection(): GuiObject?     -- for gamepad focus
screen:Destroy()
```

### 3.3 Phones first

- **One root** `ScreenGui` per layer, created by `Components/Root`: `ResetOnSpawn =
  false`, safe-area insets on (so nothing sits under a notch or Roblox's own top bar),
  and a `UIScale` set from the screen's shorter side so everything grows and shrinks
  together.
- **Tap targets** are never smaller than `UIConfig.Touch.minTapTargetPixels` after scaling.
- **Keep the thumbs clear.** On touch devices Roblox puts the movement stick
  bottom-left and the jump button bottom-right. Nothing of ours goes there: the HUD
  lives along the top, panels on the right or centre.
- **Every button is a real `GuiButton` using `Activated`**, which fires for taps, clicks
  and gamepad presses alike. No per-device input code in screens.

### 3.4 Accessibility

- **Shape and colour together.** Every status has an icon shape as well as a colour:
  ready = tick, not ready = hollow circle, active = filled circle, eliminated = cross,
  hazard = wave or flame. The palette avoids red/green as the only difference.
- **Reduced motion** (a saved setting): no tweens (changes are instant), no screen
  shake or flashes.
- **Readable text:** sizes come from `UIConfig.Text`, never below `minSizePixels`; text
  over the 3D world gets an outline.

## 4. Files

| File | New/changed | Purpose |
|------|-------------|---------|
| `src/shared/Config/UIConfig.luau` | changed | Theme, sizes, HUD, toast, layout numbers |
| `src/shared/Config/TutorialConfig.luau` | new | Tutorial timings, gentle modifier, reward |
| `src/shared/Config/LobbyConfig.luau` | changed | Training pad; per-pad `maxSize` |
| `src/shared/Config/FlagConfig.luau` | changed | `TutorialEnabled` |
| `src/shared/Constants/SettingKeys.luau` | new | Toggle keys and volume keys |
| `src/shared/Constants/TeamModes.luau` | changed | Add `Tutorial` |
| `src/shared/Content/Effects.luau` | new | Effect id -> sound id (all empty for now) |
| `src/shared/Content/Locations/Tutorial.luau` | new | The one-room tutorial location |
| `src/shared/Types/init.luau` | changed | `LocationDefinition.category`; view-model types are local to each screen |
| `src/shared/Remotes/Definitions.luau` | changed | `RoundPlayAgain`, `SettingsSetToggle`, `SettingsSetVolume`, `TutorialSkip` |
| `src/shared/Strings.luau` | changed | All interface text |
| `src/client/UI/Theme.luau` | new | |
| `src/client/UI/Components/{Root,Panel,Label,Button,ProgressBar,Icon,Toast}.luau` | new | |
| `src/client/UI/Screens/{HudScreen,LobbyScreen,ResultsScreen,ShopScreen,SettingsScreen,TutorialScreen,ToastLayer}.luau` | new | |
| `src/client/Controllers/NoticeController.luau` | changed | Use `ToastLayer` instead of the built-in notification |
| `src/client/Controllers/{FxController,InputController,HudController,LobbyUiController,ResultsUiController,ShopUiController,SettingsUiController,TutorialUiController}.luau` | new | |
| `src/server/Services/SettingsService.luau` | new | |
| `src/server/Services/TutorialService.luau` | new | |
| `src/server/Services/TeamService.luau` | changed | `CreateDirectTeam`; per-pad max size |
| `src/server/Services/LobbyService.luau` | changed | Training pad; `PlaceOnFreePad` |
| `src/server/Services/LocationService.luau` | changed | Respect `category` |
| `src/server/Services/ExpeditionService.luau` | changed | Tutorial spec |
| `src/server/Services/RoundService.luau` | changed | Play again |
| `src/server/Services/RewardService.luau` | changed | Tutorial runs pay through `TutorialService`, not the formula |
| Both Bootstraps | changed | Order lists |

## 5. Module specifications

### 5.1 `UIConfig` and `Theme`

Extend `UIConfig` with groups (all numbers and colours live here, none in screens):
`Scale = { referenceShortSide = 720, min = 0.75, max = 1.5 }`; `Colors` (background,
panel, text, accent, good, warning, bad: chosen to stay distinguishable for the common
forms of colour blindness; note the choice in a comment); `Spacing`; `Corner`;
`Hud = { topMarginPixels, barSize, timerUpdateSeconds = 0.25 }`;
`Toast = { durationSeconds, maxVisible = 3 }`; `Profile.syncIntervalSeconds` (M7).

`UI/Theme` reads `UIConfig` and offers helpers: `Theme.Color(name)`,
`Theme.TextSize(kind)`, `Theme.IsReducedMotion()` / `Theme.SetReducedMotion(bool)`,
and `Theme.Tween(instance, goals, seconds)` which applies the change instantly when
reduced motion is on. **Every animation in the UI goes through `Theme.Tween`**, so the
setting works everywhere without each screen remembering it.

### 5.2 Components

Small builder functions that return instances. Each takes a properties table and
returns the instance (plus an `Update` function where useful).

| Component | Notes |
|-----------|-------|
| `Root.Create(name, displayOrder)` | The `ScreenGui` + `UIScale`. Parented to `PlayerGui`. Recomputes scale when the viewport size changes. |
| `Panel` | Rounded background frame with padding and an optional list layout |
| `Label` | Text with a theme size and optional outline |
| `Button` | Enforces the minimum tap size; `onActivated` callback; disabled look |
| `ProgressBar` | 0-1 fill, optional icon and text; fills through `Theme.Tween` |
| `Icon` | The status shapes, built from frames/text glyphs (no image assets exist) |
| `Toast` | One toast row, optionally with one action button |

### 5.3 Toasts and `NoticeController`

`ToastLayer` shows up to `Toast.maxVisible` stacked messages near the top, each for
`durationSeconds`. `NoticeController.Show` and `ShowWithAction` keep their signatures
(other controllers already call them) and now use `ToastLayer`. Delete the built-in
notification code and its retry settings.

### 5.4 HUD (`HudScreen`, `HudController`)

Visible only while `RoundController`'s state has phase `Briefing` or `Running`
(a compact version during `Success`/`Failure`).

View model: `{ phase, objectiveText, deadline (synced time, 0 = none), roomText ("Room
2 of 3"), hazard = { name, progress 0-1, iconShape }, teammates = { { name, statusShape,
statusColorName, isSelf } } }`.

- `objectiveText` = `Strings.Get(state.objectiveKey, unpack(state.objectiveParams))`.
- Hazard progress comes from the arena folder's `HazardProgress` attribute
  (`RoundController.GetArenaFolder()`; listen with `GetAttributeChangedSignal`;
  re-resolve the folder whenever the round state changes; tolerate it being nil).
- The countdown is drawn by the screen from `deadline - Time.SyncedNow()` on a slow
  timer (`Hud.timerUpdateSeconds`) that runs only while the HUD is visible. No
  per-frame work.
- `RoundEvent` kinds become toasts and effect calls here: `PlayerEliminated` ->
  "<name> was caught"; `RoomCleared` -> "Room cleared!"; `HazardWarning` -> a warning
  pulse on the bar (skipped under reduced motion).

### 5.5 Lobby (`LobbyScreen`, `LobbyUiController`)

Visible when the player is not in a run. Three regions:

1. **Profile strip** (top): coins, level, XP bar. From `ProfileController`.
2. **Party panel** (right). From `TeamController`:
   - Not in a team: "Stand on a launch pad to form a crew" + a **Quick Play** button
     (`TeamQuickPlay`).
   - In a team: member list with ready shapes, a large **Ready / Not ready** button
     (`TeamSetReady`), a **Leave** button (`TeamLeave`), and the countdown when running.
   - A pending invite shows a **Join** button (`TeamJoin`).
3. **Daily card** (left). From `DailyController`: today's location, hazard and modifier
   names; "Resets in H:MM:SS"; the streak; a **Claim** button
   (`Remotes.InvokeServer("DailyClaim")`, result shown as a toast) that is disabled
   when already claimed; a "Reach level N to unlock" line when locked.

Plus a button row: **Shop**, **Settings**, **Invite friends**
(`SocialService:PromptGameInvite(localPlayer)` inside `pcall`; hide the button if
`SocialService:CanSendGameInviteAsync` says no).

### 5.6 Results (`ResultsScreen`, `ResultsUiController`)

Shown on `RoundController.ResultsReceived`; hidden when the round state becomes nil.
View model from `Types.RoundResults`: headline (success, or the failure reason's
string), time (`Time.FormatClock`), rooms cleared, the `bonuses` list as labelled rows
(`Strings.Get("Results.Bonus." .. key)`), total coins and XP, and the level bar.
A **Play again** button sends `RoundPlayAgain` and then shows "Waiting for crew...".

**Server side of "play again"** (`RoundService`): handler for `RoundPlayAgain` records
the player in `round.playAgain` if the round is in `Results`. When the round finishes,
after `ExpeditionService.Return`, call `LobbyService.PlaceOnFreePad(players)` with
those who opted in and are still here. `PlaceOnFreePad` finds a `Standard` pad with no
open team and teleports them onto it (the pad loop then forms the team; nobody is
auto-readied); with no free pad it does nothing but send a notice.

### 5.7 Settings (`SettingsScreen`, `SettingsUiController`, `SettingsService`)

Settings: `reducedMotion` (toggle), `musicVolume`, `sfxVolume` (sliders 0-1, built from
a bar with minus/plus buttons so they work with touch and gamepad without dragging).

- Client applies a change immediately (`Theme.SetReducedMotion`; volumes onto two
  `SoundGroup`s owned by `FxController`) and sends `SettingsSetToggle(key, value)` or
  `SettingsSetVolume(key, value)`.
- `SettingsService` validates the key against `Constants/SettingKeys` (the schema's
  `Enum` already did; check again), clamps volumes to 0-1, and writes
  `data.settings[key]` with `DataService.Update`. It grants nothing.
- On each `ProfileController.Changed`, the client applies the saved values (so they
  load on join).

### 5.8 Input (`InputController`)

- Bind a few shortcuts with `ContextActionService`, each mirrored for keyboard and
  gamepad: open/close shop, open/close settings, toggle ready (only meaningful in a
  team). The bindings call the same functions the buttons call.
- Gamepad focus: when a panel opens and the last input was a gamepad
  (`UserInputService:GetLastInputType()`), set `GuiService.SelectedObject` to the
  screen's `GetDefaultSelection()`; clear it when the panel closes.
- Never bind keys Roblox uses for movement, jump or the menu.

### 5.9 Shop (`ShopScreen`, `ShopUiController`)

Tabs by slot. Each item card: name, price or "Owned" / "Equipped", a level lock line if
needed, and one button: **Buy** (`InvokeServer("ShopPurchase", id)`), **Equip** or
**Unequip** (`InvokeServer("ShopEquip", slot, id or nil)`). The view model is built
from `Content/Cosmetics` + `ShopConfig` + the profile snapshot. A failed request shows
`Strings.Get("Shop.Reason." .. code)` as a toast. The card's state is always redrawn
from the next `ProfileSnapshot`, never assumed from the button press.

A **Coins** tab lists configured coin packs and the 2x pass from
`MonetizationConfig` (entries with `id ~= 0` only; hide the whole tab if none). Buttons
call `MarketplaceService:PromptProductPurchase(localPlayer, id)` /
`PromptGamePassPurchase(localPlayer, id)` inside `pcall`. Roblox shows its own purchase
dialog; the server's `ProcessReceipt` does the granting. The screen states plainly what
each purchase gives. Nothing here is random.

### 5.10 Tutorial

**Server.**

- `TutorialConfig`: `{ locationId = "Tutorial", rewardCoins = 50, autoStartDelaySeconds
  = 2, Modifier = { hazardSpeedMultiplier = 0.35, timeLimitMultiplier = 1,
  startDelayBonusSeconds = 30, coinMultiplier = 0, xpMultiplier = 0 } }`.
- `Content/Locations/Tutorial.luau`: one room, `category = "Tutorial"`, a single
  `HoldTheDoor` puzzle with one plate and one crate spawn (so a solo player uses the
  crate), `timeLimitSeconds = 180`, a long `hazardBaseSeconds` (300). Sized so a new
  player finishes in well under 90 seconds: small room (40 x 18 x 44), the crate a few
  steps from the plate.
- `LocationDefinition.category`: `"Standard"` (default for existing content) or
  `"Tutorial"`. `LocationService.GetUsableIds()` and `PickStandard` return **Standard
  only**, so the tutorial never appears as a normal or daily run.
- `TeamService.CreateDirectTeam(players: { Player }, mode: string): string?` makes a
  team that skips the pad: created directly in `Launching` and announced with
  `LaunchRequested`. Refuses if any player is already in a team.
- `ExpeditionService`: for mode `Tutorial`, the spec is `{ locationId =
  TutorialConfig.locationId, hazardId = "RisingWater", modifier =
  TutorialConfig.Modifier, seed = 1 }`.
- `TutorialService`:
  - On `DataService.WhenReady` + `PlayerSessionService.WhenClientReady`: if
    `TutorialEnabled`, `data.tutorialCompleted` is false and the player is not in a
    team, wait `autoStartDelaySeconds`, re-check, then `CreateDirectTeam({ player },
    "Tutorial")`.
  - On `RoundService.RoundFinished` for a `Tutorial` run that **succeeded**: one
    `DataService.Update` sets `tutorialCompleted = true` and notes whether it was
    already true; if it was not, `EconomyService.AddCoins(player, rewardCoins,
    "TutorialReward")`. (The flag is what makes the reward one-time.)
  - `TutorialSkip` remote: if the player is in a `Tutorial` run,
    `RoundService.AbandonTeam(teamId, "TutorialSkipped")` and set
    `tutorialCompleted = true` (no reward).
  - A failed tutorial is not marked complete; the player lands in the lobby with a
    friendly notice and can retry from the Training pad.
- A **Training pad** in the lobby (`mode = "Tutorial"`, `maxSize = 1`) lets anyone
  replay it. `PadDefinition` gains an optional `maxSize`; `TeamService` uses it when
  creating a pad's team.
- `RewardService`: a `Tutorial` run's modifier has coin and XP multipliers of 0, so the
  formula pays nothing; also skip `DailyService.RecordPlay` and the stats counters for
  it. The 50 coins come only from `TutorialService`.

**Client.** `TutorialUiController` is active while the round's `mode` is `Tutorial`:
`TutorialScreen` shows the objective as a large caption with step dots, a **Skip**
button (`TutorialSkip`), and world markers: a bouncing arrow (`BillboardGui`, static
under reduced motion) over whatever the current objective points at, found by tag
(`CC_Carriable`, `CC_Plate`, `CC_Lever`) inside the player's arena folder. Which tag
goes with which objective key is a small table in the controller.

### 5.11 Effect hooks (`FxController`, `Content/Effects`)

```lua
FxController.Play(effectId: string, options: { position: Vector3?, volume: number? }?)
```

`Content/Effects` maps effect ids to `{ soundId = "", group = "Sfx" }`. **Every
`soundId` is an empty string for now**: `Play` does nothing when the id is empty, so
the hook points exist and M12 only has to fill in ids. Effect ids to define and call:
`UiClick`, `Toast`, `Countdown`, `Launch`, `RoomCleared`, `GateOpen`, `PlateDown`,
`SwitchOn`, `ValveTurn`, `ValveSlip`, `CellPlaced`, `CargoBlocked`, `HazardWarning`,
`Caught`, `Eliminated`, `Win`, `Lose`, `Purchase`, `LevelUp`, and one per
`DeathSplash` cosmetic.

`FxController` also owns two `SoundGroup`s (`Music`, `Sfx`) whose volumes follow the
settings, and listens for world changes by tag to add purely cosmetic motion: when a
`CC_Gate`'s `Open` attribute becomes true, slide it down with `Theme.Tween` (the
server already made it passable; this is only how it looks). Client code must tolerate
tagged objects appearing and disappearing (streaming): use
`CollectionService:GetInstanceAddedSignal` / `GetInstanceRemovedSignal`.

## 6. Build order

1. `UIConfig`, `Theme`, components, `Root`.
2. `ToastLayer` + `NoticeController` switch-over.
3. `HudScreen` + `HudController`.
4. `LobbyScreen` + `LobbyUiController`.
5. `ResultsScreen` + `ResultsUiController` + server "play again".
6. `SettingsScreen` + `SettingsUiController` + `SettingsService`; `InputController`.
   _(M9a ends here if split.)_
7. `ShopScreen` + `ShopUiController`.
8. Tutorial: config, location, `category`, `CreateDirectTeam`, `TutorialService`,
   Training pad, `TutorialScreen` + `TutorialUiController`.
9. `Content/Effects`, `FxController`, hook calls.
10. Bootstrap lists. Docs. Review.

## 7. Engine assumptions (SV-9xx)

- `ScreenGui.ScreenInsets` (safe-area handling) exists with the expected enum values;
  otherwise fall back to `IgnoreGuiInset` plus manual padding from
  `GuiService:GetGuiInset()`.
- `UIScale` scales a whole `ScreenGui`'s contents; `Camera.ViewportSize` changes fire
  when a phone rotates.
- `GuiButton.Activated` fires for touch, mouse and gamepad.
- `GuiService.SelectedObject` moves gamepad focus; `UserInputService:GetLastInputType()`.
- `ContextActionService:BindAction` with both a key and a gamepad button.
- `SocialService:PromptGameInvite` and `CanSendGameInviteAsync`.
- `MarketplaceService:PromptProductPurchase` / `PromptGamePassPurchase` may be called
  from a client script.
- `SoundGroup.Volume` controls every `Sound` assigned to the group.
- `CollectionService:GetInstanceAddedSignal` fires on the client as tagged parts stream in.
- A `BillboardGui` created on the client and adorned to a server part displays.
- **Checks on a real phone (M12):** nothing overlaps the movement stick or jump button;
  every button is comfortable to tap; text is readable; the notch is clear; rotating
  the phone re-lays-out; a full run is playable with touch only, keyboard only and
  gamepad only.
- Tutorial checks: a brand-new profile is taken into the tutorial; it can be finished in
  under 90 seconds; Skip works; it never runs twice; the reward is paid once.

## 8. Docs to update

`ARCHITECTURE.md` (a "User interface" section with the diagram in 3.1, the screen
contract and the list of screens and their controllers; module map; remotes),
`DECISIONS.md`, `STUDIO_VERIFY.md`, `ROADMAP.md`.

## 9. Additions to the roadmap

- `SettingsService`, Training pad, `CreateDirectTeam`, `PlaceOnFreePad`.
- Location `category`.
- `FxController` and the effect id list.

## 10. Decisions to record (plain language)

- **Screens only draw; controllers ask; the server decides**, and why.
- **Phones first**: where things are placed and why.
- **Shape plus colour for every status; a reduced-motion setting.**
- **The tutorial is a real (tiny) run**, not a slideshow: the player learns by doing the
  actual mechanic, and it reuses the real puzzle code.
- **The tutorial is skippable and never repeats**; it can be replayed from the Training pad.
- **Sound and effects are wired but silent** until real assets exist.
- **Sliders are plus/minus buttons** so they work the same on touch and gamepad.

## 11. Acceptance and review focus

Roadmap acceptance:

- [ ] All UI is built from small modules driven by data.
- [ ] No UI module makes gameplay decisions.
- [ ] Tutorial progress is stored in the profile.

Review focus:

1. Search `src/client/UI/` for `Remotes`, `Controllers`, `Config/` (other than
   `UIConfig`) and `InvokeServer`/`FireServer`: there must be none. Screens receive
   view models and call callbacks, nothing else.
2. Search `src/client` for anything that changes coins, ownership, readiness, timers
   or outcomes locally and treats it as true. Every such value must be redrawn from
   server state.
3. Every animation goes through `Theme.Tween`; search for `TweenService` elsewhere.
4. No per-frame connections (`RenderStepped`, `Heartbeat`) in the UI; timers run only
   while their screen is visible and are stopped on hide and destroy.
5. Every view controller disconnects what it connected when its screen is destroyed
   (Maid), and tolerates state being nil (not in a team, not in a run, no profile yet,
   arena folder missing).
6. Every visible string comes from `Strings`; every colour and size from `UIConfig`/`Theme`.
7. Every status is shown with a shape as well as a colour.
8. Server: `TutorialSkip`, `RoundPlayAgain` and both settings remotes check state and
   grant nothing by themselves; the tutorial reward cannot be paid twice; a tutorial
   run does not count for streak, stats or normal rewards; the tutorial location is
   never picked for a Standard or Daily run.
9. `CreateDirectTeam` cannot be reached by any client message with arbitrary players or
   modes (only `TutorialService` calls it, with the requesting player only).
10. Controller load order: nothing requires a controller below it; `SessionController`
    is still last.
