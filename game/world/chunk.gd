class_name Chunk extends Node2D
## One streamed section of the gameplay plane: ground, collision, and seeded scenery.

const STEP := 40.0
const DEPTH := 2400.0
const WATER_SHADER := preload("res://game/world/water.gdshader")
const MUD := Color("3f3226")

var index := 0
var world: World
var _terrain: Terrain
var _surface: PackedVector2Array
var _snow: Polygon2D ## lying snow over the ground, behind the player
var _lip: Polygon2D ## the front edge of it, over the boots, so you wade in it
var _grass_nodes: Array[Node2D] = []

func build(terrain: Terrain, world_seed: int, st: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, index])
	var x0 := index * Terrain.CHUNK_W - STEP # overlap one step so seams never snag
	var x1 := (index + 1) * Terrain.CHUNK_W + STEP
	var surface := PackedVector2Array()
	var x := x0
	while x <= x1:
		surface.append(Vector2(x, terrain.height_at(x)))
		x += STEP
	_terrain = terrain
	_surface = surface

	var ground := surface.duplicate()
	ground.append(Vector2(x1, DEPTH))
	ground.append(Vector2(x0, DEPTH))
	var body := StaticBody2D.new()
	var shape := CollisionPolygon2D.new()
	shape.polygon = ground
	body.add_child(shape)
	add_child(body)

	var fill := Polygon2D.new()
	fill.polygon = ground
	fill.color = Palette.SOIL_DEEP
	fill.z_index = 1
	add_child(fill)
	add_child(_soil_bands(surface, terrain))

	var tree_mat := SceneryArt.material(0.0, 14.0)
	var low_mat := SceneryArt.material(0.0, 6.0)
	_scatter_trees(terrain, rng, tree_mat, low_mat, st)
	_grass(terrain, rng, low_mat, x0, x1)
	if _contains(Terrain.CREEK_X):
		_creek(terrain)
	_vines(terrain, world_seed, st)
	_snow = _snow_poly(2)
	_lip = _snow_poly(8)

## Vine tangles on their own seed, so adding them never moved the trees of existing saves.
func _vines(terrain: Terrain, world_seed: int, st: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, index, "vines"])
	for k in 5:
		var x := index * Terrain.CHUNK_W + rng.randf_range(300.0, Terrain.CHUNK_W - 300.0)
		if _near_creek(x, 150.0) or x < 400.0 or x > Terrain.WORLD_W - 400.0:
			continue
		var v := VineTangle.new()
		var id := 1000 + k # clear of the tree/bush ids in the same "picked" table
		v.setup(self, id, st.picked.get(str(id), -INF))
		v.position = Vector2(x, terrain.height_at(x) + 2.0)
		add_child(v)

func _snow_poly(z: int) -> Polygon2D:
	var p := Polygon2D.new()
	p.z_index = z
	p.visible = false
	add_child(p)
	return p

## Shows `cm` of lying snow (1 cm = 1 px at 100 px/m). Grass disappears under a real cover.
func set_snow(cm: float) -> void:
	_snow.visible = cm > 0.3
	_lip.visible = cm > 4.0
	for g in _grass_nodes:
		g.visible = cm < 10.0
	if _snow.visible:
		_band(_snow, maxf(cm, 3.0), 6.0)
	if _lip.visible:
		_band(_lip, minf(cm * 0.45, 18.0), 2.0)

func _band(p: Polygon2D, depth: float, below: float) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var bottom := PackedVector2Array()
	for s in _surface:
		var d := 0.0 if _terrain.water_surface_at(s.x) != INF else depth * (1.0 + 0.15 * sin(s.x * 0.013) + 0.08 * sin(s.x * 0.041))
		pts.append(s - Vector2(0, d))
		cols.append(Color(0.94, 0.96, 0.99))
		bottom.append(s + Vector2(0, below))
	bottom.reverse()
	for b in bottom:
		pts.append(b)
		cols.append(Color(0.74, 0.8, 0.88))
	p.polygon = pts
	p.vertex_colors = cols

## Topsoil strip that fades into deep earth, so the ground cross-section reads as depth, not a slab.
func _soil_bands(surface: PackedVector2Array, terrain: Terrain) -> Polygon2D:
	var rows := [[0.0, Palette.GRASS.darkened(0.25)], [14.0, Palette.SOIL_TOP], [90.0, Palette.SOIL_TOP.lerp(Palette.SOIL_DEEP, 0.55)], [320.0, Palette.SOIL_DEEP]]
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var polys := []
	var n := surface.size()
	for r in rows:
		for p in surface:
			pts.append(p + Vector2(0, r[0]))
			var mud: bool = r[0] < 20.0 and terrain.soft_at(p.x)
			cols.append(MUD if mud else r[1])
	for row in rows.size() - 1:
		for i in n - 1:
			var a := row * n + i
			polys.append(PackedInt32Array([a, a + 1, a + n + 1, a + n]))
	var band := Polygon2D.new()
	band.polygon = pts
	band.vertex_colors = cols
	band.polygons = polys
	band.z_index = 1
	return band

