class_name Waterfall extends Node2D
## The falls below the basin rim: the tarn's outlet pours over a cliff just behind the
## gameplay plane into the Falls Pool, which you can wade, drink from and fish. The cliff and
## the falling water sit behind everything; spray drifts across in front.

const LIP := -1150.0 ## where the water leaves the cliff, above the pool
const HALF := 70.0 ## half-width of the falling water at the lip

var terrain: Terrain
var _mist: CPUParticles2D
var _t := 0.0
var _rocks: Array = [] ## the cliff, worked out once: [polygon, colour]

func _ready() -> void:
	var i := terrain.water_index(Terrain.FALLS_X)
	position = Vector2(Terrain.FALLS_X, terrain.surface_of(i, false))
	z_as_relative = false
	z_index = -14 # behind the trees along the plane
	_mist = CPUParticles2D.new()
	_mist.amount = 40
	_mist.lifetime = 3.0
	_mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_mist.emission_rect_extents = Vector2(140, 10)
	_mist.direction = Vector2(0, -1)
	_mist.spread = 60.0
	_mist.initial_velocity_min = 30.0
	_mist.initial_velocity_max = 90.0
	_mist.gravity = Vector2(20, -10)
	_mist.scale_amount_min = 0.5
	_mist.scale_amount_max = 1.4
	_mist.color = Color(0.92, 0.95, 1.0, 0.22)
	_mist.texture = Underground.light_texture() # soft round puffs
	_mist.z_as_relative = false
	_mist.z_index = 6 # spray drifts in front of you at the pool
	_mist.position = Vector2(0, -10)
	add_child(_mist)
	add_to_group("landmark")

func _process(delta: float) -> void:
	_t += delta
	var frozen := GameClock.weather.ice > 0.85
	_mist.emitting = not frozen
	var cam := get_viewport().get_camera_2d()
	if cam and absf(cam.get_screen_center_position().x - global_position.x) < 2600.0:
		queue_redraw()
	var p: Player = get_tree().get_first_node_in_group("player")
	if p and absf(p.global_position.x - global_position.x) < 900.0:
		Journal.note("falls", "The tarn's outlet goes over the basin rim in a long white fall into a deep pool. Below it the country drops into big timber, dark and wet.")

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	# The cliff: a ragged wall of dark rock with ledges, wet near the water.
	var cliff := PackedVector2Array([Vector2(-760, 1600)]) # down behind the ground: no edge shows below the pool
	for k in 13:
		var x := -700.0 + k * 115.0
		cliff.append(Vector2(x, LIP - 140.0 - absf(sin(k * 1.7)) * 220.0 + rng.randf_range(-40, 40) + absf(x) * 0.25))
	cliff.append(Vector2(760, 1600))
	if _rocks.is_empty():
		_build_rocks(cliff, rng)
		_rocks = _rocks.filter(func(r): return not Geometry2D.triangulate_polygon(r[0]).is_empty()) # (slivers from the clipping)
	for r in _rocks:
		draw_colored_polygon(r[0], r[1])
	draw_colored_polygon(PackedVector2Array([Vector2(-HALF - 50, LIP), Vector2(HALF + 50, LIP), Vector2(HALF + 110, 20), Vector2(-HALF - 110, 20)]), Color("2e3634")) # wet rock
	var frozen := GameClock.weather.ice > 0.85
	var sheet := Color(0.85, 0.92, 0.96, 0.95) if not frozen else Color(0.82, 0.9, 0.96)
	draw_colored_polygon(PackedVector2Array([Vector2(-HALF, LIP), Vector2(HALF, LIP), Vector2(HALF + 45, 0), Vector2(-HALF - 45, 0)]), Color(sheet, 0.75))
	if frozen: # hung up in icicles
		for k in 12:
			var x := -HALF + k * 12.0
			draw_line(Vector2(x, LIP), Vector2(x * 1.3, -rng.randf_range(40, 300)), Color(0.7, 0.8, 0.9), 5.0)
		return
	for k in 16: # streaks racing down
		var x := -HALF + 6.0 + k * (HALF * 2.0 - 12.0) / 15.0
		var speed := 900.0 + (k * 37 % 5) * 90.0
		var phase := fposmod(_t * speed + k * 211.0, 260.0)
		var y := LIP + phase
		while y < 0.0:
			var t := (y - LIP) / -LIP
			draw_line(Vector2(x * (1.0 + t * 0.6), y), Vector2(x * (1.0 + t * 0.6), minf(y + 90.0, 0.0)), Color(1, 1, 1, 0.55), 3.0)
			y += 260.0
	draw_colored_polygon(Transform2D(0.0, Vector2(1, 0.3), 0.0, Vector2(0, -6)) * SceneryArt.blob(Vector2.ZERO, 170.0, rng, 12, 0.2), Color(1, 1, 1, 0.55)) # the churn where it lands
	for k in 7:
		var r := 90.0 + k * 38.0
		var at := Vector2(sin(_t * 0.4 + k) * 60.0 + (k - 3) * 55.0, -60.0 - k * 45.0 - sin(_t * 0.7 + k * 2.0) * 20.0)
		for j in 5: # soft: rings of fainter white
			draw_circle(at, r * (1.0 - j * 0.16), Color(1, 1, 1, 0.022))
	var sun := Atmosphere.sun_k
	if sun > 0.25 and GameClock.weather.precip < 0.2:
		var bands := [Color(0.9, 0.3, 0.3), Color(0.95, 0.65, 0.25), Color(0.95, 0.9, 0.35), Color(0.4, 0.8, 0.4), Color(0.35, 0.55, 0.9), Color(0.55, 0.4, 0.8)]
		for k in bands.size():
			draw_arc(Vector2(40, 60), 330.0 - k * 9.0, PI * 1.1, PI * 1.62, 32, Color(bands[k], 0.16 * (sun - 0.25) / 0.75 + 0.05), 9.0)

