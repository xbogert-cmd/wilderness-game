class_name Backdrop extends Node2D
## Depth layers around the gameplay plane (scroll scale 1.0).
## A layer with scroll scale s keeps local x = world_x * s aligned under the camera, so
## creek pieces placed at CREEK_X * s in every layer line up into one watercourse that
## recedes into the distance and comes toward the viewer.

const FEET_BELOW_CENTER := 250.0 ## where the player's feet sit on screen (px below centre)
const DEPTH_RISE := 350.0 ## how far up the screen the horizon of a layer at s=0 sits
const FOG_SHADER := preload("res://game/world/fog.gdshader")
## Flowing water (creeks and the river) runs off into the distance in every layer.
static func _flowing() -> Array:
	return Terrain.WATERS.filter(func(w): return w.kind in ["creek", "river"])

var camera: Camera2D
var player: Node2D
var layers: Array[Dictionary] = []
var fg_items: Array[Node2D] = []
var fog_material: ShaderMaterial
var _far_tower: Node2D ## the lookout as a far silhouette; fades as the real one comes near
var _far_lights: Node2D ## the lights over the eastern skyline, some nights
var _ref_cy := 0.0
var _rng := RandomNumberGenerator.new()

func build(terrain: Terrain, cam: Camera2D, focus: Node2D) -> void:
	camera = cam
	player = focus
	_rng.seed = World.WORLD_SEED
	_ref_cy = terrain.bank_y - FEET_BELOW_CENTER
	_add_layer(0.02, 0.02, -61, 0.0, _light_layer)
	_add_layer(0.1, 0.1, -60, 0.55, _mountains)
	_add_layer(0.35, 0.35, -50, 0.4, _forest.bind(0.6))
	_add_layer(0.6, 0.6, -40, 0.25, _forest.bind(0.85))
	_add_layer(0.72, 0.72, -35, 0.0, _fog)
	_add_layer(0.85, 0.85, -30, 0.1, _forest.bind(1.0))
	_add_layer(1.25, 0.0, 20, 0.0, _foreground, 500.0)

func _add_layer(s: float, sy: float, z: int, haze: float, fill: Callable, screen_y := NAN) -> void:
	var node := Node2D.new()
	node.z_index = z
	node.z_as_relative = false
	var ground_screen := screen_y if not is_nan(screen_y) else FEET_BELOW_CENTER - DEPTH_RISE * (1.0 - s)
	add_child(node)
	layers.append({"node": node, "s": s, "sy": sy, "bias": ground_screen + sy * _ref_cy})
	fill.call(node, s, SceneryArt.material(haze, 4.0 * s))

func _process(delta: float) -> void:
	var c := camera.get_screen_center_position()
	for l in layers:
		l.node.position = Vector2(c.x * (1.0 - l.s), c.y * (1.0 - l.sy) + l.bias)
	_fade_foreground(delta)
	var fg: Node2D = layers[-1].node # the near foreground makes no sense in a wide view: let it go
	fg.modulate.a = move_toward(fg.modulate.a, 0.0 if camera.zoom.x < 0.75 else 1.0, delta * 1.5)
	if _far_tower:
		_far_tower.modulate.a = 1.0 - smoothstep(Terrain.RIDGE_X - 8000.0, Terrain.RIDGE_X - 3000.0, c.x)
	_lights(delta, c.x)

## After dark, from the ridge or anywhere east of it: pale lights drifting low along the far
## skyline, past the edge of the map. Not every night, and never for long.
func _lights(delta: float, cx: float) -> void:
	if _far_lights == null:
		return
	var clock := GameClock.clock
	var night := clock.daylight() < 0.05 and GameClock.weather.cloud < 0.7
	var tonight := hash([clock.day(), "lights"]) % 3 != 0 # two nights in three
	var h := clock.hour_of_day()
	var want := 1.0 if night and tonight and (h > 22.0 or h < 3.0) and cx > Terrain.RIDGE_X - 4000.0 else 0.0
	_far_lights.modulate.a = move_toward(_far_lights.modulate.a, want, delta * (0.15 if Engine.get_frames_drawn() > 400 else 5.0)) # (already there if you arrive at night)
	_far_lights.visible = _far_lights.modulate.a > 0.01
	if _far_lights.visible:
		var t := Time.get_ticks_msec() / 1000.0
		for i in _far_lights.get_child_count():
			var l: Node2D = _far_lights.get_child(i)
			l.position.x = l.get_meta("x0") + sin(t * 0.05 + i * 1.7) * 60.0
			l.position.y = l.get_meta("y0") + sin(t * 0.13 + i) * 8.0
			l.modulate.a = 0.6 + 0.4 * sin(t * (0.7 + i * 0.3))
		if cx > Terrain.RIDGE_X - 3000.0 and _far_lights.modulate.a > 0.5:
			Journal.note("lights_seen", "Saw them myself tonight: pale lights low along the skyline, far to the east, past the basin. Moving slow, together. Not fire, not stars. The keeper and the pilot weren't imagining things.")

