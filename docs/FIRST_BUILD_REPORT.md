# First Build Report

This is the first playable build of the western wilderness survival game: a systems-first slice of one forest-and-creek valley, built in Godot 4.7.1 with GDScript (about 6,300 lines including tests).

## How to run it
```bash
cd "/Users/alexanderbogert/wilderness game"
godot                                  # play
godot -- --camp --hour=20.5            # jump to a finished camp at dusk
```
The controls and every check command are listed in the [README](../README.md).

## What works
| Area | Status |
|---|---|
| World | 4 streamed chunks (about 240 m), with the current chunk and its neighbours loaded. Terrain is seeded and reproducible. There are edge ridges and a creek you can wade. |
| Depth and atmosphere | Mountains, three forest layers, a fog band, and a foreground layer that fades when it covers you. The creek comes toward the camera through the layers. Day and night, sky, stars and moon, weather-driven clouds, two layers of rain, and morning fog. |
| Weather | Clear, overcast, drizzle, and rain. Rain is always preceded by a 1.5-hour warning: clouds build, wind rises, birds fall silent, and a short music cue plays. |
| Player | A procedural rig with feet placed on the terrain. Idle, walk, run, crouch, wade, hop, chop, carry, drag, kneel to work, sleep, and collapse. The camera looks ahead and widens when you run. |
| Condition | Health, stamina, hunger, and thirst meters. Warmth, wetness, and fatigue appear when they matter. Injuries are per body region (a sprain from a fall, treated with a splint). |
| Backpack | A 6×7 grid of shaped items with rotation, 2 exterior straps, a hands slot, drag and drop, weight and encumbrance, and a recipe list. The game pauses while it's open. |
| Wood | Fell a tree, strip its branches for sticks, then cut the trunk into short, medium, and long logs at marks near you. Logs are physical: shoulder-carry short and medium ones, drag long ones. |
| Camp | Build mode places blueprints, you deliver materials, and assembly takes game time. The campfire has fuel, light, heat, drying, cooking, and boiling. The lean-to gives shelter, becomes your camp, and autosaves. |
| Water and food | Clean and dirty water never mix. Boil dirty water in the pot. Food goes fresh, then stale, then spoiled. Raw fish hurts; cooked fish doesn't. Berries regrow. |
| Sleep | Only under shelter. Time runs about 60× faster. Any key wakes you, and hunger, thirst, or injury wake you too. Recovery depends on the bag, roof, fire, dryness, warmth, and a full stomach. |
| Saving | 3 manual slots plus autosave (at camp and every 5 minutes while safe). Versioned JSON, written atomically, with future and corrupt files refused. Saves only happen when it's safe. |
| Death | Fade out, then wake at camp (or the trailhead). Your pack stays where you fell and never despawns. Food spoils, tools dull, and some consumables scatter. Irreplaceable items are never lost. |
| Wildlife | A data-driven animal brain with hearing, sight, awareness, alert, and flee. It calms once far enough away and never chases across the map. Mule deer have graze, walk, alert, bedded, and stotting poses. Birds flush when you get close. Animals still spawn in felled areas. |
| Tracks | Hooves and boots print in the bank mud and damp hollows. Tracks age from fresh to a few hours old to old, then fade, faster in rain. Examine deer tracks for their age and heading. |
| Fishing | Craft a pole, cast, and read the bobber (with fake-out twitches). Hook within about a second, then play the reel minigame. Trout and whitefish behave differently. Bites depend on time of day, weather, and season. There is an accessibility slider. |
| Persistence | Felled trees, items, logs, trunks, fires, blueprints, shelters, and a dropped pack all survive chunk unloading and saving. Fires catch up on the hours you were away. |
| Sound | 10 ambience layers (from CC0 recordings) mixed by time and weather, a creek positioned in the world, footsteps by surface, wings, splashes, an owl at night, and a synthesized storm cue and deer snort. |
| Guidance | Key popups only on camp things and trunk cutting, a soft glow on things in reach, one-time tips (saved), and a trailhead sign pointing to the lookout. |