## The cliff steps down into rocky shoulders on both sides and a slope of fallen
## rock at its foot, with forest along the rim, so it sits in the land rather than standing in it
## like a wall; its face broken into blocks and ledges, lit on one side, dark in the cracks,
## streaked black where the water runs, mossy low down in the spray.
func _build_rocks(top: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	var rock := Color("4a4a48")
	var outline := PackedVector2Array()
	for side in [-1.0, 1.0]: # the shoulders: ledges stepping down and out to the ground
		var pts := PackedVector2Array()
		var x := 700.0
		var y := LIP - 140.0 + 700.0 * 0.25
		while y < 60.0: # a steep drop, then a ledge, down to the ground within a few hundred px
			pts.append(Vector2(side * x, y))
			x += rng.randf_range(20.0, 60.0)
			y += rng.randf_range(150.0, 260.0)
			pts.append(Vector2(side * x, y - rng.randf_range(20.0, 50.0)))
			x += rng.randf_range(50.0, 110.0)
		pts.append(Vector2(side * x, 60.0))
		if side < 0.0:
			pts.reverse()
			outline.append(Vector2(pts[0].x, 1600.0))
			outline.append_array(pts)
			for k in range(1, top.size() - 1):
				outline.append(top[k])
		else:
			outline.append_array(pts)
			outline.append(Vector2(pts[-1].x, 1600.0))
	if Geometry2D.triangulate_polygon(outline).is_empty():
		push_warning("falls cliff outline doesn't triangulate")
	_rocks.append([outline, rock])
	var y := LIP - 380.0
	while y < 60.0:
		var h := rng.randf_range(60.0, 230.0)
		var x := -1500.0 + rng.randf_range(0.0, 120.0)
		var tilt := rng.randf_range(-0.12, 0.12) # the strata dip a little
		while x < 1500.0:
			var w := rng.randf_range(90.0, 210.0)
			var tl := Vector2(x, y + x * tilt + rng.randf_range(-30, 30))
			var tr := Vector2(x + w, y + (x + w) * tilt + rng.randf_range(-30, 30))
			var br := Vector2(x + w - rng.randf_range(0, 30), y + h + (x + w) * tilt + rng.randf_range(-20, 20))
			var bl := Vector2(x + rng.randf_range(0, 30), y + h + x * tilt + rng.randf_range(-20, 20))
			var block := Geometry2D.intersect_polygons(PackedVector2Array([tl, tr, br, bl]), outline)
			var shade := rng.randf_range(-0.08, 0.1)
			for b in block:
				_rocks.append([b, rock.lightened(shade) if shade > 0.0 else rock.darkened(-shade)])
			for b in Geometry2D.intersect_polygons(PackedVector2Array([tl, tl.lerp(tr, 0.35), bl.lerp(br, 0.3) + Vector2(0, -h * 0.4), bl]), outline):
				_rocks.append([b, Color(0.62, 0.6, 0.55, 0.22)]) # the lit face
			for b in Geometry2D.intersect_polygons(PackedVector2Array([tl + Vector2(0, -3), tr + Vector2(0, -3), tr + Vector2(0, 5), tl + Vector2(0, 5)]), outline):
				_rocks.append([b, Color(0.18, 0.18, 0.17)]) # the crack above
			if absf(x) < HALF + 260.0 and y > LIP - 60.0: # wet, black near the falls
				for b in block:
					_rocks.append([b, Color(0.1, 0.13, 0.13, 0.35 * (1.0 - absf(x) / (HALF + 260.0)))])
			if (y > -300.0 or absf(x) > 800.0) and rng.randf() < 0.55: # moss in the spray, and on the lower shoulders
				for b in Geometry2D.intersect_polygons(PackedVector2Array([bl + Vector2(0, -h * 0.35), br + Vector2(0, -h * 0.25), br, bl]), outline):
					_rocks.append([b, Color(0.28, 0.42, 0.24, 0.55)])
			x += w
		y += h
	# scree: fallen blocks piled at the foot of the shoulders
	for k in 26:
		var side := -1.0 if k % 2 == 0 else 1.0
		var bx := side * rng.randf_range(420.0, 1500.0)
		var r := rng.randf_range(24.0, 70.0)
		var b := Transform2D(0.0, Vector2(1.2, 0.8), 0.0, Vector2(bx, rng.randf_range(-40.0, 30.0))) * SceneryArt.blob(Vector2.ZERO, r, rng, 7, 0.25)
		_rocks.append([b, rock.lightened(rng.randf_range(-0.05, 0.15))])
		_rocks.append([Transform2D(0.0, Vector2(1.0, 0.35), 0.0, Vector2(bx - side * r * 0.2, -r * 0.35)) * SceneryArt.blob(Vector2.ZERO, r * 0.8, rng, 7, 0.2), Color(0.66, 0.64, 0.6, 0.35)])
	# the forest along the rim: a dark fringe and firs standing against the sky
	for k in range(1, outline.size() - 1):
		var a := outline[k - 1]
		var b := outline[k]
		if (b.y > LIP + 500.0 and absf(b.x) < 900.0) or absf(a.x - b.x) < 2.0 or b.y > 1000.0:
			continue
		_rocks.append([PackedVector2Array([a + Vector2(0, 6), a + Vector2(0, -14), b + Vector2(0, -14), b + Vector2(0, 6)]), Color(0.2, 0.3, 0.22)])
		if rng.randf() < 0.7 and absf(b.x) > HALF + 120.0:
			var fh := rng.randf_range(120.0, 320.0)
			var fw := fh * 0.22
			for t in 5:
				var ty := b.y - fh * t / 5.0
				var tw := fw * (1.0 - t / 5.0)
				_rocks.append([PackedVector2Array([Vector2(b.x - tw, ty + 6), Vector2(b.x + tw, ty + 6), Vector2(b.x, ty - fh * 0.3)]), Color(0.16, 0.26, 0.2)])
