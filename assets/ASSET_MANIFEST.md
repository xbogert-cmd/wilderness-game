# Asset Manifest

Every asset in the build, where it came from, and whether it is temporary.

## Art

All visuals are currently **procedural placeholders** drawn in code with the locked palette in `game/art/palette.gd`. No image files yet.

| Asset | Source | Status | Intended replacement |
|---|---|---|---|
| Conifers (fir/pine) | `SceneryArt.conifer` | Temporary | Painted fir/ponderosa sprites, 3 sizes x 4 variants, with separate canopy for sway |
| Aspens / broadleaf | `SceneryArt.broadleaf` | Temporary | Aspen + cottonwood sprites, seasonal leaf variants (green, gold, bare) |
| Bushes, rocks, ferns, grass | `SceneryArt.*` | Temporary | Painted props; grass as a sway-shaded strip texture |
| Background ridges and mountains | `Backdrop._forest`, `_mountains` | Temporary | Painted parallax plates per depth layer, per biome |
| Fire lookout (distant landmark) | `Backdrop._mountains` | Temporary | Painted silhouette with a faint window light at night |
| Ground cross-section | `Chunk._soil_bands` | Temporary | Soil texture with roots/stones, tiling along the surface |
| Creek water | `game/world/water.gdshader` | Keep (shader), tune | Add foam at banks, reflections |
| Sky, clouds, stars | `game/world/sky.gdshader` | Keep (shader), tune | Painted cloud sheets blended into the shader |
| Player | `PlayerRig` (drawn shapes) | Temporary | Cutout sprite parts on the same joints. See `docs/art/player_reference.md` |
| HUD meters | `Hud` (drawn) | Keep, restyle | Hand-drawn icons |
| Backpack item tiles | `BackpackUI._item` (colour blocks + name) | Temporary | Painted top-down item icons, one per cell footprint |
| Items in hand | `PlayerRig._held_item` | Temporary | Sprites attached to the hand joint |
| Logs, felled trunks, stumps | `WorldLog`, `FelledTrunk`, `ChoppableTree._stump` | Temporary | Bark-textured sprites with cut-end rings |
| Campfire (stones, wood, flames) | `Campfire._draw` + particles + light | Temporary art, keep the light and particles | Animated flame sprite sheet |
| Lean-to | `LeanTo._draw` | Temporary | Painted structure in build stages (frame → roof → bedding) |
| Blueprint ghosts | `Blueprint`, `BuildMode` | Keep, restyle | Chalk-line style outlines |
| Mule deer | `DeerRig` (drawn, jointed) | Temporary | Cutout sprite parts on the same joints; poses: graze, walk, alert, bedded, stot, bound |
| Birds | `BirdFlock._draw` | Temporary | Small sprite sheet (peck, hop, flap) |
| Tracks (boot, hoof) | `Tracks._draw` | Temporary | Decal sprites per species and age stage |
| Fishing pole, line, bobber | `PlayerRig._held_item`, `Fishing._draw` | Keep line and bobber, replace pole | Pole sprite |
| Reel meter | `FishingUI` | Keep, restyle | Hand-drawn gauge |



## Audio

Source files are in `assets/audio/src/` (originals, never imported). All are from **BigSoundBank**, licensed **CC0 (public domain)**: no attribution required, commercial use allowed.
Processed files: mono, loudness-normalised (loops at -20 LUFS, steps at -18 LUFS), and loops made seamless with a 2–3 s crossfade seam (`loop_mode=2` in the `.import` files).

| File | BigSoundBank ID | Original title | Processing | Status |
|---|---|---|---|---|
| `forest_day.wav` | 0100 | Forest | Seamless loop | Keep (add 2–3 more variants) |
| `creek.wav` | 0823 | Small Stream | Loop, positional | Keep |
| `wind_trees.wav` | 0659 | Wind in a Tree | Loop | Keep; add a strong-wind layer (1450) for storms |
| `rain.wav` | 1290 | Rain on Puddle | Loop | Temporary: want rain on leaves/forest floor |
| `night_crickets.wav` | 0110 | Campaign at night #1 | Loop | Keep |
| `dusk.wav` | 3203 | Mountain, Evening #1 | Loop, downmixed to mono | Keep |
| `campfire.wav` | 0988 | Big Branching Fire #2 | Loop | Keep (milestone 8) |
| `steps/grass_1..6.wav` | 1253 | Steps in the Grass, Slow | Single steps cut at detected onsets | Keep; add dirt, leaves, and snow sets |
| `steps/mud_1..6.wav` | 0495 | Steps in the Mud | Single steps | Keep; add a dedicated wading set |

| `sfx/wings_1..3.wav` | 2891, 2892, 2894 | Flight Bird #1, #2, #4 | Trimmed to 2.2 s, mono | Keep |
| `sfx/splash_1..2.wav` | 1529, 1531 | Splash, Small #1, #3 | Trimmed, mono | Keep |
| (hooves) | reuses `steps/grass_*` | — | Pitched up ×1.5, quieter | Temporary: want real hoofbeats |

### Biome ambience and calls (added 2026-09-26)
Built by `tools/process_audio.py` from the originals in `assets/audio/src/bsb/` (BigSoundBank, CC0) and `assets/audio/src/fs/` (Freesound, every one CC0; the Yellowstone ones are National Park Service recordings, public domain). Freesound files are the site's public HQ previews. Loops go to `amb/` (mono, -20 LUFS, crossfaded seam, `loop_mode=2`); one-shots to `sfx/<name>_<n>.wav` (-18 LUFS). Which biome uses what: `Ambience.PROFILES`.

