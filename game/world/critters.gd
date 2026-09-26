class_name Critters extends Node2D
## Small life that's just there to be seen: dragonflies hovering and darting over water on
## summer days, butterflies fluttering over the meadows and the valley. They keep near you
## and mind nothing.

const MEADOWS := ["meadow", "valley", "sage", "river", "grove", "alpine"]

var player: Player
var world: World
var _flies: Array = [] ## {p: Vector2, v: Vector2, kind: "dragonfly"/"butterfly", c: Color, t: float, home: float}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	z_as_relative = false
	z_index = 9

func _process(delta: float) -> void:
	var clock := GameClock.clock
	var w := GameClock.weather
	var yp := clock.year_pos()
	var warm := yp > 0.18 and yp < 0.55 and w.air_temp_c(clock) > 12.0 and w.precip < 0.1 and w.wind < 0.6
	var day := clock.daylight() > 0.4
	var px := player.global_position.x
	var water := world.terrain.water_index(px, 900.0)
	var want_d := 4 if warm and day and water >= 0 and Terrain.WATERS[water].kind != "spring" and player.under < 0.3 else 0
	var want_b := 5 if warm and day and Terrain.biome(px) in MEADOWS and player.under < 0.3 and water < 0 else 0
	_keep("dragonfly", want_d, water)
	_keep("butterfly", want_b, water)
	for f in _flies:
		f.t += delta
		var ground := world.terrain.height_at(f.p.x)
		if f.kind == "dragonfly": # hover, then dart
			var wd: Dictionary = Terrain.WATERS[f.home]
			var surface := world.terrain.surface_of(f.home)
			if _rng.randf() < delta * 1.2:
				f.v = Vector2(_rng.randf_range(-420, 420), _rng.randf_range(-120, 120))
			f.v = f.v.move_toward(Vector2.ZERO, delta * 500.0)
			f.p += f.v * delta
			f.p.x = clampf(f.p.x, wd.x - wd.half - 150.0, wd.x + wd.half + 150.0)
			f.p.y = clampf(f.p.y, minf(surface, ground) - 160.0, minf(surface, ground) - 15.0)
		else: # flutter along, bobbing
			f.v.x = move_toward(f.v.x, _rng.randf_range(-90, 90), delta * 60.0)
			f.p.x += f.v.x * delta
			f.p.y = ground - 70.0 - 45.0 * sin(f.t * 1.3 + f.home) - 12.0 * sin(f.t * 7.0)
			if absf(f.p.x - px) > 1400.0:
				f.p.x = px + signf(px - f.p.x) * 1300.0
	queue_redraw()

func _keep(kind: String, n: int, water: int) -> void:
	var have := _flies.filter(func(f): return f.kind == kind)
	if have.size() > n:
		_flies = _flies.filter(func(f): return f.kind != kind)
		return
	var cols := [Color("e8903a"), Color("f2e9d0"), Color("e8d24a"), Color("9ec0e8")]
	for i in n - have.size():
		var x := player.global_position.x + _rng.randf_range(-1100, 1100)
		if kind == "dragonfly":
			x = Terrain.WATERS[water].x + _rng.randf_range(-1.0, 1.0) * Terrain.WATERS[water].half
		_flies.append({"p": Vector2(x, world.terrain.height_at(x) - 80.0), "v": Vector2.ZERO, "kind": kind, "t": _rng.randf() * 10.0,
			"c": Color("3a8a8a") if kind == "dragonfly" else cols[_rng.randi() % cols.size()], "home": water if kind == "dragonfly" else _rng.randf() * TAU})

func _draw() -> void:
	for f in _flies:
		draw_set_transform(f.p, 0.0, Vector2(1.7, 1.7)) # (drawn about their own centre, bigger than life so you see them)
		f = f.duplicate()
		f.p = Vector2.ZERO
		if f.kind == "dragonfly":
			var dir := -1.0 if f.v.x < 0.0 else 1.0
			draw_line(f.p - Vector2(dir * 9.0, 0), f.p + Vector2(dir * 5.0, 0), f.c, 2.0)
			var flick := 0.35 + 0.3 * sin(f.t * 60.0)
			draw_line(f.p + Vector2(dir * 1.0, 0), f.p + Vector2(dir * -2.0, -7.0), Color(0.9, 0.95, 1.0, flick), 1.5)
			draw_line(f.p + Vector2(dir * 3.0, 0), f.p + Vector2(dir * 5.0, -6.0), Color(0.9, 0.95, 1.0, flick), 1.5)
		else:
			var flap := absf(sin(f.t * 14.0))
			draw_colored_polygon(PackedVector2Array([f.p, f.p + Vector2(-7.0, -8.0 * flap), f.p + Vector2(-5.0, 3.0)]), f.c)
			draw_colored_polygon(PackedVector2Array([f.p, f.p + Vector2(7.0, -8.0 * flap), f.p + Vector2(5.0, 3.0)]), f.c.darkened(0.15))
	draw_set_transform_matrix(Transform2D.IDENTITY)
