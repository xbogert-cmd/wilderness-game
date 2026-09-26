extends Node
## Autoload "GameClock": owns world time and weather, advances them each frame.
## Pauses with the tree (backpack open = full pause).

signal ticked(dh: float)

var tuning: Tuning = preload("res://data/tuning.tres")
var clock := Clock.new()
var weather := Weather.new(20260924)
var time_scale := 1.0

func _ready() -> void:
	clock.day_length_sec = tuning.day_length_sec
	clock.days_per_season = tuning.days_per_season

func _process(delta: float) -> void:
	var dh := clock.advance(delta, time_scale)
	weather.step(dh, clock)
	RenderingServer.global_shader_parameter_set("wind", weather.wind)
	ticked.emit(dh)

## Debug/test helper: jump straight to a weather state without the transition.
func force_weather(kind: int) -> void:
	weather.kind = kind
	weather.next_kind = kind
	weather.hours_left = 6.0
	weather.cloud = Weather.CLOUD[kind]
	weather.precip = Weather.PRECIP[kind]
	weather.wind = Weather.WIND[kind]
	weather.thunder = false
	weather.next_thunder = false
	weather.chinook = 0.0