| Output | Source | Original title |
|---|---|---|
| `sfx/axe_1..6` | BigSoundBank 0536 | Ax on Wood |
| `sfx/axe_far_1..6` | Freesound 410768 (Selector) | axe chopping (in the forest) |
| `sfx/split_1..3` | Freesound 519567 (Nivatius, NPS) | splitting logs |
| `sfx/treefall_1` | Freesound 494071 (Kinoton) | Big Tree Fall in Forest (crash at 1.75 s) |
| `sfx/wolves_1..2` | Freesound 519592 (Nivatius, NPS) | Wolves - Yellowstone National Park |
| `sfx/grizzly_1..3` | Freesound 519599 (Nivatius, NPS) | Grizzly Bear growl eating (the bear's roar) |
| `sfx/raven_1..3` | Freesound 519591 (Nivatius, NPS) | Common Raven - Yellowstone |
| `amb/toads` | Freesound 519590 (Nivatius, NPS) | Spadefoot Toad - Yellowstone |
| `sfx/coyotes_1..3` | Freesound 640060 (SamsterBirdies) | coyotes howling |
| `sfx/coyote_1..2` | Freesound 833774 (darcydunes) | Coyote_Crickets-Short |
| `sfx/marmot_1..3` | Freesound 822939 (SoundsLikeYukon) | Hoary marmot whistles |
| `sfx/squirrel_1..3` | Freesound 111393 (philberts) | Red_Squirrel_chatter |
| `sfx/flicker_1..4` | Freesound 568807 (TRP) | Northern Flicker calls |
| `sfx/woodpecker_1..4` | Freesound 518573 (misswakawaka) | Woodpecker pecking on dead tree |
| `sfx/canyon_wren_1` | Freesound 351649 (alyceobvious) | canyon_wren |
| `sfx/hawk_1..3` | Freesound 683743 (kvgarlic) | Red Shouldered Hawk cry |
| `sfx/owl_gh_1` | Freesound 157870 (gfrog) | Owl in Arkansas Backyard 01 |
| `sfx/elk_1` | Freesound 263489 (lwdickens) | elk bugle, Banff |
| `sfx/geese_1..2` | Freesound 204337 (wjoojoo) | cibolo_geese09 |
| `sfx/jay_1..3` | Freesound 736257 (itinerantmonk108) | Blue Jay |
| `sfx/ducks_1..2` | BigSoundBank 0276 | Ducks |
| `sfx/bats_1` | BigSoundBank 0458 | Cries of bats |
| `sfx/rockfall_1..5` | BigSoundBank 1022 | Fall of Stone |
| `sfx/ice_1`, `ice2_1` | BigSoundBank 2205, 2206 | Cracking ice #1, #2 |
| `amb/marsh_day` | BigSoundBank 0691 | Pond in a Field |
| `amb/marsh_night` | BigSoundBank 0998 | Frogs #2 |
| `amb/frogs_close` | Freesound 569543 (bmacphail) | Many Frogs at Night in Marsh |
| `amb/desert_day` | BigSoundBank 1779 | Sun and Heat #1 |
| `amb/cicadas` | BigSoundBank 2397 | Cicada 1, Long |
| `amb/wind_strong` | BigSoundBank 0146 | Strong Wind #1 |
| `amb/wind_whistle` | BigSoundBank 0147 | Whistling of the Wind #1 |
| `amb/wind_grass` | BigSoundBank 0908 | Wind in Tall Grass |
| `amb/wind_creak` | BigSoundBank 1051 | Wind and tree squeaks |
| `amb/wind_storm` | BigSoundBank 1450 | Strong wind and trees #1 |
| `amb/wind_cottonwood` | Freesound 579250 (Danjocross) | Wind in Cottonwood Trees Utah |
| `amb/wind_aspen` | Freesound 637993 (kyles) | wind through aspens |
| `amb/oldgrowth_day` | Freesound 563571 (Cinetony) | Wind in forest with creaking tree |
| `amb/drips` | BigSoundBank 1386 | Drops of Water #3 |
| `amb/oldgrowth_night` | BigSoundBank 0555 | Forest at Night After Rain |
| `amb/meadow_day` | BigSoundBank 0097 | Countryside |
| `amb/prairie` | Freesound 351609 (dsebeste) | PrairieSummer_ambience |
| `amb/field_crickets` | BigSoundBank 1020 | Field cricket |
| `amb/foothills_day` | BigSoundBank 2749 | Forest #4 |
| `amb/alpine_day` | BigSoundBank 3204 | Mountain, evening #2 |
| `amb/sage_day` | Freesound 176786 (conleec) | Eastern Oregon Wildlife (meadowlarks) |
| `amb/nighthawks` | Freesound 245393 (kvgarlic) | Summer Nighthawk and Insects |

### Original (synthesized in code, no licence needed)
Generated by `tools/synth_audio.py` (pure Python stdlib), then normalised with ffmpeg. Re-run the script to regenerate or tweak.

| File | What it is | Status |
|---|---|---|
| `music/storm_cue.wav` | 16 s. A low bowed-string drone on D swells in; a fifth joins; a minor second (E flat) rubs for unease; a distant thunder roll sits at 40–120 Hz; the cue settles on D without resolving. Plays when a storm warning starts, at most every 10 min, never while asleep. | Keep until a composer's cue exists |
| `sfx/snort_1..2.wav` | Mule deer alarm snort: a noise burst through two resonances with a second, smaller puff. Only the first deer to bolt snorts. | Temporary: a field recording would be better |
| `sfx/pika_1..3.wav` | A pika's short, nasal, falling "eeep", one to three at a time (no free recording found). | Temporary: a field recording would be better |
| `sfx/thrush_1..3.wav` | A varied thrush: one long buzzy whistle, fading in and out, in the old-growth. | Temporary: a field recording would be better |
