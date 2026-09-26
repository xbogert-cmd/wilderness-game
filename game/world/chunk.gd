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
var _trail: Polygon2D ## worn game-trail path over the ground (and over snow)

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
	if legacy():
		_scatter_trees(terrain, rng, tree_mat, low_mat, st)
	else:
		_scatter_wild(terrain, world_seed, tree_mat, low_mat, st)
	_grass(terrain, rng, low_mat, x0, x1)
	for i in Terrain.WATERS.size():
		if _contains(Terrain.WATERS[i].x):
			_creek(terrain, i)
	for lm in [[Terrain.CAVE_X, Cave], [Terrain.LOOKOUT_X, Lookout]]:
		if _contains(lm[0]):
			var n: Node2D = lm[1].new()
			n.world = world
			n.chunk_index = index
			add_child(n)
	for sx in Site.PLACES:
		if _contains(sx):
			var site := Site.new()
			site.world = world
			site.chunk_index = index
			site.kind = Site.PLACES[sx]
			site.position = Vector2(sx, terrain.height_at(sx))
			add_child(site)
	_vines(terrain, world_seed, st)
	_plants(terrain, world_seed, st)
	_snow = _snow_poly(2)
	_lip = _snow_poly(8)
	_trail = _trail_poly()

## Vine tangles on their own seed, so adding them never moved the trees of existing saves.
func _vines(terrain: Terrain, world_seed: int, st: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, index, "vines"])
	for k in 5:
		var x := index * Terrain.CHUNK_W + rng.randf_range(300.0, Terrain.CHUNK_W - 300.0)
		if _near_creek(x, 150.0) or not _open(x):
			continue
		var v := VineTangle.new()
		var id := 1000 + k # clear of the tree/bush ids in the same "picked" table
		v.setup(self, id, st.picked.get(str(id), -INF))
		v.position = Vector2(x, terrain.height_at(x) + 2.0)
		add_child(v)

## Wild plants (herbs), on their own seed. Water plants keep to the banks.
func _plants(terrain: Terrain, world_seed: int, st: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, index, "herbs"])
	for k in 8:
		var x := index * Terrain.CHUNK_W + rng.randf_range(250.0, Terrain.CHUNK_W - 250.0)
		var wet := terrain.water_index(x, 900.0) >= 0 or Terrain.marsh(x) > 0.5
		var sp := Plant.pick_for(Terrain.biome(x), wet, rng)
		if terrain.water_surface_at(x) != INF or not _open(x) or absf(x - Terrain.CAVE_X) < Terrain.CAVE_HALF or absf(x - Terrain.LOOKOUT_X) < 300.0:
			continue
		var id := 2000 + k # clear of the tree, bush and vine ids in the "picked" table
		var p := Plant.new()
		p.setup(self, id, sp, st.picked.get(str(id), -INF))
		p.position = Vector2(x, terrain.height_at(x) + 2.0)
		add_child(p)

## Dashes of packed, hoof-worn earth along each game trail crossing this chunk.
func _trail_poly() -> Polygon2D:
	var shapes := []
	var x0 := index * Terrain.CHUNK_W
	var x1 := x0 + Terrain.CHUNK_W
	for i in range(index - 1, index + 2):
		if i < Terrain.FIRST or i > Terrain.LAST:
			continue
		var t := Wildlife.trail(i)
		var a := maxf(minf(t.x, t.y), x0)
		var b := minf(maxf(t.x, t.y), x1)
		var x := a
		while x < b:
			var seg := minf(x + 70.0, b)
			if _terrain.water_surface_at(x) == INF:
				shapes.append(PackedVector2Array([Vector2(x, _terrain.height_at(x) - 3.0), Vector2(seg, _terrain.height_at(seg) - 3.0),
					Vector2(seg, _terrain.height_at(seg) + 7.0), Vector2(x, _terrain.height_at(x) + 7.0)]))
			x += 95.0
	var p := SceneryArt.multi(shapes, Palette.SOIL_TOP.lightened(0.32), null) if shapes else Polygon2D.new()
	p.z_index = 2
	add_child(p)
	return p

