class_name Atmosphere extends Node
## Turns clock + weather into light, sky, haze, fog and rain every frame.
## Everything visual about time and weather is decided here.

## [hour, sky top, horizon, ambient light, sun colour]
const KEYS := [
	[0.0, "0b1020", "1b2438", "4d5577", "000000"],
	[4.8, "10162a", "252c44", "4d5577", "000000"],
	[6.0, "34436a", "d38a5e", "8b7f86", "ffb070"],
	[7.3, "5a82ad", "e0c7a0", "d8d0c2", "ffe0a8"],
	[12.0, "5a8dc0", "cddbe0", "ffffff", "fff6e0"],
	[17.0, "6190bb", "ddd4b8", "f5ecdc", "ffe8b8"],
	[19.3, "49588a", "e58c5a", "c49a86", "ff9c60"],
	[20.4, "1f2848", "5a4058", "6a6480", "ff7040"],
	[21.6, "0b1020", "1b2438", "4d5577", "000000"],
	[24.0, "0b1020", "1b2438", "4d5577", "000000"],
]
const OVERCAST := Color("8a9095")

var sky: ShaderMaterial
var canvas_mod: CanvasModulate
var backdrop: Backdrop
var rain: Rain
var _keys: Array = []

func _ready() -> void:
	for k in KEYS:
		_keys.append([k[0], Color(k[1]), Color(k[2]), Color(k[3]), Color(k[4])])

func _sample(h: float) -> Array:
	for i in _keys.size() - 1:
		var a: Array = _keys[i]
		var b: Array = _keys[i + 1]
		if h <= b[0]:
			var t := smoothstep(a[0], b[0], h)
			return [a[1].lerp(b[1], t), a[2].lerp(b[2], t), a[3].lerp(b[3], t), a[4].lerp(b[4], t)]
	return _keys[-1].slice(1)

func _process(_delta: float) -> void:
	var clock := GameClock.clock
	var w := GameClock.weather
	var h := clock.solar_hour() # sky keys are authored for a 6:00-20:00 day
	var c := _sample(h)
	var light := clock.daylight()
	var grey := OVERCAST * lerpf(0.25, 1.0, (c[2] as Color).get_luminance() * 1.4)
	grey.a = 1.0
	var top: Color = c[0].lerp(grey.darkened(0.15), w.cloud * 0.85)
	var horizon: Color = c[1].lerp(grey, w.cloud * 0.75)
	var ambient: Color = c[2] * lerpf(1.0, 0.72, w.cloud)
	var bz := w.blizzard()
	if bz > 0.0: # a whiteout: everything goes pale and close
		horizon = horizon.lerp(Color(0.85, 0.87, 0.9) * lerpf(0.35, 1.0, light), bz * 0.8)
		top = top.lerp(horizon, bz * 0.7)
		ambient = ambient.lerp(Color(0.8, 0.82, 0.86) * lerpf(0.45, 1.0, light), bz * 0.35)
	ambient.a = 1.0

	RenderingServer.global_shader_parameter_set("haze_color", horizon)
	canvas_mod.color = ambient
	sky.set_shader_parameter("top_color", top)
	sky.set_shader_parameter("horizon_color", horizon)
	sky.set_shader_parameter("sun_color", c[3])
	sky.set_shader_parameter("cloud_color", horizon.lerp(ambient, 0.4).lerp(grey, w.cloud * 0.5))
	sky.set_shader_parameter("cloud", w.cloud)
	var t := (h - Clock.SUNRISE) / (Clock.SUNSET - Clock.SUNRISE)
	sky.set_shader_parameter("sun_uv", Vector2(lerpf(0.08, 0.92, t), 0.78 - sin(clampf(t, 0.0, 1.0) * PI) * 0.62))
	sky.set_shader_parameter("sun_alpha", smoothstep(-0.03, 0.05, t) * smoothstep(1.03, 0.95, t))
	var tm := fposmod(h - Clock.SUNSET, 24.0) / (24.0 - (Clock.SUNSET - Clock.SUNRISE))
	sky.set_shader_parameter("moon_uv", Vector2(lerpf(0.1, 0.9, tm), 0.7 - sin(clampf(tm, 0.0, 1.0) * PI) * 0.55))
	sky.set_shader_parameter("moon_alpha", 1.0 - smoothstep(0.0, 0.1, light))
	sky.set_shader_parameter("stars", 1.0 - smoothstep(0.0, 0.12, light))

	var morning := exp(-pow((h - 6.5) / 1.8, 2.0))
	backdrop.fog_material.set_shader_parameter("density", 0.12 + 0.55 * morning + 0.3 * w.precip + 0.9 * bz)
	rain.set_weather(w.rain(), w.snowfall(), w.wind)
