class_name Terrain extends RefCounted
## Deterministic ground profile. 100 px = 1 m. Down is +y.
## West to east: the dry canyon country at the far west (semi-desert, the canyon and the old
## Lucky Boy mine), Juniper Spring, the sage flats (Alder Creek), the old homestead meadow,
## the marsh, the Sweetwater River bottoms and the trapper's camp, then the original valley at
## x >= 0 (Rattlesnake Creek, the foothills with the cave and the rock shelter, the ridge and
## the fire lookout), and past the summit down into the old burn where the plane came down,
## the high basin with its tarn, a boulder field on the far rim, the falls, the old-growth
## forest along Cedar Creek, and an aspen grove at the eastern end.
## The valley kept its coordinates when the world grew: new country lies at negative x and
## past 48000, so older saves line up.
## Authored features (waters, level flats, summit, edges) are layered on seeded noise.

const CHUNK_W := 6000.0
const FIRST := -7 ## chunk indices run FIRST..LAST
const LAST := 15
const OLD_MIN := -24000.0 ## where the world's edges were before the canyon and the forest (kept
const OLD_MAX := 72000.0 ## so the scatter in the chunks that had them doesn't shift)
const CHUNKS := LAST - FIRST + 1
const WORLD_MIN := FIRST * CHUNK_W
const WORLD_MAX := (LAST + 1) * CHUNK_W
const EDGE := 900.0 ## world-edge ridges
const FOOTHILLS_X := 24000.0 ## where the valley gives way to foothills
const RIDGE_X := 40500.0 ## start of the climb to the lookout
const CAVE_X := 31500.0 ## middle of the rock-shelter cave
const CAVE_HALF := 450.0
const LOOKOUT_X := 44600.0
const BASIN_X := 53000.0 ## bottom of the descent east of the summit
const HOMESTEAD_X := -16500.0
const TRAPPER_X := -7000.0
const CRASH_X := 57500.0
const MINE_X := -35000.0 ## the Lucky Boy mine, on the canyon floor
const ECHO_CAVE_X := 27000.0 ## the sinkhole into the cave in the foothills
const FALLS_X := 78300.0
const CANYON := Vector2(-31000.0, -39600.0) ## rim to rim

## The original creek (kept as constants: plenty of code and checks refer to it).
const CREEK_X := 13500.0
const CREEK_HALF := 380.0 ## bank to centre
const CREEK_DEPTH := 150.0 ## bed depth below banks
const CREEK_WATER := 40.0 ## water surface below bank top

## Every body of water: kind is creek or river (flowing, drawn into the distance), pond or lake.
const WATERS := [
	{"name": "Rattlesnake Creek", "x": CREEK_X, "half": CREEK_HALF, "depth": CREEK_DEPTH, "water": CREEK_WATER, "kind": "creek", "fish": true},
	{"name": "Sweetwater River", "x": -9000.0, "half": 470.0, "depth": 200.0, "water": 45.0, "kind": "river", "fish": true},
	{"name": "Alder Creek", "x": -19800.0, "half": 260.0, "depth": 110.0, "water": 35.0, "kind": "creek", "fish": true},
	{"name": "Marsh pond", "x": -12600.0, "half": 430.0, "depth": 75.0, "water": 22.0, "kind": "pond", "fish": true},
	{"name": "Burnt Creek", "x": 54600.0, "half": 240.0, "depth": 100.0, "water": 35.0, "kind": "creek", "fish": true},
	{"name": "Basin Tarn", "x": 64500.0, "half": 820.0, "depth": 190.0, "water": 40.0, "kind": "lake", "fish": true},
	{"name": "Juniper Spring", "x": -28800.0, "half": 170.0, "depth": 55.0, "water": 16.0, "kind": "spring", "fish": false, "clean": true},
	{"name": "Falls Pool", "x": FALLS_X, "half": 330.0, "depth": 160.0, "water": 30.0, "kind": "pool", "fish": true},
	{"name": "Cedar Creek", "x": 84800.0, "half": 300.0, "depth": 130.0, "water": 38.0, "kind": "creek", "fish": true},
]
## Level ground for places people built or things came down: [x, half-width].
const FLATS := [[HOMESTEAD_X, 520.0], [TRAPPER_X, 320.0], [CRASH_X, 650.0], [MINE_X, 420.0]]

