# Player Animation Reference

The source of truth for final player art. The current placeholder (`game/player/player_rig.gd`) draws simple shapes on exactly these joints. Final art should be cutout sprite parts attached to the same joints, so the IK and gait code stays unchanged.

## Scale and view
- 100 px = 1 m. Standing height about 175 px, from boot sole to hat crown.
- Pure side view, drawn facing right; facing left mirrors on x.
- Origin is at the feet, centred between them. Up is -y.
- Light comes from the upper-left of the scene. Time-of-day tint is applied on top (CanvasModulate), so paint in neutral daylight.

## Palette (`game/art/palette.gd`)
| Part | Hex |
|---|---|
| Jacket (canvas, rust) | `#9a5b3a` |
| Pants (denim) | `#3e4c5e` |
| Boots | `#3b2a20` |
| Skin | `#c89b7b` |
| Hat (felt, wide brim) | `#6b5a45` |
| Pack (olive canvas) | `#5e6b45` |
| Bedroll (tan) | `#b39a6e` |

The far arm and far leg are the same colours darkened about 28%.

## Body parts and joints (standing, facing right)
| Part | From joint | To joint | Length | Width |
|---|---|---|---|---|
| Thigh | hip (0, -95) | knee | 46 | 15 → 12 |
| Shin | knee | ankle | 46 | 12 → 9 |
| Boot | ankle | sole | 7 tall, 25 long | — |
| Torso (jacket) | hip | shoulder | 62 | 20 waist → 25 chest |
| Head | neck, 19 above shoulder | — | radius 10.5 | — |
| Hat | head | — | 40 brim, 17 crown | — |
| Upper arm | shoulder | elbow | 31 | 11 → 9.5 |
| Forearm and hand | elbow | hand | 29 | 9.5 → 8, hand r5 |
| Pack | torso back, hip +12 → shoulder | — | 16 deep | — |

Draw order, back to front: far arm, far leg, pack and bedroll, hip, near leg, torso, head, hat, near arm.

## States and key poses
| State | Key poses | Gait parameters (`GAITS` in the rig) |
|---|---|---|
| Idle | Relaxed stand with feet 16 apart, breathing 0.25 Hz | — |
| Walk | Contact, down, passing, up (×2 per cycle) | stride 62, lift 12, stance 62%, arm swing 0.42 rad |
| Run | Contact, push-off, flight, reach | stride 118, lift 30, stance 40%, arm 0.95 rad, elbows 1.35 rad |
| Crouch-walk | Low contact and passing, torso leaning 23° | hip −30, stride 40 |
| Wade | Walk with arms raised clear of the water, slower | arm swing ×0.4, elbows 1.1 rad |
| Airborne (hop) | Tuck with feet under the hip | — |
| *Planned:* carry, drag, chop, drink, fish cast/reel, sleep, fall/ragdoll, get up | Pose sheets needed |

Transition rules: gait parameters blend through the smoothed hip height and lean. Feet are always placed by IK on the terrain, so slopes need no separate animations. Ragdoll only happens on severe impacts (planned), followed by an authored get-up.

## Asset naming
`player_<part>_<variant>.png`, for example `player_thigh_near.png` and `player_jacket_winter.png`. Each part's pivot sits at its "from" joint.

## Image-generation prompt (for the reference turnaround and pose sheets)
> Original character design sheet, 2D side-view game character, a lone wilderness traveler in the western United States: wide-brim brown felt hat, rust-colored waxed canvas jacket, dark denim trousers, worn leather boots, olive canvas backpack with a tan bedroll strapped on top. Flat-shaded cutout style with clean silhouettes, muted natural palette (#9a5b3a, #3e4c5e, #3b2a20, #c89b7b, #6b5a45, #5e6b45), neutral daylight from the upper left, plain background. Show a strict profile facing right plus three-quarter and back views, same proportions (about 7.5 heads tall) across every view. No text, no logos.

Pose-sheet variant: the same prompt plus "walk cycle key poses: contact, down, passing, up; evenly spaced, same scale, ground line visible".
