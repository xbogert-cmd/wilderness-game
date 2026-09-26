class_name Weather extends RefCounted
## Markov weather with a readable warning phase before rain. Pure logic.
## Wind follows the valley: it blows up toward the ridge (east) by day and back down the valley
## (west) at night, turning in the morning and evening; a passing front can reverse it.
## Below freezing the same precipitation falls as snow, which lies, deepens and melts;
## a long hard cold freezes the creek.
## Summer rain can come as a thunderstorm (lightning, distant thunder before it). In winter a
## chinook sometimes roars down off the ridge: warm, dry and fast, it eats the snow. Calm
## mornings after rain, and in the cool seasons, the valley fills with fog. Rain and snowmelt
## raise the creeks (a flood), and in spring the ice goes out in a rush (the breakup).

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
var thunder := false ## this rain is a thunderstorm
var next_thunder := false ## the rain coming is
var chinook := 0.0 ## hours of chinook wind left
const CHINOOK_C := 17.0 ## how much warmer it blows
var fog := 0.0 ## valley fog, 0..1 (thins out up in the foothills: Terrain.fog_at)
var damp := 0.0 ## how wet the ground and air are after rain, 0..1
var _fog_day := -1 ## the day the morning's fog was rolled for
var _fog_chance := 0.0 ## that morning's fog, 0..1
var flood := 0.0 ## how high the creeks are running, 0 normal .. 1 bankfull and roaring
var floods := 0 ## how many floods so far (things left in the water may go with each)
var _flooding := false
var breakup := 0.0 ## hours of the spring breakup left: ice going out down the creeks
var since_rain := 99.0 ## hours since it last rained properly (a rainbow, drips off the trees)
const FLOOD_AT := 0.6 ## a flood (things in the water can wash away)
const WADE_FLOOD := 0.45 ## the creeks run too deep and fast to wade

func _init(seed_value := 1) -> void:
	rng.seed = seed_value

func step(dh: float, clock: Clock = null) -> void:
	hours_left -= dh
	if hours_left <= 0.0:
		kind = next_kind
		thunder = next_thunder and kind == Kind.RAIN
		next_kind = _roll(kind)
		# a warm day's rain may build into a thunderstorm
		next_thunder = next_kind == Kind.RAIN and clock != null and _base_temp(clock) > 9.0 and rng.randf() < 0.5
		hours_left = rng.randf_range(2.0, 8.0)
		if rng.randf() < 0.35:
			front = -front # a front brings the wind round
			wind_dir = -wind_dir
		if clock and chinook <= 0.0 and _base_temp(clock) < -3.0 and snow_cm > 5.0 and rng.randf() < 0.08:
			chinook = rng.randf_range(10.0, 22.0) # the snow-eater
			kind = Kind.CLEAR
			next_kind = Kind.OVERCAST
			next_thunder = false
			hours_left = chinook
	var target_cloud := CLOUD[kind]
	var target_wind := WIND[kind] + (0.15 if thunder else 0.0)
	if storm_warning():
		var k := 1.0 - hours_left / warning_hours
		target_cloud = lerpf(CLOUD[kind], CLOUD[next_kind], k)
		target_wind = lerpf(WIND[kind], WIND[next_kind] + (0.15 if next_thunder else 0.0), k)
	if chinook > 0.0:
		chinook = maxf(chinook - dh, 0.0)
		target_cloud = 0.35 # the chinook arch: a band of cloud over the ridge, clear below
		target_wind = 0.8
	cloud = move_toward(cloud, target_cloud, dh * 0.8)
	wind = move_toward(wind, target_wind, dh * 0.8)
	precip = move_toward(precip, PRECIP[kind], dh * 1.5)
	since_rain = 0.0 if rain() > 0.3 else since_rain + dh
	if precip > 0.3:
		damp = minf(damp + dh * 0.5, 1.0)
	else:
		damp = maxf(damp - dh * 0.04, 0.0)
	if clock:
		_ground(dh, air_temp_c(clock))
		_fog(dh, clock)
		var h := clock.hour_of_day()
		var day := 1 if h >= UPSLOPE_HOURS.x and h < UPSLOPE_HOURS.y else 0
		if day != _daytime: # the breeze turns with the day
			_daytime = day
			wind_dir = (1 if day == 1 else -1) * front
		if chinook > 0.0:
			wind_dir = -1 # down off the ridge