var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var damp := FastNoiseLite.new()
var bank_y := 0.0 ## the original creek's banks
var cave_y := 0.0 ## the cave's level floor
var summit_y := 0.0 ## the lookout's level summit
var banks: PackedFloat32Array ## per water, bank height
var _flat_y: PackedFloat32Array

func _init(seed_value := 1) -> void:
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0 / 3200.0
	noise.fractal_octaves = 3
	detail.seed = seed_value + 1
	detail.frequency = 1.0 / 380.0
	detail.fractal_octaves = 1
	damp.seed = seed_value + 2
	damp.frequency = 1.0 / 700.0
	bank_y = noise.get_noise_1d(CREEK_X) * 260.0
	for w in WATERS:
		banks.append(bank_y if w.x == CREEK_X else _smooth(w.x))
	for f in FLATS:
		_flat_y.append(_smooth(f[0]))
	cave_y = _base(CAVE_X)
	summit_y = _base(LOOKOUT_X) - 60.0

## Which kind of country x is in.
static func biome(x: float) -> String:
	if x < CANYON.y: return "desert"
	if x < CANYON.x: return "canyon"
	if x < -26500.0: return "desert"
	if x < -17800.0: return "sage"
	if x < -14300.0: return "meadow"
	if x < -10800.0: return "marsh"
	if x < -5200.0: return "river"
	if x < FOOTHILLS_X: return "valley"
	if x < RIDGE_X: return "foothills"
	if x < LOOKOUT_X + 2500.0: return "ridge"
	if x < 61000.0: return "burn"
	if x < 73500.0: return "alpine"
	if x < 77000.0: return "boulders"
	if x < 89000.0: return "oldgrowth"
	return "grove"

## How much warmer (or colder) than the valley a place runs: dry country is warm, the high
## rocks and the deep shade cool.
const WARMER := {"desert": 3.0, "canyon": 2.0, "boulders": -2.0, "oldgrowth": -1.0}

static func temp_offset(x: float) -> float:
	return WARMER.get(biome(x), 0.0)

## 0..1 on the canyon floor, easing up the walls.
static func canyon(x: float) -> float:
	return smoothstep(CANYON.x, CANYON.x - 1600.0, x) * (1.0 - smoothstep(CANYON.y + 1800.0, CANYON.y, x))

static func inside(x: float, margin := 0.0) -> bool:
	return x > WORLD_MIN + margin and x < WORLD_MAX - margin

## 0 in the valley, 1 in the foothills and beyond (rockier ground, sparser trees).
static func foothills(x: float) -> float:
	return smoothstep(FOOTHILLS_X - 1500.0, FOOTHILLS_X + 1500.0, x)

## 0 below the ridge, 1 on it.
static func ridge(x: float) -> float:
	return smoothstep(RIDGE_X - 1000.0, RIDGE_X + 1000.0, x)

## 0..1 inside the marsh: flat, wet ground.
static func marsh(x: float) -> float:
	return smoothstep(-15000.0, -14000.0, x) * (1.0 - smoothstep(-11200.0, -10200.0, x))

