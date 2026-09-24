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
| F3 | Debug overlay |
| W/S, E, F, Q, 1/2, R, Tab, Z, Esc, F5, mouse | Bound; the features behind them arrive in later milestones |

## Checks
```bash
godot --headless --import                 # parse and import check
godot --headless -s tests/run.gd          # unit tests (exit code = failure count)
godot --headless --quit-after 600         # smoke run
godot --headless -- --tour                # walk every chunk and back, verify streaming
godot -- --hour=19.5 --weather=rain --x=13500 --shot=out.png   # screenshot a scenario
```
Other debug flags (after `--`): `--walk=1|-1`, `--run`, `--zoom=Z`, `--debug`.

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