func _fade_foreground(delta: float) -> void:
	var p := player.get_global_transform_with_canvas().origin
	var zoom := camera.zoom.x
	for item in fg_items:
		var o := item.get_global_transform_with_canvas().origin
		var hw: float = item.get_meta("half_w") * zoom
		var top: float = o.y - float(item.get_meta("height")) * zoom
		var covers := absf(o.x - p.x) < hw + 50.0 and top < p.y - 60.0 * zoom
		item.modulate.a = move_toward(item.modulate.a, 0.22 if covers else 1.0, delta * 2.5)

func _span(s: float) -> Vector2:
	return Vector2(Terrain.WORLD_MIN * s - 1800.0, Terrain.WORLD_MAX * s + 1800.0)

func _hills(s: float, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = int(s * 1000) + World.WORLD_SEED
	n.frequency = freq
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return n

func _ground_line(s: float, n: FastNoiseLite, amp: float, x: float) -> float:
	var fade := 1.0
	for w in _flowing():
		var cw: float = 2.0 * w.half
		fade = minf(fade, smoothstep(cw * s, cw * s + 900.0 * s, absf(x - w.x * s)))
	return n.get_noise_1d(x) * amp * fade

# --- Layers ------------------------------------------------------------------

func _mountains(node: Node2D, s: float, mat: Material) -> void:
	var span := _span(s)
	var n := _hills(s, 1.0 / 420.0)
	n.fractal_octaves = 4
	var back := PackedVector2Array()
	var front := PackedVector2Array()
	var peak := Vector2(0, 0)
	var x := span.x
	while x <= span.y:
		var yb := -260.0 - absf(n.get_noise_1d(x * 0.7 + 5000.0)) * 420.0
		var yf := -120.0 - absf(n.get_noise_1d(x)) * 330.0
		back.append(Vector2(x, yb))
		front.append(Vector2(x, yf))
		if absf(x - Terrain.LOOKOUT_X * s) < 400.0 and yf < peak.y: # the highest point near the real lookout
			peak = Vector2(x, yf)
		x += 30.0
	for ridge in [[back, Palette.MOUNTAIN.lightened(0.18)], [front, Palette.MOUNTAIN]]:
		var pts: PackedVector2Array = ridge[0].duplicate()
		pts.append(Vector2(span.y, 3000))
		pts.append(Vector2(span.x, 3000))
		node.add_child(SceneryArt.poly(pts, ridge[1], mat))
		var cap := PackedVector2Array([Vector2(span.x, -2000), Vector2(span.y, -2000), Vector2(span.y, -330), Vector2(span.x, -330)])
		for snow in Geometry2D.intersect_polygons(pts, cap):
			node.add_child(SceneryArt.poly(snow, Palette.SNOW, mat))
	# The fire lookout on the far eastern ridge: a soft long-term goal visible from the valley.
	var tower := Node2D.new()
	tower.position = peak + Vector2(0, 4)
	var c := Palette.BARK_DARK
	tower.add_child(SceneryArt.poly(PackedVector2Array([Vector2(-7, 0), Vector2(-4, 0), Vector2(-2, -26), Vector2(-5, -26)]), c, mat))
	tower.add_child(SceneryArt.poly(PackedVector2Array([Vector2(4, 0), Vector2(7, 0), Vector2(5, -26), Vector2(2, -26)]), c, mat))
	tower.add_child(SceneryArt.poly(PackedVector2Array([Vector2(-7, -26), Vector2(7, -26), Vector2(7, -36), Vector2(0, -41), Vector2(-7, -36)]), c, mat))
	node.add_child(tower)
	_far_tower = tower


## The lights, on a layer so far off it barely moves: always somewhere off to the east over the
## far range, beyond the edge of the map. Each carries a small light so the night can't dim it.
func _light_layer(node: Node2D, s: float, _mat: Material) -> void:
	_far_lights = Node2D.new()
	_far_lights.modulate.a = 0.0
	_far_lights.visible = false
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	for i in 4:
		var l := Node2D.new()
		var x0 := (Terrain.WORLD_MAX - 1000.0) * s + i * 55.0
		l.set_meta("x0", x0)
		l.set_meta("y0", -345.0 - (i % 2) * 26.0)
		l.position = Vector2(x0, l.get_meta("y0"))
		for k in 3:
			l.add_child(SceneryArt.poly(SceneryArt.blob(Vector2.ZERO, 9.0 + k * 10.0, _rng, 10, 0.05), Color(0.8, 0.95, 1.0, 0.85 - k * 0.3), null))
		var glow := PointLight2D.new()
		glow.texture = tex
		glow.texture_scale = 3.0
		glow.color = Color(0.75, 0.92, 1.0)
		glow.energy = 1.6
		l.add_child(glow)
		_far_lights.add_child(l)
	node.add_child(_far_lights)

func _forest(node: Node2D, s: float, mat: Material, s_next: float) -> void:
	var span := _span(s)
	var n := _hills(s, 1.0 / (2400.0 * s))
	var amp := 140.0 * s
	var line := PackedVector2Array()
	var x := span.x
	while x <= span.y:
		line.append(Vector2(x, _ground_line(s, n, amp, x)))
		x += 40.0
	var ground := line.duplicate()
	ground.append(Vector2(span.y, 3000))
	ground.append(Vector2(span.x, 3000))
	node.add_child(SceneryArt.poly(ground, Palette.SOIL_TOP.lerp(Palette.GRASS, 0.45).darkened(0.15), mat, 0.0, SceneryArt.GROUND))

	# Creek and river ribbons: this layer's slice of each watercourse, widening toward the next nearer layer.
	var gaps := []
	for wd in _flowing():
		var cx: float = wd.x * s
		var w_far: float = 2.0 * wd.half * s * s
		var w_near: float = 2.0 * wd.half * s_next * s_next
		var strip := DEPTH_RISE * (s_next - s) + 20.0
		node.add_child(SceneryArt.poly(PackedVector2Array([
			Vector2(cx - w_far * 0.5, -2), Vector2(cx + w_far * 0.5, -2),
			Vector2(cx + w_near * 0.5, strip), Vector2(cx - w_near * 0.5, strip)]), Palette.WATER.lerp(Palette.WATER_LIGHT, 0.35), mat, 0.0, SceneryArt.WATER))
		gaps.append([cx, w_far * 0.5 + 60.0 * s])
	for wd in Terrain.WATERS: # ponds and the tarn: open water in the near layers, no trees standing in it
		if wd.kind in ["creek", "river"] or s < 0.5:
			continue
		var cx: float = wd.x * s
		var hw: float = wd.half * s * 1.3
		node.add_child(SceneryArt.poly(PackedVector2Array([Vector2(cx - hw, -1), Vector2(cx + hw, -1), Vector2(cx + hw * 0.9, 14), Vector2(cx - hw * 0.9, 14)]),
			Palette.WATER.lerp(Palette.WATER_LIGHT, 0.35), mat, 0.0, SceneryArt.WATER))
		gaps.append([cx, hw + 80.0 * s])

	var h_min := 1100.0 * s * s
	var h_max := 1700.0 * s * s
	var gap := 220.0 * s
	x = span.x
	while x < span.y:
		if not gaps.any(func(g): return absf(x - g[0]) < g[1]):
			var roll := _rng.randf()
			var tree: Node2D
			var detail := s > 0.5
			var fh := Terrain.foothills(x / s) # the same thinning east as the gameplay plane
			var b := Terrain.biome(x / s)
			if b == "burn" and roll < 0.75:
				tree = SceneryArt.snag(_rng, _rng.randf_range(h_min, h_max) * 0.8, mat)
			elif (b == "sage" or b == "marsh") and roll < 0.85:
				tree = SceneryArt.bush(_rng, _rng.randf_range(80.0, 160.0) * s, Color("7f8a62") if b == "sage" else Color("6f7f45"), mat)
			elif b == "sage": # junipers: short and dark
				tree = SceneryArt.conifer(_rng, _rng.randf_range(h_min, h_max) * 0.35, Color("2f4a3e"), Color("2f4a3e"), Palette.BARK, mat)
			elif b == "alpine" and roll < 0.5:
				tree = SceneryArt.rock(_rng, _rng.randf_range(120.0, 300.0) * s, mat)
			elif roll > 0.9 - 0.2 * fh:
				tree = SceneryArt.rock(_rng, _rng.randf_range(90.0, 260.0) * s, mat) if fh > 0.5 else SceneryArt.bush(_rng, 160.0 * s, Palette.BUSH, mat)
			elif roll < 0.6:
				tree = SceneryArt.conifer(_rng, _rng.randf_range(h_min, h_max), Palette.FIR_DARK, Palette.FIR_LIGHT if detail else Palette.FIR_DARK, Palette.BARK, mat)
			elif roll < 0.9:
				tree = SceneryArt.broadleaf(_rng, _rng.randf_range(h_min, h_max) * 0.7, Palette.ASPEN_LEAF_DARK, Palette.ASPEN_LEAF_LIGHT if detail else Palette.ASPEN_LEAF_DARK, Palette.ASPEN_BARK, mat)
			tree.position = Vector2(x, _ground_line(s, n, amp, x) + 3.0)
			node.add_child(tree)
		x += _rng.randf_range(gap * 0.35, gap * 1.3)

func _fog(node: Node2D, s: float, _mat: Material) -> void:
	var span := _span(s)
	var rect := ColorRect.new()
	rect.position = Vector2(span.x, -700)
	rect.size = Vector2(span.y - span.x, 950)
	fog_material = ShaderMaterial.new()
	fog_material.shader = FOG_SHADER
	rect.material = fog_material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(rect)

func _foreground(node: Node2D, s: float, _mat: Material) -> void:
	var span := _span(s)
	var mat := SceneryArt.material(0.0, 10.0)
	var line := PackedVector2Array()
	var x := span.x
	while x <= span.y:
		line.append(Vector2(x, -_rng.randf_range(0, 18)))
		x += 60.0
	var ground := line.duplicate()
	ground.append(Vector2(span.y, 2000))
	ground.append(Vector2(span.x, 2000))
	node.add_child(SceneryArt.poly(ground, Palette.FG_DARK, mat, 0.0, SceneryArt.GROUND))
	# Near reaches of the creeks and the river, flowing out toward the viewer.
	var near := []
	for wd in _flowing():
		var cx: float = wd.x * s
		var w: float = 2.0 * wd.half * s * s
		node.add_child(SceneryArt.poly(PackedVector2Array([
			Vector2(cx - w * 0.5, -6), Vector2(cx + w * 0.5, -6),
			Vector2(cx + w * 0.8, 700), Vector2(cx - w * 0.8, 700)]), Palette.WATER.darkened(0.45), mat, 0.0, SceneryArt.WATER))
		near.append([cx, w * 0.6 + 150.0])
	x = span.x
	while x < span.y:
		x += _rng.randf_range(500, 1500)
		if near.any(func(g): return absf(x - g[0]) < g[1]):
			continue
		var item: Node2D
		if _rng.randf() < 0.35:
			var tw := _rng.randf_range(60, 130)
			item = Node2D.new()
			item.add_child(SceneryArt.poly(PackedVector2Array([Vector2(-tw * 0.55, 40), Vector2(tw * 0.55, 40), Vector2(tw * 0.42, -2600), Vector2(-tw * 0.42, -2600)]), Palette.FG_DARK, mat))
			item.set_meta("half_w", tw * 0.55)
			item.set_meta("height", 2600.0)
		else:
			var fh := _rng.randf_range(160, 320)
			item = SceneryArt.fern(_rng, fh, Palette.FG_MID, mat)
			item.set_meta("half_w", fh * 0.9)
			item.set_meta("height", fh * 0.9)
		item.position = Vector2(x, 10)
		node.add_child(item)
		fg_items.append(item)