## The big shapes without the small bumps: the climb east and back down, the western lowlands.
func _smooth(x: float) -> float:
	var y := noise.get_noise_1d(x) * 260.0
	y -= pow(smoothstep(FOOTHILLS_X - 1500.0, RIDGE_X, x), 1.2) * 1300.0
	y -= smoothstep(RIDGE_X - 1500.0, LOOKOUT_X - 700.0, x) * 1000.0
	y += smoothstep(LOOKOUT_X + 900.0, BASIN_X, x) * 1400.0 # down off the summit into the burn
	y -= smoothstep(61000.0, 70000.0, x) * 500.0 # and up again into the high basin
	y += smoothstep(-1500.0, -8000.0, x) * 220.0 # the river bottoms lie lower
	y -= smoothstep(-15500.0, -22000.0, x) * 320.0 # the sage flats rise west
	y -= smoothstep(-25000.0, -30000.0, x) * 180.0 # and the dry country higher still
	y += canyon(x) * 720.0 # down into the canyon
	y += 60.0 * exp(-pow((x + 36300.0) / 260.0, 2.0)) # the dry wash along its floor
	y += smoothstep(73500.0, 80500.0, x) * 1500.0 # off the basin rim, down past the falls
	y -= smoothstep(88000.0, 95000.0, x) * 260.0 # the aspen benches rise east
	return lerpf(y, _marsh_level(), marsh(x) * 0.85)

func _marsh_level() -> float:
	return noise.get_noise_1d(-12600.0) * 260.0 + 220.0

## Rolling ground plus the long climb east (up is -y).
func _base(x: float) -> float:
	var rough := 16.0 + 14.0 * foothills(x) - 12.0 * marsh(x) + 10.0 * smoothstep(LOOKOUT_X + 2500.0, BASIN_X, x) \
		+ 14.0 * smoothstep(-26000.0, -30000.0, x) - 18.0 * smoothstep(80000.0, 82000.0, x)
	return _smooth(x) + detail.get_noise_1d(x) * rough

func height_at(x: float) -> float:
	var y := _base(x)
	y = lerpf(y, cave_y, 1.0 - smoothstep(CAVE_HALF + 100.0, CAVE_HALF + 700.0, absf(x - CAVE_X))) # level cave floor
	y = lerpf(y, summit_y, 1.0 - smoothstep(500.0, 1300.0, absf(x - LOOKOUT_X))) # level summit
	for i in FLATS.size():
		var f: Array = FLATS[i]
		y = lerpf(y, _flat_y[i], 1.0 - smoothstep(f[1], f[1] + 700.0, absf(x - f[0])))
	for i in WATERS.size():
		var w: Dictionary = WATERS[i]
		var half: float = w.half
		var d := absf(x - float(w.x))
		if d > half + 1100.0:
			continue
		y = lerpf(y, banks[i], 1.0 - smoothstep(half + 150.0, half + 1100.0, d))
		if d < half:
			var k := d / half
			y += float(w.depth) * (1.0 - k * k)
	if x < WORLD_MIN + EDGE:
		y -= pow((WORLD_MIN + EDGE - x) / EDGE, 2.0) * 1100.0
	elif x > WORLD_MAX - EDGE:
		y -= pow((x - (WORLD_MAX - EDGE)) / EDGE, 2.0) * 1100.0
	return y

## The water x lies in (its index into WATERS), or -1. margin widens the test past the banks.
func water_index(x: float, margin := 0.0) -> int:
	for i in WATERS.size():
		if absf(x - WATERS[i].x) < WATERS[i].half + margin:
			return i
	return -1

func surface_of(i: int) -> float:
	return banks[i] + WATERS[i].water

## Water surface y at x, or INF where there is no water.
func water_surface_at(x: float) -> float:
	var i := water_index(x)
	if i < 0:
		return INF
	var s := surface_of(i)
	return s if height_at(x) > s else INF

func water_depth_at(x: float, feet_y: float) -> float:
	var s := water_surface_at(x)
	return 0.0 if s == INF else maxf(minf(feet_y, height_at(x)) - s, 0.0)

## Soft ground that records tracks: banks, the marsh, and scattered damp hollows.
func soft_at(x: float) -> bool:
	if water_surface_at(x) != INF:
		return false
	return water_index(x, 650.0) >= 0 or marsh(x) > 0.5 or damp.get_noise_1d(x) > 0.42

func chunk_of(x: float) -> int:
	return clampi(int(floor(x / CHUNK_W)), FIRST, LAST)
