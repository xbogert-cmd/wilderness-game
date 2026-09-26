class_name Weather extends RefCounted
## Markov weather with a readable warning phase before rain. Pure logic.
## Wind follows the valley: it blows up toward the ridge (east) by day and back down the valley
## (west) at night, turning in the morning and evening; a passing front can reverse it.
## Below freezing the same precipitation falls as snow, which lies, deepens and melts;
## a long hard cold freezes the creek.

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
const MEAN_C := 6.0 ## yearly mean; swings ±SWING_C between midwinter and midsummer
const SWING_C := 15.0
const SNOW_CM_PER_HOUR := 5.0 ## at full precipitation
const MELT_CM_PER_DEG_HOUR := 0.5
const MAX_SNOW_CM := 80.0

var kind: int = Kind.CLEAR
var next_kind: int = Kind.OVERCAST
var hours_left := 5.0
var warning_hours := 1.5 ## game hours of visible/audible signs before rain starts
var cloud := 0.1
var precip := 0.0
var wind := 0.15
var wind_dir := 1 ## which way it blows: +1 toward the east (right), -1 toward the west
var front := 1 ## +1: the usual valley breeze; -1: a front has turned it round
var _daytime := -1 ## last valley-breeze phase applied (1 day, 0 night, -1 not yet)
const UPSLOPE_HOURS := Vector2(9.0, 19.0) ## the breeze blows up the valley between these
var snow_frac := 0.0 ## 0 = falls as rain, 1 = as snow (eases across freezing)
var snow_cm := 0.0 ## lying snow
var ice := 0.0 ## creek ice, 0 open to 1 frozen hard
var rng := RandomNumberGenerator.new()

func _init(seed_value := 1) -> void:
	rng.seed = seed_value

func step(dh: float, clock: Clock = null) -> void:
	hours_left -= dh
	if hours_left <= 0.0:
		kind = next_kind
		next_kind = _roll(kind)
		hours_left = rng.randf_range(2.0, 8.0)
		if rng.randf() < 0.35:
			front = -front # a front brings the wind round
			wind_dir = -wind_dir
	var target_cloud := CLOUD[kind]
	var target_wind := WIND[kind]
	if storm_warning():
		var k := 1.0 - hours_left / warning_hours
		target_cloud = lerpf(CLOUD[kind], CLOUD[next_kind], k)
		target_wind = lerpf(WIND[kind], WIND[next_kind], k)
	cloud = move_toward(cloud, target_cloud, dh * 0.8)
	wind = move_toward(wind, target_wind, dh * 0.8)
	precip = move_toward(precip, PRECIP[kind], dh * 1.5)
	if clock:
		_ground(dh, air_temp_c(clock))
		var h := clock.hour_of_day()
		var day := 1 if h >= UPSLOPE_HOURS.x and h < UPSLOPE_HOURS.y else 0
		if day != _daytime: # the breeze turns with the day
			_daytime = day
			wind_dir = (1 if day == 1 else -1) * front

func _ground(dh: float, t: float) -> void:
	snow_frac = clampf((1.5 - t) / 2.0, 0.0, 1.0)
	snow_cm += snowfall() * SNOW_CM_PER_HOUR * dh
	if t > 0.0:
		snow_cm -= t * MELT_CM_PER_DEG_HOUR * (1.0 + 2.0 * rain()) * dh
	snow_cm = clampf(snow_cm, 0.0, MAX_SNOW_CM)
	if t < -3.0:
		ice += (-3.0 - t) * 0.015 * dh
	elif t > 1.0:
		ice -= (t - 1.0) * 0.03 * dh
	ice = clampf(ice, 0.0, 1.0)

func rain() -> float:
	return precip * (1.0 - snow_frac)

func snowfall() -> float:
	return precip * snow_frac

## 0..1: heavy snow driven by a hard wind. Whiteout, and it cuts through your clothes.
func blizzard() -> float:
	return clampf((snowfall() - 0.4) / 0.35, 0.0, 1.0) * clampf((wind - 0.5) / 0.25, 0.0, 1.0)

func storm_warning() -> bool:
	return next_kind == Kind.RAIN and kind != Kind.RAIN and hours_left <= warning_hours

func air_temp_c(clock: Clock) -> float:
	var diurnal := 6.0 * sin((clock.hour_of_day() - 9.0) / 24.0 * TAU)
	return MEAN_C + SWING_C * clock.warmth_cycle() + diurnal - 3.0 * precip - 2.0 * cloud

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
		"precip": precip, "wind": wind, "rng_state": str(rng.state),
		"snow_frac": snow_frac, "snow_cm": snow_cm, "ice": ice, "wind_dir": wind_dir, "front": front, "daytime": _daytime}

func from_dict(d: Dictionary) -> void:
	kind = int(d.kind)
	next_kind = int(d.next)
	hours_left = float(d.left)
	cloud = float(d.cloud)
	precip = float(d.precip)
	wind = float(d.wind)
	rng.state = int(d.rng_state)
	snow_frac = float(d.get("snow_frac", 0.0))
	snow_cm = float(d.get("snow_cm", 0.0))
	ice = float(d.get("ice", 0.0))
	wind_dir = int(d.get("wind_dir", 1))
	front = int(d.get("front", 1))
	_daytime = int(d.get("daytime", -1))
