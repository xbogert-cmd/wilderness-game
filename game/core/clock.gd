class_name Clock extends RefCounted
## Absolute game time in hours since the journey began. Pure logic, no nodes.

const SEASONS: PackedStringArray = ["spring", "summer", "autumn", "winter"]
const SUNRISE := 6.0
const SUNSET := 20.0

var day_length_sec := 1440.0
var days_per_season := 4
var hours := 8.0

func advance(real_sec: float, scale := 1.0) -> float:
	var dh := real_sec * 24.0 / day_length_sec * scale
	hours += dh
	return dh

func hour_of_day() -> float:
	return fposmod(hours, 24.0)

func day() -> int:
	return int(hours / 24.0)

func season() -> int:
	return (day() / days_per_season) % 4

## 0 at night, 1 at solar noon.
func daylight() -> float:
	var h := hour_of_day()
	return clampf(sin((h - SUNRISE) / (SUNSET - SUNRISE) * PI), 0.0, 1.0)

func is_night() -> bool:
	var h := hour_of_day()
	return h < SUNRISE or h > SUNSET

func to_dict() -> Dictionary:
	return {"hours": hours}

func from_dict(d: Dictionary) -> void:
	hours = float(d.get("hours", 8.0))