## Whether x lies on a game trail (for hints).
static func on_trail(x: float) -> bool:
	var i := int(floor(x / Terrain.CHUNK_W))
	for k in range(i - 1, i + 2):
		if k < Terrain.FIRST or k > Terrain.LAST:
			continue
		var t := Wildlife.trail(k)
		if x > minf(t.x, t.y) and x < maxf(t.x, t.y):
			return true
	return false

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
	_trail.position.y = -minf(cm, 60.0) if cm > 0.3 else 0.0 # trodden into the snow's surface
	_trail.color = Color(0.62, 0.68, 0.78) if cm > 2.0 else Palette.SOIL_TOP.lightened(0.32)
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
			var c: Color = r[1]
			if r[0] < 20.0: # drier, stonier topsoil going east
				c = c.lerp(Palette.ROCK.darkened(0.25), 0.45 * Terrain.foothills(p.x))
			cols.append(MUD if mud else c)
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
	return _terrain.water_index(x, margin) >= 0

## The original eight chunks keep their exact scatter (tree ids line up with older saves).
func legacy() -> bool:
	return index >= 0 and index <= 7

## Clear of the world's edges (and of where the old edges were, in the original chunks).
func _open(x: float) -> bool:
	if index == 0 and x < 400.0: return false
	if index == 7 and x > 47600.0: return false
	return Terrain.inside(x, 400.0)

func _scatter_trees(terrain: Terrain, rng: RandomNumberGenerator, mat: Material, low_mat: Material, st: Dictionary) -> void:
	var x := index * Terrain.CHUNK_W + rng.randf_range(0, 300)
	var end := (index + 1) * Terrain.CHUNK_W
	var n := 0
	while x < end:
		var clear := absf(x - Terrain.CAVE_X) < Terrain.CAVE_HALF + 250.0 or absf(x - Terrain.LOOKOUT_X) < 500.0
		if not _near_creek(x, 120.0) and not clear and _open(x):
			n += 1
			var roll := rng.randf()
			var pos := Vector2(x, terrain.height_at(x) + 6)
			# East of the valley: fewer aspens and more rock in the foothills, sparse pines on the ridge.
			var fh := Terrain.foothills(x)
			var rg := Terrain.ridge(x)
			var tree_cut := 0.75 - 0.08 * fh - 0.25 * rg
			var conifer_cut := lerpf(0.45, tree_cut - 0.07, fh)
			var bush_cut := 0.9 - 0.12 * fh - 0.1 * rg
			# Art is always generated so the rng sequence (and the rest of the chunk) stays stable.
			if roll < tree_cut:
				var conifer := roll < conifer_cut
				var h := rng.randf_range(900, 1500) if conifer else rng.randf_range(650, 1000)
				var art := SceneryArt.conifer(rng, h, Palette.FIR_DARK, Palette.FIR_LIGHT, Palette.BARK, mat) if conifer \
					else SceneryArt.broadleaf(rng, h, Palette.ASPEN_LEAF_DARK, Palette.ASPEN_LEAF_LIGHT, Palette.ASPEN_BARK, mat)
				var tree := ChoppableTree.new()
				tree.setup(self, n, h, conifer, art, st.felled.has(str(n)))
				tree.position = pos
				tree.z_index = -10
				add_child(tree)
			elif roll < bush_cut:
				var w := rng.randf_range(90, 170)
				var bush := BerryBush.new()
				bush.setup(self, n, SceneryArt.bush(rng, w, Palette.BUSH, low_mat), w, rng.randf() < 0.4, st.picked.get(str(n), -INF))
				bush.position = pos
				add_child(bush)
			else:
				var rock := SceneryArt.rock(rng, rng.randf_range(60, 150) * (1.0 + 0.9 * fh), low_mat)
				rock.position = pos
				add_child(rock)
		x += rng.randf_range(180, 520)

