# Level design

Locations, rooms and puzzles, with a solve walkthrough for every room. The game builds
its maps from data definitions in `src/shared/Content/`, so this document and those
definitions must always agree.

> **Status:** skeleton. Puzzle types and Location 1 are designed and documented in M6.

## Design pillars (from the brief)

1. **Teamwork is mandatory.** Every room needs 2+ players doing different things at once
   (with "helper" mechanics so solo and duo teams can still finish).
2. **Instantly readable.** A new player understands the goal in under 10 seconds.
3. **Short, repeatable runs.** 4-8 minutes per expedition.
4. **Mobile-first.** Big targets, simple controls, no precision-required inputs.
5. **Mild content.** Cartoon hazards, no gore.

## Vocabulary

| Term | Meaning |
|------|---------|
| **Location** | A themed place to escape from (for example a sinking cargo ship). Made of rooms. |
| **Room** | One puzzle space. Clearing it opens the way to the next room. |
| **Puzzle** | The teamwork challenge inside a room. |
| **Hazard** | The advancing danger (rising water, lava) that puts a clock on the run. |
| **Checkpoint** | Where players respawn inside the current room. |
| **Expedition** | One full run through a location. |

## Puzzle types

_Documented in M6: Hold-the-door, Power routing, Timed switches, Carry-and-place._

## Locations

_Documented in M6 using the template below._

### Template: location

```
## Location <N>: <Name>
Theme:            <one sentence>
Default hazard:   <water | lava | ...>
Target run time:  <minutes>
Rooms:            <count>

### Room <N>: <Name>
Puzzle type:      <type>
Difficulty:       <1-5>
Players needed:   <minimum with helpers> to <maximum useful>
Layout:           <short description of the space>
Goal (10-second read): <what the player sees and understands immediately>

Solve walkthrough (4 players):
1. ...
Solve walkthrough (solo/duo with helper mechanics):
1. ...

Reset path:       <what happens if the puzzle is failed or players respawn>
Hazard notes:     <safe zones, how the hazard interacts with this room>
```
