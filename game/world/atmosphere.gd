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
var veil: ShaderMaterial ## fog and blizzard over the view (visibility.gdshader)
var _aurora := 0.0
static var force_aurora := false ## (preview)
static var sun_dir := 0.0 ## -1 the sun's off to the left .. 1 to the right
static var sun_k := 0.0
static var moon_k := 0.0 ## the moon up in a clear night sky ## how strongly the sun's shining (0 night, cloud, underground)
var shimmer: ColorRect ## heat shimmer over hot dry country (off unless there's heat)
const HOT := {"desert": 1.0, "canyon": 1.0, "sage": 0.6, "meadow": 0.2}
var beams: ShaderMaterial ## sunbeams, cloud shadows and vignette
const BEAMS := {"valley": 1.0, "river": 0.7, "oldgrowth": 1.0, "grove": 0.9, "foothills": 0.7, "burn": 0.5, "marsh": 0.5, "meadow": 0.6}
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
	var p: Player = get_tree().get_first_node_in_group("player")
	var under := p.under if p else 0.0
	var fog := Terrain.fog_at(p.global_position.x) * (1.0 - under) if p else 0.0
	if fog > 0.0: # fog greys and flattens the light
		ambient = ambient.lerp(horizon.lerp(Color(0.75, 0.77, 0.78) * lerpf(0.3, 1.0, light), 0.6), fog * 0.25)
		horizon = horizon.lerp(Color(0.78, 0.8, 0.8) * lerpf(0.3, 1.0, light), fog * 0.6)
	if under > 0.0: # underground it's dark whatever the hour: bring a light
		ambient = ambient.lerp(Color(0.11, 0.105, 0.12), under * 0.95)
	if Storm.flash > 0.0: # lightning
		ambient = ambient.lerp(Color(0.92, 0.94, 1.0), Storm.flash * 0.75)
		top = top.lerp(Color(0.8, 0.82, 0.95), Storm.flash * 0.6)
		horizon = horizon.lerp(Color(0.85, 0.87, 0.97), Storm.flash * 0.6)
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
	# Where the sun is and how strongly it lights things (scenery, ground)
	sun_dir = clampf((t - 0.5) * 2.0, -1.0, 1.0)
	RenderingServer.global_shader_parameter_set("sun_dir", sun_dir)
	sun_k = smoothstep(-0.03, 0.08, t) * smoothstep(1.03, 0.92, t) * (1.0 - w.cloud * 0.85) * (1.0 - under)
	RenderingServer.global_shader_parameter_set("sun_k", sun_k)
	RenderingServer.global_shader_parameter_set("sun_col", (c[3] as Color).lerp(Color(1, 0.97, 0.9), 0.3))
	RenderingServer.global_shader_parameter_set("under", under)
	RenderingServer.global_shader_parameter_set("cam_x", get_viewport().get_camera_2d().get_screen_center_position().x if get_viewport().get_camera_2d() else 0.0)
	var tm := fposmod(h - Clock.SUNSET, 24.0) / (24.0 - (Clock.SUNSET - Clock.SUNRISE))
	RenderingServer.global_shader_parameter_set("wind_dir", float(w.wind_dir))
	var yp := clock.year_pos() # wildflowers: spring into early summer (lupine, balsamroot, paintbrush)
	RenderingServer.global_shader_parameter_set("bloom", smoothstep(0.06, 0.14, yp) * (1.0 - smoothstep(0.32, 0.42, yp)) * (1.0 - smoothstep(2.0, 8.0, w.snow_cm)))
	moon_k = (1.0 - smoothstep(0.0, 0.1, light)) * (1.0 - w.cloud) * sin(clampf(tm, 0.0, 1.0) * PI) * (1.0 - under)
	RenderingServer.global_shader_parameter_set("frost", w.frost(clock))
	RenderingServer.global_shader_parameter_set("wet", clampf(maxf(w.rain() * 1.5, w.damp * 0.8), 0.0, 1.0))
	RenderingServer.global_shader_parameter_set("rain_k", w.rain())
	RenderingServer.global_shader_parameter_set("fish_rise", (exp(-pow((h - 6.8) / 1.2, 2.0)) + exp(-pow((h - 19.8) / 1.2, 2.0))) * (1.0 - w.precip * 0.7))
	RenderingServer.global_shader_parameter_set("sun_sx", lerpf(0.08, 0.92, t))
	RenderingServer.global_shader_parameter_set("moon_sx", lerpf(0.1, 0.9, tm))
	RenderingServer.global_shader_parameter_set("moon_a", (1.0 - smoothstep(0.0, 0.1, light)) * (1.0 - w.cloud) * sin(clampf(tm, 0.0, 1.0) * PI))
	sky.set_shader_parameter("moon_uv", Vector2(lerpf(0.1, 0.9, tm), 0.7 - sin(clampf(tm, 0.0, 1.0) * PI) * 0.55))
	sky.set_shader_parameter("moon_alpha", 1.0 - smoothstep(0.0, 0.1, light))
	sky.set_shader_parameter("stars", 1.0 - smoothstep(0.0, 0.12, light))
	sky.set_shader_parameter("rainbow", w.rainbow(clock) * (1.0 - under))
	var summer_pm := smoothstep(0.22, 0.28, yp) * (1.0 - smoothstep(0.47, 0.53, yp)) * smoothstep(12.0, 14.5, h) * (1.0 - smoothstep(19.0, 20.5, h))
	sky.set_shader_parameter("towers", maxf(summer_pm * 0.7 * (1.0 - smoothstep(0.6, 0.85, w.cloud)), 1.0 if w.thunder_far() and not w.thunderstorm() else 0.0))
	var aurora_night := force_aurora or hash([clock.day(), "aurora"]) % 3 == 0 and clock.season() == 3 and (h > 21.0 or h < 4.5)
	_aurora = 1.0 if force_aurora else move_toward(_aurora, 1.0 if aurora_night else 0.0, get_process_delta_time() * 0.1)
	sky.set_shader_parameter("aurora", _aurora * (1.0 - w.cloud))

	var morning := exp(-pow((h - 6.5) / 1.8, 2.0))
	backdrop.fog_material.set_shader_parameter("density", 0.12 + 0.55 * morning + 0.3 * w.precip + 0.9 * bz + 1.2 * w.fog)
	if shimmer and p:
		var heat: float = smoothstep(22.0, 30.0, p.air_c()) * sun_k * HOT.get(Terrain.biome(p.global_position.x), 0.0) * (1.0 - w.precip)
		shimmer.visible = heat > 0.02
		if shimmer.visible:
			(shimmer.material as ShaderMaterial).set_shader_parameter("amount", heat)
	if beams and p:
		var vp := get_viewport()
		var view := vp.get_visible_rect().size
		beams.set_shader_parameter("view", view)
		var sun_uv: Vector2 = sky.get_shader_parameter("sun_uv")
		beams.set_shader_parameter("sun", sun_uv * view)
		var low := smoothstep(0.3, 0.7, sun_uv.y) # low in the sky: long beams
		AirLife.beams = low * float(sky.get_shader_parameter("sun_alpha")) * (1.0 - w.cloud) * (1.0 - under) * BEAMS.get(Terrain.biome(p.global_position.x), 0.3)
		beams.set_shader_parameter("rays", low * float(sky.get_shader_parameter("sun_alpha")) * (1.0 - w.cloud) * (1.0 - under) * BEAMS.get(Terrain.biome(p.global_position.x), 0.3) * (1.0 + fog))
		beams.set_shader_parameter("ray_col", (c[3] as Color).lerp(Color(1, 0.95, 0.8), 0.3))
		beams.set_shader_parameter("vignette", 0.3)
		beams.set_shader_parameter("scroll", -vp.get_canvas_transform().origin)
		var sunlit := smoothstep(-0.03, 0.08, t) * smoothstep(1.03, 0.92, t) * (1.0 - under) # the sun's up, clouds or no
		beams.set_shader_parameter("cloud_shade", sunlit * smoothstep(0.15, 0.4, w.cloud) * (1.0 - smoothstep(0.7, 0.92, w.cloud))) # broken cloud: patches of shadow
	if veil and p:
		var vp := get_viewport()
		var ct := vp.get_canvas_transform()
		veil.set_shader_parameter("center", ct * (p.global_position + Vector2(0, -80)))
		veil.set_shader_parameter("view", vp.get_visible_rect().size)
		veil.set_shader_parameter("scroll", -ct.origin)
		veil.set_shader_parameter("fog", fog)
		veil.set_shader_parameter("snow", bz * (1.0 - under) * (0.5 if p.world.sheltered_at(p.global_position.x) else 1.0))
		veil.set_shader_parameter("wind_dir", float(w.wind_dir))
		var dim := lerpf(0.22, 1.0, light) * lerpf(1.0, 0.8, w.cloud)
		veil.set_shader_parameter("fog_color", Color(0.8, 0.82, 0.83) * dim + Color(0.02, 0.02, 0.03))
		veil.set_shader_parameter("snow_color", Color(0.9, 0.92, 0.95) * dim + Color(0.03, 0.03, 0.04))
	rain.set_weather(w.rain() * (1.0 - under), w.snowfall() * (1.0 - under), w.wind)
