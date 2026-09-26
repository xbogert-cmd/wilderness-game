class_name SkyLife extends Node2D
## High over the country: skeins of geese going over in spring and autumn, calling, and a hawk
## turning slow circles on warm days. Drawn far off, in front of the mountains and behind the
## trees, so they read as distant.

var player: Player
var _geese: Array = [] ## a skein: {x, y (off the view's centre), dir, n, t}
var _hawk := {} ## {cx, cy, a, r} while one's up
var _next_geese := 40.0
var _cry := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	z_as_relative = false
	z_index = -55

func _process(delta: float) -> void:
	var clock := GameClock.clock
	var w := GameClock.weather
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	global_position = cam.get_screen_center_position()
	var yp := clock.year_pos()
	var migrating := (yp > 0.02 and yp < 0.2) or (yp > 0.55 and yp < 0.8)
	var day := clock.daylight() > 0.35 and w.precip < 0.3 and player.under < 0.3
	_next_geese -= delta
	if _next_geese <= 0.0:
		_next_geese = _rng.randf_range(60.0, 180.0)
		if migrating and day and _geese.is_empty():
			var dir := 1.0 if yp > 0.5 else -1.0 # south in autumn, back north in spring (off to the side)
			_geese.append({"x": -dir * 1300.0, "y": _rng.randf_range(-520.0, -380.0), "dir": dir, "n": _rng.randi_range(7, 15), "t": 0.0})
			Sfx.play_at(player, player.global_position + Vector2(-dir * 600.0, -400.0), Sfx.pool("geese", Sfx.takes("geese", 2)), -8.0)
	for g in _geese:
		g.t += delta
		g.x += g.dir * 140.0 * delta
	_geese = _geese.filter(func(g): return absf(g.x) < 1500.0)
	var hawk_weather := day and clock.season() in [0, 1] and w.cloud < 0.6 and w.wind < 0.6
	if hawk_weather and _hawk.is_empty() and _rng.randf() < delta / 90.0:
		_hawk = {"cx": _rng.randf_range(-600.0, 600.0), "cy": _rng.randf_range(-480.0, -320.0), "a": 0.0, "r": _rng.randf_range(90.0, 160.0), "t": 0.0}
	if not _hawk.is_empty():
		_hawk.a += delta * 0.6
		_hawk.t += delta
		_hawk.cx += 8.0 * delta
		if _hawk.t > 60.0 or not hawk_weather:
			_hawk = {}
		else:
			_cry -= delta
			if _cry <= 0.0:
				_cry = _rng.randf_range(12.0, 25.0)
				Sfx.play_at(player, player.global_position + Vector2(_hawk.cx, -300.0), Sfx.pool("hawk", Sfx.takes("hawk", 3)), -10.0)
	queue_redraw()

func _draw() -> void:
	var c := Color(0.12, 0.13, 0.15, 0.85)
	for g in _geese: # a V pointing the way they're going
		for i in g.n:
			var rank := int((i + 1) / 2.0)
			var side := 1.0 if i % 2 == 0 else -1.0
			var at := Vector2(g.x - g.dir * rank * 38.0, g.y + side * rank * 18.0 + rank * 5.0)
			var flap := sin(g.t * 6.0 + i * 0.7)
			draw_polyline(PackedVector2Array([at + Vector2(-12, -6 * flap), at, at + Vector2(12, -6 * flap)]), c, 2.4)
	if not _hawk.is_empty():
		var at := Vector2(_hawk.cx + cos(_hawk.a) * _hawk.r, _hawk.cy + sin(_hawk.a) * _hawk.r * 0.35)
		var tilt := sin(_hawk.a) * 2.0
		draw_polyline(PackedVector2Array([at + Vector2(-24, -3 + tilt), at + Vector2(-8, -5), at, at + Vector2(8, -5), at + Vector2(24, -3 - tilt)]), c, 3.2)
