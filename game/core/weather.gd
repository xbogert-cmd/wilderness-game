class_name Weather extends RefCounted
## Markov weather with a readable warning phase before rain. Pure logic.

enum Kind { CLEAR, OVERCAST, DRIZZLE, RAIN }
const NAMES: PackedStringArray = ["clear", "overcast", "drizzle", "rain"]
const CLOUD: PackedFloat32Array = [0.1, 0.6, 0.75, 0.95]
const PRECIP: PackedFloat32Array = [0.0, 0.0, 0.35, 1.0]
const WIND: PackedFloat32Array = [0.15, 0.3, 0.35, 0.8]
## [next_kind, weight]
const NEXT := {
	Kind.CLEAR: [[Kind.OVERCAST, 1.0]],
	Kind.OVERCAST: [[Kind.CLEAR, 0.4], [Kind.DRIZZLE, 0.35], [Kind.RAIN, 0.25]],
	Kind.DRIZZLE: [[Kind.OVERCAST, 0.5], [Kind.RAIN, 0.3], [Kind.CLEAR, 0.2]],
	Kind.RAIN: [[Kind.DRIZZLE, 0.6], [Kind.OVERCAST, 0.4]],
}
const SEASON_BASE_C: PackedFloat32Array = [12.0, 22.0, 10.0, -2.0]

var kind: int = Kind.CLEAR
var next_kind: int = Kind.OVERCAST
var hours_left := 5.0
var warning_hours := 1.5 ## game hours of visible/audible signs before rain starts
var cloud := 0.1
var precip := 0.0
var wind := 0.15
var rng := RandomNumberGenerator.new()

func _init(seed_value := 1) -> void:
	rng.seed = seed_value

func step(dh: float) -> void:
	hours_left -= dh
	if hours_left <= 0.0:
		kind = next_kind
		next_kind = _roll(kind)
		hours_left = rng.randf_range(2.0, 8.0)
	var target_cloud := CLOUD[kind]
	var target_wind := WIND[kind]
	if storm_warning():
		var k := 1.0 - hours_left / warning_hours
		target_cloud = lerpf(CLOUD[kind], CLOUD[next_kind], k)
		target_wind = lerpf(WIND[kind], WIND[next_kind], k)
	cloud = move_toward(cloud, target_cloud, dh * 0.8)
	wind = move_toward(wind, target_wind, dh * 0.8)
	precip = move_toward(precip, PRECIP[kind], dh * 1.5)

func storm_warning() -> bool:
	return next_kind == Kind.RAIN and kind != Kind.RAIN and hours_left <= warning_hours

func air_temp_c(clock: Clock) -> float:
	var diurnal := 6.0 * sin((clock.hour_of_day() - 9.0) / 24.0 * TAU)
	return SEASON_BASE_C[clock.season()] + diurnal - 3.0 * precip - 2.0 * cloud

func _roll(from: int) -> int:
	var options: Array = NEXT[from]
	var r := rng.randf()
	for o in options:
		r -= o[1]
		if r <= 0.0:
			return o[0]
	return options[-1][0]

func to_dict() -> Dictionary:
	return {"kind": kind, "next": next_kind, "left": hours_left, "cloud": cloud,
		"precip": precip, "wind": wind, "rng_state": str(rng.state)}

func from_dict(d: Dictionary) -> void:
	kind = int(d.kind)
	next_kind = int(d.next)
	hours_left = float(d.left)
	cloud = float(d.cloud)
	precip = float(d.precip)
	wind = float(d.wind)
	rng.state = int(d.rng_state)