## Fog settles in the valley on calm nights and burns off in the morning sun: most mornings
## after rain, and some in the cool seasons. Wind or rain clears it.
func _fog(dh: float, clock: Clock) -> void:
	var day := int(clock.hours / 24.0)
	if day != _fog_day:
		_fog_day = day
		var cool := 0.35 if clock.season() in [0, 2] else (0.15 if clock.season() == 3 else 0.0)
		_fog_chance = clampf(damp * 0.9 + cool + rng.randf_range(-0.4, 0.3), 0.0, 1.0) if rng.randf() < 0.7 else 0.0
	var h := clock.hour_of_day()
	var night_to_morning := smoothstep(1.0, 4.0, h) * (1.0 - smoothstep(8.5, 11.0 + 2.0 * cloud, h))
	var calm := 1.0 - smoothstep(0.25, 0.45, wind)
	var target := _fog_chance * night_to_morning * calm * (1.0 - smoothstep(0.3, 0.8, precip))
	if kind == Kind.DRIZZLE and wind < 0.4:
		target = maxf(target, 0.35 * _fog_chance) # low cloud down in the trees
	fog = move_toward(fog, target, dh * 0.6)

func _ground(dh: float, t: float) -> void:
	snow_frac = clampf((1.5 - t) / 2.0, 0.0, 1.0)
	snow_cm += snowfall() * SNOW_CM_PER_HOUR * dh
	var melt := 0.0
	if t > 0.0:
		melt = minf(t * MELT_CM_PER_DEG_HOUR * (1.0 + 2.0 * rain()) * dh, snow_cm)
		snow_cm -= melt
	snow_cm = clampf(snow_cm, 0.0, MAX_SNOW_CM)
	var was := ice
	if t < -3.0:
		ice += (-3.0 - t) * 0.015 * dh
	elif t > 1.0:
		ice -= (t - 1.0) * 0.03 * dh * (0.35 if ice > 0.6 else 1.0) # thick ice goes slowly, then all at once
	ice = clampf(ice, 0.0, 1.0)
	# The creeks rise with rain and meltwater and fall back over a day or so.
	var rise := rain() * (0.16 if thunder else 0.1) * dh + melt * 0.018
	breakup = maxf(breakup - dh, 0.0)
	if was >= 0.6 and ice < 0.6 and t > 0.0: # the ice goes out
		breakup = 8.0
		rise += 0.3
	flood = clampf(flood + rise - dh * 0.045 * (1.0 + flood), 0.0, 1.0)
	if flood >= FLOOD_AT and not _flooding:
		_flooding = true
		floods += 1
	elif flood < FLOOD_AT - 0.25:
		_flooding = false

func rain() -> float:
	return precip * (1.0 - snow_frac)

func snowfall() -> float:
	return precip * snow_frac

## 0..1: heavy snow driven by a hard wind. Whiteout, and it cuts through your clothes.
func blizzard() -> float:
	return clampf((snowfall() - 0.4) / 0.35, 0.0, 1.0) * clampf((wind - 0.5) / 0.25, 0.0, 1.0)

func storm_warning() -> bool:
	return next_kind == Kind.RAIN and kind != Kind.RAIN and hours_left <= warning_hours

## Lightning now.
func thunderstorm() -> bool:
	return thunder and kind == Kind.RAIN and precip > 0.5 and snow_frac < 0.5

## Thunder far off: a storm building, or one going by.
func thunder_far() -> bool:
	return thunderstorm() or (next_thunder and hours_left <= warning_hours * 1.5)

