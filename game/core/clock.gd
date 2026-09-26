class_name Clock extends RefCounted
## Absolute game time in hours since the journey began. Pure logic, no nodes.
## The year is a smooth cycle: temperature and day length follow it, seasons are named
## quarters of it. The journey starts at the beginning of autumn.

const SEASONS: PackedStringArray = ["spring", "summer", "autumn", "winter"]
const START_YEAR := 0.5 ## year position on day 0: the start of autumn
const MIDSUMMER := 0.375 ## warmest, longest days
const NOON := 13.0
const DAY_HALF := Vector2(4.5, 7.5) ## half the daylight hours at midwinter, midsummer
## Sky colours are authored for a 6:00 sunrise and 20:00 sunset; solar_hour() maps to that.
const SUNRISE := 6.0
const SUNSET := 20.0

var day_length_sec := 1440.0
var days_per_season := 6
var hours := 8.0

func advance(real_sec: float, scale := 1.0) -> float:
	var dh := real_sec * 24.0 / day_length_sec * scale
	hours += dh
	return dh

func hour_of_day() -> float:
	return fposmod(hours, 24.0)

func day() -> int:
	return int(hours / 24.0)

## 0..1 through the year; spring starts at 0.
func year_pos() -> float:
	return fposmod(START_YEAR + hours / 24.0 / (days_per_season * 4.0), 1.0)

func season_hours() -> float:
	return days_per_season * 24.0

## Hours of growing weather since `since`: winter doesn't count (nothing grows under snow).
func growing_hours(since: float) -> float:
	if since == -INF:
		return INF
	return _grown(hours) - _grown(since)

## Growing hours from the start of year zero up to game hour h.
func _grown(h: float) -> float:
	var year := season_hours() * 4.0
	var u := START_YEAR * year + h
	var y := floorf(u / year)
	return y * season_hours() * 3.0 + minf(u - y * year, season_hours() * 3.0)

func season() -> int:
	return int(year_pos() * 4.0) % 4

## "early autumn", "midwinter", "late spring"...
func season_name() -> String:
	var within := fposmod(year_pos() * 4.0, 1.0)
	var s := SEASONS[season()]
	if within < 0.34:
		return "early " + s
	if within > 0.66:
		return "late " + s
	return "mid" + s if s == "winter" or s == "summer" else "mid-" + s

## 1 at midsummer, -1 at midwinter.
func warmth_cycle() -> float:
	return cos((year_pos() - MIDSUMMER) * TAU)

## Aspen leaves and grass: 0 green, 1 turned (gold, straw). Stays turned through winter.
func leaf_turn() -> float:
	var y := year_pos()
	if y < 0.25:
		return 1.0 - smoothstep(0.06, 0.14, y)
	return smoothstep(0.52, 0.6, y) if y >= 0.5 else 0.0

## Aspen leaves fallen: 0 in leaf, 1 bare.
func leaf_drop() -> float:
	var y := year_pos()
	if y < 0.25:
		return 1.0 - smoothstep(0.04, 0.12, y)
	return smoothstep(0.62, 0.72, y) if y >= 0.5 else 0.0

func sunrise() -> float:
	return NOON - lerpf(DAY_HALF.x, DAY_HALF.y, (warmth_cycle() + 1.0) * 0.5)

func sunset() -> float:
	return 2.0 * NOON - sunrise()

## Hour of day stretched so today's sunrise/noon/sunset land on the authored 6/13/20.
func solar_hour() -> float:
	var h := hour_of_day()
	var rise := sunrise()
	var sets := sunset()
	if h < rise:
		return h / rise * SUNRISE
	if h < NOON:
		return lerpf(SUNRISE, NOON, (h - rise) / (NOON - rise))
	if h < sets:
		return lerpf(NOON, SUNSET, (h - NOON) / (sets - NOON))
	return lerpf(SUNSET, 24.0, (h - sets) / (24.0 - sets))

## 0 at night, 1 at solar noon.
func daylight() -> float:
	var h := hour_of_day()
	return clampf(sin((h - sunrise()) / (sunset() - sunrise()) * PI), 0.0, 1.0)

func is_night() -> bool:
	var h := hour_of_day()
	return h < sunrise() or h > sunset()

func to_dict() -> Dictionary:
	return {"hours": hours}

func from_dict(d: Dictionary) -> void:
	hours = float(d.get("hours", 8.0))
