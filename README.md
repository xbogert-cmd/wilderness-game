# Wilderness (working title)

An atmospheric 2D side-scrolling wilderness survival game set in the western United States. Built with Godot 4.7.1 and GDScript.

## Run
Open the folder in Godot 4.7 and press Play, or from a terminal:
```bash
godot
```

## Controls
| Key | Action |
|---|---|
| A / D | Move |
| Shift | Run (uses stamina) |
| Ctrl | Crouch |
| Space | Hop |
| Tab | Backpack (pauses the game): drag to pack, R rotates while dragging |
| 1 / 2 | Draw the tool strapped outside the pack (hatchet, knife), or put it back |
| Left click | Use what's in hand: chop, eat, drink, treat. With a felled trunk, aim at a length mark |
| E | Interact: pick up, fill a container at the creek, deliver materials, fuel or light a fire, pot on/off the fire |
| F | Lift or set down a log. Short and medium logs ride on the shoulder; long logs drag |
| Q | Put away what's in hand |
| B | Build menu (campfire, lean-to), then click to place a blueprint and right-click to cancel |
| F3 | Debug overlay |
| Z | Sleep under a shelter; time runs about 60× faster, and any key wakes you |
| Esc | Pause menu: save to slots 1–3 (only when safe), load any slot or the autosave |
| F5 | Quicksave to slot 1 |
| W/S | Bound; climbing and deeper wading arrive later |

**Camp, sleep, and death:** building or sleeping in a lean-to makes it your camp, which is your respawn point and triggers an autosave (the game also autosaves every 5 minutes when you're safe). If you die, you wake at camp without your pack, which stays where you fell. Food spoils, tools come back duller, and some consumables scatter, but nothing irreplaceable is ever lost. Walk back and press E to recover it.

**First camp:** gather fallen sticks (E), press B to place a campfire blueprint and deliver 3 sticks, build it, then light it with E. For a lean-to, fell a tree with the hatchet, strip its branches, cut 2 long and 4 medium logs at the marks, and haul them to a lean-to blueprint. To make water safe, fill the cook pot at the creek, set it on a lit fire until it boils, take it back, and pour it into your bottle from the backpack.

## Checks
```bash
godot --headless --import                 # parse and import check
godot --headless -s tests/run.gd          # unit tests (exit code = failure count)
godot --headless --quit-after 600         # smoke run
godot --headless -- --tour                # walk every chunk and back, verify streaming
godot --headless --fixed-fps 60 -- --scenario   # full camp loop end to end (~3 min)
godot --headless --fixed-fps 60 -- --scenario=life                # sleep, autosave, save slot 3, die, respawn, recover
godot --headless --fixed-fps 60 -- --load=3 --scenario=verify     # then cold-load slot 3 and check it matches
godot -- --hour=19.5 --weather=rain --x=13500 --shot=out.png   # screenshot a scenario
```
Other debug flags (after `--`): `--walk=1|-1`, `--run`, `--zoom=Z`, `--debug`, `--camp` (finished camp nearby), `--sleep`, `--pack`, `--menu`, `--load=SLOT`.

## Layout
- `game/core/`: pure rules with no nodes (clock, weather, condition, tuning). All unit-tested.
- `game/world/`: terrain, streamed chunks, parallax backdrop, atmosphere, ambience, rain.
- `game/player/`: movement (`player.gd`), procedural rig (`player_rig.gd`), camera, footsteps.
- `game/art/`: palette and procedural placeholder art.
- `data/tuning.tres`: every balance number. Edit this, not the code.
- `assets/`: audio, plus `ASSET_MANIFEST.md` (sources, licences, what's temporary).
- `docs/art/`: the player reference and image-generation prompts.

## Extending
- **New tuning value:** add an `@export` to `game/core/tuning.gd`, then read it via `GameClock.tuning`.
- **New ambience bed:** add a WAV loop (set `edit/loop_mode=2` in its `.import`), then add a gain rule in `Ambience._process`.
- **World scale:** 100 px = 1 m; chunks are 60 m wide. Only the current chunk and its neighbours exist at a time.