const GRASS_COLORS := {
	"sage": [Color("8a8a5a"), Palette.GRASS_DRY],
	"meadow": [Color("7d8a45"), Palette.GRASS_DRY],
	"marsh": [Color("5e7a3a"), Color("6f8a42")],
	"burn": [Color("6a6a3a"), Color("7a6a3a")],
	"alpine": [Color("6f7d52"), Color("8a8a5a")],
}

## Scenery for the new country, by biome. Its own rng, so it never disturbs the original chunks.
## Trees here are choppable like the valley's; the burn's snags and the reeds are scenery.
func _scatter_wild(terrain: Terrain, world_seed: int, mat: Material, low_mat: Material, st: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, index, "wild"])
	var x := index * Terrain.CHUNK_W + rng.randf_range(0, 300)
	var end := (index + 1) * Terrain.CHUNK_W
	var n := 0
	while x < end:
		var b := Terrain.biome(x)
		var pos := Vector2(x, terrain.height_at(x) + 6)
		var clear := Site.PLACES.keys().any(func(sx): return absf(x - sx) < 700.0)
		var roll := rng.randf()
		var gap := rng.randf_range(160, 480)
		if _near_creek(x, 90.0) or clear or not _open(x):
			x += gap
			continue
		n += 1
		var node: Node2D = null
		match b:
			"sage": # open flats: sagebrush, the odd juniper, rock
				if roll < 0.12:
					node = _tree(rng, n, rng.randf_range(380, 560), true, Color("2f4a3e"), Color("3f5a48"), Palette.BARK, mat, st)
				elif roll < 0.8:
					node = SceneryArt.bush(rng, rng.randf_range(50, 95), Color("8a9a7a"), low_mat)
				else:
					node = SceneryArt.rock(rng, rng.randf_range(50, 120), low_mat)
				gap *= 0.8
			"meadow": # grass, scattered aspens, berry bushes
				if roll < 0.3:
					node = _tree(rng, n, rng.randf_range(650, 950), false, Palette.ASPEN_LEAF_DARK, Palette.ASPEN_LEAF_LIGHT, Palette.ASPEN_BARK, mat, st)
				elif roll < 0.55:
					var w := rng.randf_range(90, 160)
					var bush := BerryBush.new()
					bush.setup(self, n, SceneryArt.bush(rng, w, Palette.BUSH, low_mat), w, rng.randf() < 0.5, st.picked.get(str(n), -INF))
					node = bush
				gap *= 1.3
			"marsh": # reeds and willows on wet ground
				if roll < 0.5:
					node = SceneryArt.reeds(rng, rng.randf_range(80, 160), low_mat)
				elif roll < 0.85:
					node = SceneryArt.bush(rng, rng.randf_range(110, 190), Color("7a8a4a"), low_mat) # willow
				else:
					node = _tree(rng, n, rng.randf_range(600, 850), false, Color("7a8c4a"), Color("93a45a"), Color("b8b0a0"), mat, st)
			"river": # cottonwoods, willows, some fir
				if roll < 0.35:
					node = _tree(rng, n, rng.randf_range(1000, 1500), false, Color("6f8a45"), Color("8a9e55"), Color("a8a090"), mat, st) # cottonwood
				elif roll < 0.6:
					node = _tree(rng, n, rng.randf_range(900, 1400), true, Palette.FIR_DARK, Palette.FIR_LIGHT, Palette.BARK, mat, st)
				elif roll < 0.9:
					node = SceneryArt.bush(rng, rng.randf_range(100, 170), Color("7a8a4a"), low_mat)
				else:
					node = SceneryArt.rock(rng, rng.randf_range(60, 130), low_mat)
			"valley": # the western approach looks like home
				if roll < 0.45:
					node = _tree(rng, n, rng.randf_range(900, 1500), true, Palette.FIR_DARK, Palette.FIR_LIGHT, Palette.BARK, mat, st)
				elif roll < 0.7:
					node = _tree(rng, n, rng.randf_range(650, 1000), false, Palette.ASPEN_LEAF_DARK, Palette.ASPEN_LEAF_LIGHT, Palette.ASPEN_BARK, mat, st)
				elif roll < 0.9:
					var w := rng.randf_range(90, 170)
					var bush := BerryBush.new()
					bush.setup(self, n, SceneryArt.bush(rng, w, Palette.BUSH, low_mat), w, rng.randf() < 0.4, st.picked.get(str(n), -INF))
					node = bush
				else:
					node = SceneryArt.rock(rng, rng.randf_range(60, 150), low_mat)
			"ridge", "burn": # standing dead, fireweed, rock, a few young pines coming back
				if roll < 0.45:
					node = SceneryArt.snag(rng, rng.randf_range(700, 1300), mat)
					node.z_index = -10
				elif roll < 0.7:
					node = SceneryArt.fireweed(rng, rng.randf_range(60, 120), low_mat)
				elif roll < 0.82:
					node = _tree(rng, n, rng.randf_range(420, 700), true, Palette.PINE_DARK, Palette.FIR_LIGHT, Palette.BARK, mat, st)
				else:
					node = SceneryArt.rock(rng, rng.randf_range(80, 200), low_mat)
			"alpine": # krummholz, boulders
				if roll < 0.35:
					node = _tree(rng, n, rng.randf_range(300, 520), true, Color("2a4032"), Color("3a5540"), Palette.BARK, mat, st)
				elif roll < 0.75:
					node = SceneryArt.rock(rng, rng.randf_range(90, 240), low_mat)
				gap *= 1.2
		if node:
			if node.position == Vector2.ZERO:
				node.position = pos
			add_child(node)
		x += gap