## Verification (all passing at the time of writing)
| Check | Command | Result |
|---|---|---|
| Parse and import | `godot --headless --import` | No errors |
| Unit tests | `godot --headless -s tests/run.gd` | 30 passed |
| Smoke | `godot --headless --quit-after 600` | No errors |
| Chunk tour | `godot --headless -- --tour` | 0 failures |
| Camp loop | `--scenario` | 38 checks: fell, strip, buck, haul, lean-to, fire, boil, drink, persistence and catch-up |
| Life | `--scenario=life` | 20 checks: sleep, autosave, save, death, respawn, pack recovery |
| Cold load | `--load=3 --scenario=verify` | 12 checks: time, weather, condition, pack layout, dirty water, camp, fire, dropped item, log, food age |
| Wild | `--scenario=wild` | 18 checks: deer senses and flight, stalking, tracks, fishing, cooking, birds |
| Performance | windowed, vsync off | Heaviest scene (night rain at the creek, camp, fire, deer) about 250 fps. Calm scene about 600 fps. Target is 60. |
| Visuals | `--shot` screenshots | Noon, dusk, night, rain, fog, camp, sleep, pause menu, backpack, deer, fishing, prompts, and debug overlay all reviewed |

Plan acceptance items:
- **Full loop through save and load:** met, across the camp, life, and verify scenarios.
- **Tour of all chunks and back:** met.
- **Death, then respawn at the lean-to with the pack left behind:** met.
- **Deer flee a running player but let a crouched one close:** met (bolted at 686 px when running, 328 px reached crouching).
- **Distinct looks for noon, dusk, night, and rain:** met.
- **Debug overlay shows the correct chunks:** met.
- **60 fps:** met.

## Bugs caught by verification (fixed)
- The HUD and backpack screen had zero size, so the meters didn't draw and the backpack couldn't receive clicks.
- Damage dealt outside the regular condition update could be healed away before death was checked.
- Death could lose the hatchet or lighter, which would soft-lock the game.
- Bucking cuts could be made at the far end of a 10 m trunk.
- A felled trunk was hidden under the ground layer until it was cut.
- The fire's light washed out the screen at noon.
- A reloaded felled tree leaked its art.
- The deer's neck polygon self-intersected when grazing.
- Key-name lookups errored 60 times a second in headless runs.
- The synthesized cue had sub-bass and a DC offset.

## Still temporary
- **All visuals are procedural placeholders** in one locked palette. Every item is listed in [ASSET_MANIFEST.md](../assets/ASSET_MANIFEST.md) with its intended replacement. The player art brief and image-generation prompt are in [player_reference.md](art/player_reference.md).
- **Audio stand-ins:**
  - The owl is a tawny owl; it should be a great horned owl.
  - The rain falls on puddles; it should fall on forest.
  - Hooves reuse pitched footsteps.
  - The snort and the storm cue are synthesized.
- **Not yet heard by a person.** The mix levels have never been listened to; I tuned them by numbers only.
- **Not yet played with a real mouse and keyboard.** Backpack drag and drop, chop timing, and the reel minigame's feel have only been exercised by scripts.

## Deferred (not in this build)
- **Map and journal:** the map, trails, manual map notes, and the field journal, including the mystery journal.
- **Hunting:** hunting and field dressing, bows and firearms, traps and snares, and passive fishing.
- **Seasons and snow:** snow (depth, tracks, weight, melt), seasons beyond a temperature offset, frozen water, and floods.
- **More world:** more biomes and biome blending, caves, and more species (predators, aggression).
- **Skills:** progression through practice, and knowledge from finds.
- **Tools and structures:** sharpening and repair (the data fields exist), cabins, fire spreading between structures, and snow weight on roofs.
- **Hauling and travel:** sleds, travois, canoes, and camp-to-camp travel.
- **People and oddities:** NPCs, rare items, and unexplained encounters.
- **Settings:** key remapping (prompts already read live bindings), controller support, a settings menu, and an assisted map marker.
- **Ragdoll:** the rig has joints ready for it.

## Suggested next steps
1. **Play it for 20–30 minutes** and note what feels wrong. Use real hands on the backpack, chopping, and fishing, and real ears on the mix.
2. **Map and field journal:** the long-term pull, and the place for tracks and knowledge to live.
3. **Hunting:** bow, snares, and field dressing. This builds on the deer brain and tracks.
4. **Seasons and snow:** the biggest atmosphere win, and tracks already have a snow hook.
5. **A second area** (foothills and a cave) to prove the world can grow past one valley.
