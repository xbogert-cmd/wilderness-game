class_name Terrain extends RefCounted
## Deterministic ground profile of the valley slice. 100 px = 1 m. Down is +y.
## Authored features (creek, edges) are layered on seeded noise so the world is reproducible.

const CHUNK_W := 6000.0
const CHUNKS := 4
const WORLD_W := CHUNK_W * CHUNKS
const CREEK_X := 13500.0
const CREEK_HALF := 380.0 ## bank to centre
const CREEK_DEPTH := 150.0 ## bed depth below banks
const CREEK_WATER := 40.0 ## water surface below bank top
const EDGE := 900.0 ## world-edge ridges

var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var damp := FastNoiseLite.new()
var bank_y := 0.0

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

func height_at(x: float) -> float:
	var y := noise.get_noise_1d(x) * 260.0 + detail.get_noise_1d(x) * 16.0
	var d := absf(x - CREEK_X)
	y = lerpf(y, bank_y, 1.0 - smoothstep(CREEK_HALF + 150.0, CREEK_HALF + 1100.0, d))
	if d < CREEK_HALF:
		var k := d / CREEK_HALF
		y += CREEK_DEPTH * (1.0 - k * k)
	if x < EDGE:
		y -= pow((EDGE - x) / EDGE, 2.0) * 1100.0
	elif x > WORLD_W - EDGE:
		y -= pow((x - (WORLD_W - EDGE)) / EDGE, 2.0) * 1100.0
	return y

## Water surface y at x, or INF where there is no water.
func water_surface_at(x: float) -> float:
	var s := bank_y + CREEK_WATER
	return s if absf(x - CREEK_X) < CREEK_HALF and height_at(x) > s else INF

func water_depth_at(x: float, feet_y: float) -> float:
	var s := water_surface_at(x)
	return 0.0 if s == INF else maxf(minf(feet_y, height_at(x)) - s, 0.0)

## Soft ground that records tracks: the creek banks and scattered damp hollows.
func soft_at(x: float) -> bool:
	if water_surface_at(x) != INF:
		return false
	return absf(x - CREEK_X) < CREEK_HALF + 650.0 or damp.get_noise_1d(x) > 0.42

func chunk_of(x: float) -> int:
	return clampi(int(floor(x / CHUNK_W)), 0, CHUNKS - 1)