func _contains(x: float) -> bool:
	return x >= index * Terrain.CHUNK_W and x < (index + 1) * Terrain.CHUNK_W

func _near_creek(x: float, margin: float) -> bool:
	return absf(x - Terrain.CREEK_X) < Terrain.CREEK_HALF + margin

func _scatter_trees(terrain: Terrain, rng: RandomNumberGenerator, mat: Material, low_mat: Material, st: Dictionary) -> void:
	var x := index * Terrain.CHUNK_W + rng.randf_range(0, 300)
	var end := (index + 1) * Terrain.CHUNK_W
	var n := 0
	while x < end:
		if not _near_creek(x, 120.0) and x > 400.0 and x < Terrain.WORLD_W - 400.0:
			n += 1
			var roll := rng.randf()
			var pos := Vector2(x, terrain.height_at(x) + 6)
			# Art is always generated so the rng sequence (and the rest of the chunk) stays stable.
			if roll < 0.75:
				var conifer := roll < 0.45
				var h := rng.randf_range(900, 1500) if conifer else rng.randf_range(650, 1000)
				var art := SceneryArt.conifer(rng, h, Palette.FIR_DARK, Palette.FIR_LIGHT, Palette.BARK, mat) if conifer \
					else SceneryArt.broadleaf(rng, h, Palette.ASPEN_LEAF_DARK, Palette.ASPEN_LEAF_LIGHT, Palette.ASPEN_BARK, mat)
				var tree := ChoppableTree.new()
				tree.setup(self, n, h, conifer, art, st.felled.has(str(n)))
				tree.position = pos
				tree.z_index = -10
				add_child(tree)
			elif roll < 0.9:
				var w := rng.randf_range(90, 170)
				var bush := BerryBush.new()
				bush.setup(self, n, SceneryArt.bush(rng, w, Palette.BUSH, low_mat), w, rng.randf() < 0.4, st.picked.get(str(n), -INF))
				bush.position = pos
				add_child(bush)
			else:
				var rock := SceneryArt.rock(rng, rng.randf_range(60, 150), low_mat)
				rock.position = pos
				add_child(rock)
		x += rng.randf_range(180, 520)

func _grass(terrain: Terrain, rng: RandomNumberGenerator, mat: Material, x0: float, x1: float) -> void:
	var back_x := PackedFloat32Array()
	var back_y := PackedFloat32Array()
	var front_x := PackedFloat32Array()
	var front_y := PackedFloat32Array()
	var x := x0
	while x < x1:
		if terrain.water_surface_at(x) == INF:
			if terrain.soft_at(x) and rng.randf() < 0.85:
				pass # bare mud
			elif rng.randf() < 0.7:
				back_x.append(x); back_y.append(terrain.height_at(x))
			elif rng.randf() < 0.5:
				front_x.append(x); front_y.append(terrain.height_at(x) + 3)
		x += rng.randf_range(10, 34)
	var back := SceneryArt.grass(rng, back_x, back_y, 26.0, Palette.GRASS, mat)
	back.z_index = 2
	add_child(back)
	var front := SceneryArt.grass(rng, front_x, front_y, 20.0, Palette.GRASS_DRY, mat)
	front.z_index = 8 # in front of the player's boots
	add_child(front)
	_grass_nodes = [back, front]

func _creek(terrain: Terrain) -> void:
	var s := terrain.water_surface_at(Terrain.CREEK_X)
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var x := Terrain.CREEK_X - Terrain.CREEK_HALF
	while x <= Terrain.CREEK_X + Terrain.CREEK_HALF:
		if terrain.height_at(x) > s:
			top.append(Vector2(x, s))
			bottom.append(Vector2(x, terrain.height_at(x) + 2))
		x += 10.0
	bottom.reverse()
	top.append_array(bottom)
	var water := Polygon2D.new()
	water.polygon = top
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	m.set_shader_parameter("surface_y", s)
	water.material = m
	water.z_index = 7 # over the player's submerged legs
	add_child(water)
	var creek := Creek.new()
	creek.terrain = terrain
	add_child(creek)
