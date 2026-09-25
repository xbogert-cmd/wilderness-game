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
| Left click | Use what's in hand: chop, eat, drink, treat, fish, knife an unaware deer. Bow: hold to draw, release to loose. With a felled trunk, aim at a length mark |
| E | Interact: pick up, fill a container at the creek, deliver materials, fuel or light a fire, pot on/off the fire, field dress a carcass |
| F | Lift or set down a log. Short and medium logs ride on the shoulder; long logs drag |
| Q | Put away what's in hand |
| B | Build menu (campfire, lean-to, woodpile, pot tripod, hunting blind, hide frame, drying rack, log cabin), then click to place a blueprint and right-click to cancel |
| F3 | Debug overlay |
| Z | Sleep under a shelter; time runs about 60× faster, and any key wakes you |
| Esc | Pause menu: save to slots 1–3 (only when safe), load any slot or the autosave |
| F5 | Quicksave to slot 1 |
| W/S | Bound; climbing and deeper wading arrive later |

**Camp, sleep, and death:** building or sleeping in a lean-to makes it your camp, which is your respawn point and triggers an autosave (the game also autosaves every 5 minutes when you're safe). If you die, you wake at camp without your pack, which stays where you fell. Food spoils, tools come back duller, and some consumables scatter, but nothing irreplaceable is ever lost. Walk back and press E to recover it.

**Wildlife and fishing:** mule deer graze at dawn and dusk, bed down midday, and read your noise and silhouette. Running spooks them from far off; crouching (Ctrl) and moving slowly gets you close. They bolt, stot away, and settle somewhere new, never chasing across the map. Hooves and boots print in the dark bank mud; press E on deer tracks to read their age and direction. Rain washes tracks out faster. Small birds burst up when you come close. To fish, craft a pole in the backpack (2 sticks + line & hooks), click toward the creek to cast, click when the bobber plunges, then click whenever the needle is in the green. Cook the catch at a lit fire (E) rather than eating it raw.

**Seasons and snow:** the journey starts in early autumn and the year turns: autumn, winter, spring, summer (6 days each, see `data/tuning.tres`). Temperature and day length follow the year smoothly: the aspens go gold, then bare; nights get cold; below freezing the weather brings snow instead of rain. Snow lies and deepens, slows you (knee-deep costs about 40% of your pace), and takes everyone's tracks, anywhere. A long hard cold freezes the creek: the ice bears your weight, E chops a hole to reach the water (it skins over in about 8 hours), and an empty pot held on snow packs full of it to melt and boil on the fire. Your breath shows in the cold, working keeps you warmer, and winter thins the deer. The pause menu shows the day and season; the backpack shows the air temperature.

**Woodpile:** build one (B, 4 sticks) and stack short logs in it with E. It holds 15, drawn end-on as a pyramid that matches the count. E with empty hands takes one back out, and a fire within a few metres feeds straight from the pile.

**Camp builds:** everything is placed with B and built by bringing materials and pressing E.
- *Pot tripod* (3 sticks) goes over a campfire; the pot hangs from it, and only then boils water. With a bottle in hand, E at the fire pours dirty water into the hanging pot or fills the bottle from it once it has boiled.
- *Hunting blind* (6 sticks): crouched behind it, deer can barely see or hear you and will walk right past. Draw the bow over it.
- *Hide frame* (2 medium logs, 2 sticks): field dressing now also gives a raw deer hide, which rots in two days unless you stretch it on the frame. It cures in 18 hours into tanned hide. Two tanned hides and paracord make a *hide coat* (backpack recipe), worn whenever it's in your pack: much warmer, and your jacket turns buckskin.
- *Drying rack* (2 medium logs, 4 sticks): hold raw venison or fish and press E to hang it (8 strips). It dries into jerky in about 12 hours, faster beside a fire, stalled by rain. Hanging meat doesn't spoil.
- *Log cabin* (6 long logs, 6 medium, 4 sticks, 8 hours to build): shelter whose walls hold warmth like a fire. Building or sleeping in it makes it camp, and it's the best sleep in the valley.

**Vines and cord:** vine tangles trail over the ground (they regrow in a few days). Three vines twist into vine cord in the backpack. Recipes ask for "cord" (paracord or vine cord: bow, hide coat) or "line" (line & hooks, or vine cord with a carved hook: fishing pole).

**Chopping:** every blow sounds, throws chips and bites a deeper notch on your side of the trunk; the tree creaks, rushes down and crashes. The chop and fall sounds are synthesized (`tools/synth_audio.py`).

**Hunting:** creep up behind a grazing deer that hasn't noticed you and click with the knife; if it's alert it bolts. From range, craft a bow (3 sticks + the paracord in your kit) and arrows (2 sticks make 4) in the backpack. Hold click to draw; at a good draw a dotted arc shows the drop. The arrow strikes what you aimed at: a chest or head hit drops the deer within a few seconds, anything else wounds it and it runs longer, leaving blood drops you can follow and examine (E). Missed arrows usually survive in the dirt. Field dress the carcass with E (knife in the pack or hand) for 4 venison, which spoils from the moment of the kill; cook it at a fire.

**First camp:** gather fallen sticks (E), press B to place a campfire blueprint and deliver 3 sticks, build it, then light it with E. For a lean-to, fell a tree with the hatchet, strip its branches, cut 2 long and 4 medium logs at the marks, and haul them to a lean-to blueprint. To make water safe, fill the cook pot at the creek, set it on a lit fire until it boils, take it back, and pour it into your bottle from the backpack.

## Checks
```bash
godot --headless --import                 # parse and import check
godot --headless -s tests/run.gd          # unit tests (exit code = failure count)
godot --headless --quit-after 600         # smoke run
godot --headless -- --tour                # walk every chunk and back, verify streaming
godot --headless --fixed-fps 60 -- --scenario   # full camp loop end to end (~3 min)
godot --fixed-fps 60 --resolution 1280x720 -- --scenario   # same, windowed: only this catches UI eating clicks
# Any run with flags after `--` saves to user://test_saves, never to the player's user://saves.
godot --headless --fixed-fps 60 -- --scenario=life                # sleep, autosave, save slot 3, die, respawn, recover
godot --headless --fixed-fps 60 -- --load=3 --scenario=verify     # then cold-load slot 3 and check it matches
godot --headless --fixed-fps 60 -- --scenario=wild                # deer senses, tracks, fishing, cooking, birds, hunting
godot --headless --fixed-fps 60 -- --scenario=winter              # woodpile, seasons, snow, tracks in snow, frozen creek
godot -- --hour=19.5 --weather=rain --x=13500 --shot=out.png   # screenshot a scenario
```
Other debug flags (after `--`): `--walk=1|-1`, `--run`, `--zoom=Z`, `--debug`, `--camp` (finished camp nearby), `--sleep`, `--pack`, `--menu`, `--deer`, `--flee`, `--fish`, `--load=SLOT`.

## Layout
- `game/core/`: pure rules with no nodes (clock, weather, condition, tuning). All unit-tested.
- `game/world/`: terrain, streamed chunks, parallax backdrop, atmosphere, ambience, rain.
- `game/player/`: movement (`player.gd`), procedural rig (`player_rig.gd`), camera, footsteps.
- `game/wildlife/`: generic `Animal` brain, species data (`data/species/*.tres`), deer rig, spawner, birds, tracks.
- `game/fishing/`: `FishFight` minigame rules (unit-tested), session, reel meter.
- `game/art/`: palette and procedural placeholder art.
- `data/tuning.tres`: every balance number. Edit this, not the code.
- `assets/`: audio, plus `ASSET_MANIFEST.md` (sources, licences, what's temporary).
- `docs/art/`: the player reference and image-generation prompts.

## Extending
- **New tuning value:** add an `@export` to `game/core/tuning.gd`, then read it via `GameClock.tuning`.
- **New animal:** add a `SpeciesDef` .tres (senses, speeds, flee distance, herd size, active hours), add it to `Wildlife.SPECIES`, and give it a rig. No behaviour code changes needed.
- **New fish:** add an entry to `FishFight.SPECIES` (sweep speed, zone, strikes, drift, runs) plus raw and cooked items.
- **New ambience bed:** add a WAV loop (set `edit/loop_mode=2` in its `.import`), then add a gain rule in `Ambience._process`.
- **World scale:** 100 px = 1 m; chunks are 60 m wide. Only the current chunk and its neighbours exist at a time.