func _tree(rng: RandomNumberGenerator, n: int, h: float, conifer: bool, dark: Color, light: Color, bark: Color, mat: Material, st: Dictionary) -> ChoppableTree:
	var art := SceneryArt.conifer(rng, h, dark, light, bark, mat) if conifer else SceneryArt.broadleaf(rng, h, dark, light, bark, mat)
	var tree := ChoppableTree.new()
	tree.setup(self, n, h, conifer, art, st.felled.has(str(n)))
	tree.z_index = -10
	return tree

func _grass(terrain: Terrain, rng: RandomNumberGenerator, mat: Material, x0: float, x1: float) -> void:
	var back_x := PackedFloat32Array()
	var back_y := PackedFloat32Array()
	var front_x := PackedFloat32Array()
	var front_y := PackedFloat32Array()
	var x := x0
	var cols: Array = GRASS_COLORS.get(Terrain.biome((x0 + x1) * 0.5), [Palette.GRASS, Palette.GRASS_DRY]) if not legacy() else [Palette.GRASS, Palette.GRASS_DRY]
	while x < x1:
		if terrain.water_surface_at(x) == INF:
			if terrain.soft_at(x) and Terrain.marsh(x) < 0.5 and rng.randf() < 0.85:
				pass # bare mud (the marsh is all sedge and grass instead)
			elif not legacy() and Terrain.biome(x) == "burn" and rng.randf() < 0.5:
				pass # burnt ground, only patchy regrowth
			elif rng.randf() < 0.7:
				back_x.append(x); back_y.append(terrain.height_at(x))
			elif rng.randf() < 0.5:
				front_x.append(x); front_y.append(terrain.height_at(x) + 3)
		x += rng.randf_range(10, 34)
	var back := SceneryArt.grass(rng, back_x, back_y, 26.0, cols[0], mat)
	back.z_index = 2
	add_child(back)
	var front := SceneryArt.grass(rng, front_x, front_y, 20.0, cols[1], mat)
	front.z_index = 8 # in front of the player's boots
	add_child(front)
	_grass_nodes = [back, front]

func _creek(terrain: Terrain, i: int) -> void:
	var wd: Dictionary = Terrain.WATERS[i]
	var s := terrain.surface_of(i)
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var x: float = wd.x - wd.half
	while x <= wd.x + wd.half:
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
	creek.index = i
	add_child(creek)