## 0..1: white frost on the ground, cold clear mornings before the sun gets to it.
func frost(clock: Clock) -> float:
	var h := clock.hour_of_day()
	return clampf(-air_temp_c(clock) / 3.0, 0.0, 1.0) * (1.0 - smoothstep(9.0, 11.0, h)) * (1.0 - smoothstep(2.0, 12.0, snow_cm)) \
		* (1.0 - precip) * (0.4 + 0.6 * (1.0 - cloud))

## 0..1: a rainbow: the sun out, low enough, right after a rain.
func rainbow(clock: Clock) -> float:
	var h := clock.hour_of_day()
	var low_sun := smoothstep(7.0, 9.0, h) * (1.0 - smoothstep(10.5, 11.5, h)) + smoothstep(15.0, 16.0, h) * (1.0 - smoothstep(18.5, 19.5, h))
	return low_sun * (1.0 - smoothstep(0.3, 1.2, since_rain)) * smoothstep(0.05, 0.25, since_rain) * (1.0 - smoothstep(0.1, 0.3, precip)) * (1.0 - smoothstep(0.5, 0.85, cloud)) * (1.0 - snow_frac)

func chinook_k() -> float:
	return clampf(chinook / 2.0, 0.0, 1.0) if chinook > 0.0 else 0.0

func air_temp_c(clock: Clock) -> float:
	return _base_temp(clock) - 3.0 * precip - 2.0 * cloud + CHINOOK_C * chinook_k()

func _base_temp(clock: Clock) -> float:
	var diurnal := 6.0 * sin((clock.hour_of_day() - 9.0) / 24.0 * TAU)
	return MEAN_C + SWING_C * clock.warmth_cycle() + diurnal

## What a barometer shows: inches of mercury, and which way it's going (-2 falling fast, -1
## falling, 0 steady, 1 rising). It falls hours before the rain comes, well before the sky shows it.
func pressure_trend() -> int:
	var wet := func(k: int) -> bool: return k == Kind.DRIZZLE or k == Kind.RAIN
	if chinook > 0.0:
		return -1
	if not wet.call(kind) and wet.call(next_kind):
		return -2 if hours_left <= 3.0 or next_thunder else -1
	if wet.call(kind) and not wet.call(next_kind) and hours_left <= 3.0:
		return 1
	if kind == Kind.OVERCAST and next_kind == Kind.CLEAR:
		return 1
	return 0

func pressure_inhg() -> float:
	var ahead := clampf(1.0 - hours_left / 8.0, 0.0, 1.0) * absf(float(mini(pressure_trend(), 0))) * 0.12
	return 30.12 - 0.3 * cloud - 0.35 * precip - ahead - (0.25 if thunder else 0.0) - 0.2 * chinook_k()

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
		"snow_frac": snow_frac, "snow_cm": snow_cm, "ice": ice, "wind_dir": wind_dir, "front": front, "daytime": _daytime,
		"thunder": thunder, "next_thunder": next_thunder, "chinook": chinook, "fog": fog, "damp": damp,
		"fog_day": _fog_day, "fog_chance": _fog_chance, "flood": flood, "floods": floods, "flooding": _flooding, "breakup": breakup, "since_rain": since_rain}

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
	thunder = bool(d.get("thunder", false))
	next_thunder = bool(d.get("next_thunder", false))
	chinook = float(d.get("chinook", 0.0))
	fog = float(d.get("fog", 0.0))
	damp = float(d.get("damp", 0.0))
	_fog_day = int(d.get("fog_day", -1))
	_fog_chance = float(d.get("fog_chance", 0.0))
	flood = float(d.get("flood", 0.0))
	floods = int(d.get("floods", 0))
	_flooding = bool(d.get("flooding", false))
	breakup = float(d.get("breakup", 0.0))
	since_rain = float(d.get("since_rain", 99.0))
