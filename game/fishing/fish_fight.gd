class_name FishFight extends RefCounted
## The reeling minigame as pure rules. A needle sweeps back and forth across a line; strike
## while it's inside the green zone to gain line, miss and the fish gains slack. Each species
## has its own rhythm: sweep speed, zone size, how many strikes it takes, how much the zone
## drifts, and sudden runs where the needle races.

enum Result { NONE, HIT, MISS, LANDED, ESCAPED }
const MAX_STRAIN := 3

const SPECIES := {
	"trout": {"name": "cutthroat trout", "item": "trout_raw", "speed": 0.75, "zone": 0.14, "hits": 4, "drift": 0.18, "runs": 0.25, "cm": Vector2(28, 46)},
	"whitefish": {"name": "mountain whitefish", "item": "whitefish_raw", "speed": 0.5, "zone": 0.2, "hits": 3, "drift": 0.0, "runs": 0.0, "cm": Vector2(24, 38)},
}

var kind := "trout"
var spec: Dictionary
var needle := 0.0 ## 0..1
var zone := 0.5 ## centre 0..1
var progress := 0.0 ## 0..1 landed
var strain := 0
var ease := 1.0 ## accessibility: <1 slows everything
var _dir := 1.0
var _run := 0.0 ## seconds left in a run
var _t := 0.0
var _rng := RandomNumberGenerator.new()

func _init(species: String, seed_value := 0, speed_scale := 1.0) -> void:
	kind = species
	spec = SPECIES[species]
	ease = speed_scale
	_rng.seed = seed_value
	_move_zone()

func speed() -> float:
	return spec.speed * ease * (1.9 if _run > 0.0 else 1.0)

func zone_half() -> float:
	return spec.zone * 0.5

func step(delta: float) -> void:
	_t += delta
	needle += _dir * speed() * delta
	if needle > 1.0 or needle < 0.0:
		_dir = -_dir
		needle = clampf(needle, 0.0, 1.0)
	if spec.drift > 0.0:
		zone = clampf(zone + sin(_t * 1.7) * spec.drift * delta, zone_half(), 1.0 - zone_half())
	_run = maxf(_run - delta, 0.0)
	if _run == 0.0 and _rng.randf() < spec.runs * delta:
		_run = 1.0

func in_zone() -> bool:
	return absf(needle - zone) <= zone_half()

func strike() -> int:
	if in_zone():
		progress += 1.0 / spec.hits
		if progress >= 0.999:
			return Result.LANDED
		_move_zone()
		return Result.HIT
	strain += 1
	return Result.ESCAPED if strain >= MAX_STRAIN else Result.MISS

func _move_zone() -> void:
	for i in 10: # somewhere the needle isn't, so every strike needs a fresh read
		zone = _rng.randf_range(zone_half(), 1.0 - zone_half())
		if absf(zone - needle) > 0.25:
			return

func length_cm() -> int:
	return _rng.randi_range(int(spec.cm.x), int(spec.cm.y))
