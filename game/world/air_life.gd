class_name AirLife extends Node2D
## Things in the air around you, by season, place and weather: leaves drifting down in autumn,
## cottonwood fluff in early summer, dust motes turning in the sunbeams, drops shaken off the
## trees after rain, and snow streaming along the ground in a hard wind. Parent to the camera;
## the particles themselves stay put in the world.

const LEAFY := ["valley", "grove", "river", "meadow", "foothills", "marsh"]
const WOODS := ["valley", "grove", "river", "foothills", "oldgrowth", "burn"]
const COTTONWOODS := ["river", "valley", "marsh", "meadow"]

static var beams := 0.0 ## how strong the sunbeams are (Atmosphere sets it)
var player: Player
var leaves: CPUParticles2D
var fluff: CPUParticles2D
var motes: CPUParticles2D
var drips: CPUParticles2D
var drift: CPUParticles2D
var _slide_t := 3.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	leaves = _emitter(45, 9.0, Vector2(1400, 30), Vector2(0, -650), 1.6, 2.4)
	leaves.texture = _leaf()
	leaves.initial_velocity_min = 10.0
	leaves.initial_velocity_max = 40.0
	leaves.angular_velocity_min = -200.0
	leaves.angular_velocity_max = 200.0
	leaves.angle_max = 360.0
	var lc := Gradient.new()
	lc.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	lc.colors = PackedColorArray([Color("d9a33a"), Color("c7752e"), Color("e0c040"), Color("a85a2a")])
	leaves.color_initial_ramp = lc
	leaves.damping_min = 8.0 # they flutter down, not drop
	leaves.damping_max = 20.0
	fluff = _emitter(60, 10.0, Vector2(1400, 400), Vector2(0, -300), 0.35, 0.6)
	fluff.color = Color(1, 1, 1, 0.8)
	motes = _emitter(70, 8.0, Vector2(1100, 450), Vector2(0, -250), 0.25, 0.45)
	motes.color = Color(1.0, 0.93, 0.7, 0.7)
	drips = _emitter(50, 0.9, Vector2(1400, 10), Vector2(0, -620), 0.8, 1.2)
	drips.texture = _streak()
	drips.color = Color(0.8, 0.88, 0.95, 0.6)
	drips.gravity = Vector2(0, 900.0)
	drips.z_index = 29
	drift = _emitter(160, 1.6, Vector2(1400, 40), Vector2(0, 230), 0.3, 0.7)
	drift.color = Color(1, 1, 1, 0.55)

## Particle shapes (8 px): a soft dot, a leaf, a falling drop.
static func _dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 8
	t.height = 8
	return t

static func _leaf() -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var u := (x - 3.5) / 3.8
			var v := (y - 3.5) / 2.2
			if u * u + v * v * (1.0 + absf(u)) < 1.0: # pointed at the ends
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)

static func _streak() -> Texture2D:
	var img := Image.create(2, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 2:
			img.set_pixel(x, y, Color(1, 1, 1, y / 8.0))
	return ImageTexture.create_from_image(img)

## Switched on or off only when it changes, and on already full (not starting from nothing).
static func _on(p: CPUParticles2D, want: bool) -> void:
	if p.emitting != want:
		p.emitting = want
		if want:
			p.restart()

func _emitter(n: int, life: float, extents: Vector2, at: Vector2, s0: float, s1: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = n
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.position = at
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 15.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = s0
	p.scale_amount_max = s1
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	p.texture = _dot()
	p.z_as_relative = false
	p.z_index = 30
	p.emitting = false
	add_child(p)
	return p

func _process(_delta: float) -> void:
	var w := GameClock.weather
	var clock := GameClock.clock
	var yp := clock.year_pos()
	var b := Terrain.biome(player.global_position.x)
	var out := player.under < 0.3
	var day := clock.daylight() > 0.3
	var wind := w.wind * w.wind_dir
	_on(leaves, out and yp > 0.52 and yp < 0.74 and b in LEAFY)
	leaves.gravity = Vector2(wind * 140.0, 60.0)
	_on(fluff, out and day and yp > 0.27 and yp < 0.4 and b in COTTONWOODS and w.precip < 0.2)
	fluff.gravity = Vector2(wind * 50.0, 3.0)
	_on(motes, out and beams > 0.12)
	motes.gravity = Vector2(0, -2.0)
	_on(drips, out and w.since_rain < 2.5 and w.precip < 0.15 and w.snow_frac < 0.5 and b in WOODS)
	_on(drift, out and w.snow_cm > 5.0 and w.wind > 0.5 and w.snowfall() < 0.4)
	drift.gravity = Vector2(wind * 700.0, -15.0)
	# a gust shakes a load of snow off a bough: it slides, drops and puffs into powder
	_slide_t -= _delta
	if _slide_t <= 0.0:
		_slide_t = _rng.randf_range(2.0, 7.0) / maxf(w.wind, 0.2)
		if out and w.snow_cm > 5.0 and w.wind > 0.3 and w.snowfall() < 0.5:
			_slide()

func _slide() -> void:
	var cx := get_viewport().get_camera_2d().get_screen_center_position().x
	var trees := get_tree().get_nodes_in_group("choppable").filter(func(t): return absf(t.global_position.x - cx) < 900.0 and t.conifer)
	if trees.is_empty():
		return
	var t: ChoppableTree = trees[_rng.randi() % trees.size()]
	var at := t.global_position + Vector2(_rng.randf_range(-0.12, 0.12) * t.height, -t.height * _rng.randf_range(0.35, 0.75))
	for fine in [false, true]: # clumps that drop, then the powder hanging after them
		var p := CPUParticles2D.new()
		p.one_shot = true
		p.explosiveness = 0.6 if not fine else 0.3
		p.amount = 14 if not fine else 40
		p.lifetime = 1.6 if not fine else 3.5
		p.local_coords = false
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(40, 10)
		p.direction = Vector2(GameClock.weather.wind_dir, 0.3)
		p.spread = 50.0
		p.initial_velocity_min = 10.0
		p.initial_velocity_max = 60.0
		p.gravity = Vector2(GameClock.weather.wind_dir * GameClock.weather.wind * (40.0 if fine else 10.0), 30.0 if fine else 700.0)
		p.damping_min = 0.0 if not fine else 20.0
		p.damping_max = 0.0 if not fine else 40.0
		p.scale_amount_min = 1.2 if not fine else 0.8
		p.scale_amount_max = 2.2 if not fine else 2.0
		p.texture = _dot()
		p.color = Color(0.96, 0.97, 1.0, 0.9 if not fine else 0.35)
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 1))
		fade.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = fade
		p.z_as_relative = false
		p.z_index = 3
		get_parent().get_parent().add_child(p) # (into the world, not the moving camera)
		p.global_position = at
		p.emitting = true
		p.finished.connect(p.queue_free)
