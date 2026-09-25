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

Wildlife audio is still missing: deer snort and bound, bird flush, and fish splash. These are the next CC0 picks.

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
| `owl.wav` | 0429 | Tawny Owls | Two calls cut from 10.4 s | Temporary: tawny owl is European; replace with great horned owl |
| `steps/grass_1..6.wav` | 1253 | Steps in the Grass, Slow | Single steps cut at detected onsets | Keep; add dirt, leaves, and snow sets |
| `steps/mud_1..6.wav` | 0495 | Steps in the Mud | Single steps | Keep; add a dedicated wading set |

Music: none yet. The planned rain-warning cue is still open.
