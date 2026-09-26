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
| M | Map and field journal (pauses the game) |
| 1 / 2 | Draw the tool strapped outside the pack (hatchet, knife), or put it back |
| Left click | Use what's in hand: chop, eat, drink, treat, fish, knife an unaware deer, thrust the spear, wave the torch. Bow: hold to draw, release to loose. With a felled trunk, aim at a length mark |
| E | Interact: pick up, fill a container at the creek, deliver materials, the fire, a carcass. Where there's more than one thing to do, E opens a numbered list: press the number (E again or walking off closes it) |
| F | Lift or set down a log (short and medium logs ride on the shoulder; long logs drag), or let go of a dragged carcass |
| Q | Put away what's in hand |
| B | Build menu (campfire, lean-to, woodpile, pot tripod, workbench, storage chest, bait pile, hunting blind, hide frame, drying rack, snare, log cabin), then click to place a blueprint and right-click to cancel |
| F3 | Debug overlay |
| Z | Sleep under a shelter, or anywhere with your sleeping bag (out in the open the rain gets you and it isn't camp); time runs about 60× faster, and any key wakes you |
| Esc | Pause menu: save to slots 1–3 (only when safe), load any slot or the autosave |
| F5 | Quicksave to slot 1 |
| W/S | Bound; climbing and deeper wading arrive later |

**Camp, sleep, and death:** building or sleeping in a lean-to makes it your camp, which is your respawn point and triggers an autosave (the game also autosaves every 5 minutes when you're safe). If you die, you wake at camp without your pack, which stays where you fell. Food spoils, tools come back duller, and some consumables scatter, but nothing irreplaceable is ever lost. Walk back and press E to recover it.

**Wildlife and fishing:** mule deer graze at dawn and dusk, bed down midday, and read your noise and silhouette. Running spooks them from far off; crouching (Ctrl) and moving slowly gets you close. They bolt, stot away, and settle somewhere new, never chasing across the map. Hooves and boots print in the dark bank mud; press E on deer tracks to read their age and direction. Rain washes tracks out faster. Small birds burst up when you come close. To fish, craft a pole in the backpack (2 sticks + line & hooks), click toward the creek to cast, click when the bobber plunges, then click whenever the needle is in the green. Cook the catch at a lit fire (E) rather than eating it raw.

**Seasons and snow:** the journey starts in early autumn and the year turns: autumn, winter, spring, summer (6 days each, see `data/tuning.tres`). Temperature and day length follow the year smoothly: the aspens go gold, then bare; nights get cold; below freezing the weather brings snow instead of rain. Snow lies and deepens, slows you (knee-deep costs about 40% of your pace), and takes everyone's tracks, anywhere. A long hard cold freezes the creek: the ice bears your weight, E chops a hole to reach the water (it skins over in about 8 hours), and an empty pot held on snow packs full of it to melt and boil on the fire. Your breath shows in the cold, working keeps you warmer, and winter thins the deer. The pause menu shows the day and season; the backpack shows the air temperature.

**Woodpile:** build one (B, 4 sticks) and stack short logs in it with E. It holds 15, drawn end-on as a pyramid that matches the count. E with empty hands takes one back out, and a fire within a few metres feeds straight from the pile.

**Camp builds:** everything is placed with B and built by bringing materials and pressing E.
- *Pot tripod* (3 sticks) goes over a campfire; the pot hangs from it, and only then boils water. E at the fire pours your bottle (in hand or in the pack) into the hanging pot, or fills the bottle from it once it has boiled. Pouring dirty water into clean makes it all dirty again.
- *Hunting blind* (6 sticks): crouched behind it, deer can barely see or hear you and will walk right past. Draw the bow over it.
- *Hide frame* (2 medium logs, 2 sticks): a raw deer hide, wolf pelt or bear hide rots in two days unless you stretch it on the frame. It cures in 18 hours (a bear hide 30) into tanned hide or cured fur.
- *Drying rack* (2 medium logs, 4 sticks): hang raw venison or fish from your hands or straight from the pack (8 strips). It dries into jerky in about 12 hours, faster beside a fire, stalled by rain. Hanging meat doesn't spoil.
- *Log cabin* (6 long logs, 6 medium, 4 sticks, 8 hours to build): shelter whose walls hold warmth like a fire. Building or sleeping in it makes it camp, and it's the best sleep in the valley.

**The wider world:** east of the creek valley the land climbs through rockier foothills (fewer aspens, more boulders) past a *rock shelter*, then up the ridge to the *fire lookout* (about 450 m of country in all). The rock shelter is dry and a little warmer than outside, somewhere to sleep, and someone left a cache there. At the lookout, E at the ladder climbs the tower, hand over hand: the view pulls back, the whole map fills in, the cab is shelter to sleep in, and the keeper's cupboard holds supplies and the logbook. Don't step off the catwalk.

**Map and journal (M):** the map is the land's profile as you've seen it (unexplored stretches stay blank), with the trailhead, creek, rock shelter, lookout, your camp and structures, a dropped pack, game trails you've crossed, and you. The field journal writes itself the first time things happen or are found: making camp, first snow, the seasons turning, your first deer, the rock shelter, the lookout, and pages left by the last keeper.

**Deer around you:** a small herd is kept around you (fewer in winter): new deer appear out of sight on either side, on that stretch's game trail, and deer that wander 60 m off and out of view leave. A deer you spook leaves the area for good (it keeps going and is gone once out of sight), and none wander in for a while after. Deer keep clear of camps and fires. Wounded deer never leave, so a blood trail always ends at the deer.

**Clothing:** the pack has four clothing slots (Head, Coat, Mitts, Legs). Clothing only warms you when you wear it: drag it onto its slot, or select it and press Wear (what it replaces goes back in the pack). Your own clothes are always on underneath. Buckskin (a coat from 2 tanned hides and cord, leggings from 1) adds about +12 °C: fine for autumn, not enough for a winter night. Real winter gear is fur: a wolf-fur hat, mittens (1 cured wolf fur each) and leggings (2 and cord), and a bear-fur coat (cured bear fur and cord), about +30 °C in all. Overdressed in the warm, you sweat and get thirsty faster. You keep your clothes on when you die.

**Wolves and the bear:** they never come near your camp (a lean-to, cabin or campfire, lit or not) or a torch in your hand. They come for food left out: a carcass, a gut pile, meat on the ground, a rabbit in a snare, and (the bear) bait piles. Ravens circle anything dead by day, a sign for you and for them, and anything left out overnight away from camp is mostly eaten by morning. A wolf pack comes after dark (any time in winter), follows the smell of raw meat you carry, and howls at night. Wolves stalk, spring and bite someone who's hurt or carrying meat after dark (the bear rears and swipes; either knocks you back): face them with a spear or torch and they won't close in, and hurting one scatters the pack. The black bear keeps to the foothills around the rock shelter and sleeps through winter. Walk up on it (or its food) and it bluff-charges and stops short; come back at it and the next charge is real. An arrow to the chest kills a wolf; the bear takes two. Skin them (knife) for a wolf pelt or bear hide.

**Torch, spear, snares:** at a lit fire, E offers *Light a torch* (uses a stick): it lights the dark for about three hours (less in rain), keeps you out of reach of anything wild, and click waves it to drive them off. It can't go in the pack; putting it away snuffs it. The *spear* (bench, 3 sticks) thrusts at arm's length and a half: it hurts a wolf or the bear, takes a rabbit or an unaware deer, and held toward a predator keeps it at bay. *Snares* (cord and a stick make two) are set from the build menu; rabbits run into them mostly at dawn and dusk. A rabbit left hanging out past camp often gets taken. Rabbits also hop about at dawn and dusk; an arrow takes one.

**Build menu (B):** each entry says what it's for and what you have toward it (pack items, and logs lying nearby).

**Workbench, tools, storage:** a *workbench* (2 medium logs, 2 sticks) is needed for the bigger crafting: bow, arrows, spear, clothing, deer call (the recipe list says "at a workbench"). Quick things (vine cord, splint, fishing pole) work anywhere. Tools dull as you use them and their handles wear: a worn tool works slower but never breaks. Select the hatchet or knife in the pack to *sharpen* it on a whetstone (two lie on the creek banks; ~30 sharpenings each), or to *repair the handle* with 2 sticks at the workbench. A *storage chest* (1 medium log, 3 sticks) opens beside the pack: drag between them, or use Move to chest / Move to pack.

**Wind, trails, bait, calls:** the wind has a direction (arrow, bottom right): it blows up the valley toward the ridge by day and back down at night, turning around 9:00 and 19:00, and a passing front can reverse it. It carries your scent: a deer downwind smells you from 8-17 m depending on the wind, blind or no blind, so come at deer from downwind. Each part of the valley has a game trail, a worn path between bedding cover and a feeding ground; deer bed there by day and walk it at dawn and dusk. A *bait pile* (4 berries, via B) draws active deer within 26 m to feed until it's eaten or goes off in two days. A *deer call* (bench, 1 stick) bleats: curious deer walk toward you, but a third call in a short while makes them wary.

**Vines and cord:** vine tangles trail over the ground (they regrow in a few days). Three vines twist into vine cord in the backpack. Recipes ask for "cord" (paracord or vine cord: bow, hide coat) or "line" (line & hooks, or vine cord with a carved hook: fishing pole).

**Chopping:** every blow sounds, throws chips and bites a deeper notch on your side of the trunk; the tree creaks, rushes down and crashes. The chop and fall sounds are synthesized (`tools/synth_audio.py`).

**Hunting:** creep up behind a grazing deer that hasn't noticed you (or one looking away) and click with the knife to take it outright; if it's seen you, the knife cuts it as it bolts and it bleeds, so follow the blood. The knife always strikes, and also fights off a wolf or the bear at close quarters. From range, craft a bow (3 sticks + the paracord in your kit) and arrows (2 sticks make 4) in the backpack. Hold click to draw; at a good draw a dotted arc shows the drop. The arrow strikes what you aimed at: a chest or head hit drops the deer within a few seconds, anything else wounds it and it runs longer, leaving blood drops you can follow and examine (E). Missed arrows usually survive in the dirt. At the carcass, E offers two choices. *Butcher it here* (knife): the hide and as many of its 6 cuts of venison as fit go straight into your pack, and the rest wait on the carcass for you to come back for. It leaves a gut pile that draws wolves. Or *drag it* home whole (F lets go): slow, hard going, but nothing is left behind to draw them, and at camp it's safe. Venison spoils from the moment of the kill; cook it at a fire or dry it on the rack.

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
godot --headless --fixed-fps 60 -- --scenario=winter              # woodpile, seasons, snow, tracks in snow, frozen creek, camp builds
godot --headless --fixed-fps 60 -- --scenario=world               # foothills, rock shelter, lookout, map, journal, the herd
godot --headless --fixed-fps 60 -- --scenario=predators           # choices, torch, wolves, bear, spear, butchering, snares, clothing
godot -- --x=9000 --hour=22 --wolves=torch --shot=out.png          # previews: --wolves[=torch] --bear[=0|1|2] --wear[=buckskin] --choices --attack[=bear] --climb --buildmenu
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
