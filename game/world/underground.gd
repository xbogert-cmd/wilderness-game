class_name Underground extends Node2D
## Places under the ground: the root cellar under the old homestead, a cave in the foothills,
## and the Lucky Boy mine on the canyon floor. Each is a hollow carved out of its chunk's
## ground (fixed layouts, not diggable terrain), reached through an opening you walk straight
## over like any ground (a cellar door, a fallen log across a sinkhole, planks over a shaft):
## press S standing on it (or E) to go down. Inside, ledges work the same way (walk on them,
## S to drop), ladders and ropes climb with E. It's dark down there (bring a torch or a
## lantern), out of the weather, and about the same cool temperature all year.

const PLACES := {Terrain.HOMESTEAD_X + 300.0: "cellar", Terrain.ECHO_CAVE_X: "cave", Terrain.MINE_X: "mine"}
const DIR := {"cellar": -1.0, "cave": 1.0, "mine": 1.0} ## which way the hollow runs from its opening
const NAMES := {"cellar": "the root cellar", "cave": "the cave", "mine": "the Lucky Boy mine"}
const HOLDS_C := 8.0 ## underground stays about this warm, summer or winter
const WARMTH := 0.3
const PLATFORM_LAYER := 3 ## physics layer of one-way ledges and hatches (drop through with S)

## The hollow's outline: x runs the way in from the opening (mirrored by DIR), y is down from
## the ground at the opening. Each breaks the surface at its opening, so the ground stays one piece.
const CAVITY := {
	"cellar": [[0, -60], [250, -60], [250, 0], [420, 110], [820, 110], [820, 330], [380, 330], [0, 3]],
	"cave": [[-80, -80], [260, -80], [260, 0], [560, 176], [700, 185], [850, 175], [1000, 195], [1200, 180], [1350, 195], [1480, 210],
		[1490, 600], [1480, 830], [1300, 835], [1100, 825], [970, 830], [925, 868], [795, 870], [750, 832], [640, 830], [600, 760],
		[610, 620], [800, 600], [1000, 590], [1200, 610], [1350, 600], [1350, 400], [1200, 392], [900, 402], [560, 380], [-80, 2]],
	"mine": [[-70, -80], [70, -80], [70, 470], [400, 466], [800, 474], [1250, 468], [1320, 480], [1320, 700], [900, 704], [400, 700], [-70, 700]],
}
## The way in at the surface: [from x, to x, "drop" (fall through onto what's below) or a ladder index].
const HATCH := {"cellar": [0.0, 250.0, "drop"], "cave": [-80.0, 260.0, "drop"], "mine": [-70.0, 70.0, 0]}
## Ladders and ropes: [x, top y, bottom y, where you step off at the top, at the bottom].
const LADDERS := {"cave": [[1415.0, 400.0, 830.0, 1300.0, 1330.0]], "mine": [[0.0, 0.0, 700.0, 115.0, 60.0]]}
## Ledges inside you can walk on and drop through: [from x, to x, y, ladder index or "drop"].
const LEDGES := {"cave": [[1350.0, 1480.0, 400.0, 0]]}
## Things to look at, search or use: [id, x, y].
const SPOTS := {
	"cellar": [["shelves", 690.0, 330.0], ["barrel", 470.0, 330.0]],
	"cave": [["den", 830.0, 400.0], ["tin", 690.0, 830.0], ["fossils", 640.0, 830.0], ["pool", 860.0, 835.0], ["glyphs", 1040.0, 826.0]],
	"mine": [["sign", 230.0, 0.0], ["cart", 430.0, 700.0], ["cache", 1240.0, 700.0]],
}
## Seams to break out with the axe: [id, x, y, item, pieces].
const DEPOSITS := {"cave": [["flint_a", 1180.0, 828.0, "flint", 2], ["flint_b", 1265.0, 833.0, "flint", 2]], "mine": [["coal", 1030.0, 700.0, "coal", 5]]}
## Rubble blocking a way on, cleared with the axe: [id, x, half-width, top y, bottom y].
const BLOCKS := {"mine": [["collapse", 790.0, 34.0, 470.0, 700.0]]}

var world: World
var chunk_index := 0
var kind := "cellar"
var dir := 1.0
var _cavity: PackedVector2Array ## world coordinates
var _back: Array = [] ## the hollow's back wall (the cavity below the ground surface), local
var _daylight: PointLight2D
var _spill := 0.0

# --- Geometry --------------------------------------------------------------------------

static func origin_of(x: float, terrain: Terrain) -> Vector2:
	return Vector2(x, terrain.height_at(x))

static func cavity_world(k: String, x: float, terrain: Terrain) -> PackedVector2Array:
	var o := origin_of(x, terrain)
	var out := PackedVector2Array()
	for v in CAVITY[k]:
		out.append(o + Vector2(v[0] * DIR[k], v[1]))
	return out

## The chunk's ground polygon with this hollow cut out of it.
static func carve(ground: PackedVector2Array, k: String, x: float, terrain: Terrain) -> PackedVector2Array:
	var cut := Geometry2D.clip_polygons(ground, cavity_world(k, x, terrain))
	if cut.size() != 1:
		push_warning("Underground %s: carving left %d pieces" % [k, cut.size()])
	var best := ground
	var area := -1.0
	for poly in cut:
		var a := absf(_area(poly))
		if a > area:
			area = a
			best = poly
	return best

static func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		s += p[i].cross(p[(i + 1) % p.size()])
	return s * 0.5

## Where an opening lies (so nothing grows across it): [from, to] in world x.
static func openings() -> Array:
	var out := []
	for x in PLACES:
		var k: String = PLACES[x]
		var h: Array = HATCH[k]
		var a: float = x + h[0] * DIR[k]
		var b: float = x + h[1] * DIR[k]
		out.append(Vector2(minf(a, b), maxf(a, b)))
	return out

static func in_opening(x: float, margin := 30.0) -> bool:
	for o in openings():
		if x > o.x - margin and x < o.y + margin:
			return true
	return false

func _p(v: Array) -> Vector2: ## layout coordinates to local
	return Vector2(v[0] * dir, v[1])

func _w(x: float, y: float) -> Vector2: ## layout coordinates to world
	return global_position + Vector2(x * dir, y)

## The player (feet at pos) is down in here.
func inside(pos: Vector2) -> bool:
	var q := pos + Vector2(0, -40)
	return q.y > world.terrain.height_at(q.x) + 30.0 and Geometry2D.is_point_in_polygon(q, _cavity)

## 0 at the opening, 1 once you're properly down.
func depth(pos: Vector2) -> float:
	if not inside(pos):
		return 0.0
	return clampf((pos.y - 40.0 - world.terrain.height_at(pos.x) - 30.0) / 140.0, 0.0, 1.0)

# --- Setup ---------------------------------------------------------------------------

func _ready() -> void:
	dir = DIR[kind]
	global_position = origin_of(global_position.x, world.terrain)
	_cavity = cavity_world(kind, global_position.x, world.terrain)
	add_to_group("underground")
	add_to_group("shelter")
	add_to_group("heat")
	add_to_group("landmark")
	z_as_relative = false
	z_index = 1 # over the ground's cross-section, behind everything standing in the world
	var ground := PackedVector2Array()
	var x0 := global_position.x - 1600.0
	var x := x0
	while x <= global_position.x + 1600.0:
		ground.append(Vector2(x, world.terrain.height_at(x)) - global_position)
		x += 20.0
	ground.append(Vector2(1600, 3000))
	ground.append(Vector2(-1600, 3000))
	var local := PackedVector2Array()
	for v in _cavity:
		local.append(v - global_position)
	_back = Geometry2D.intersect_polygons(local, ground)
	_build_bodies()
	_build_spots()
	_daylight = PointLight2D.new() # daylight spilling in at the opening
	_daylight.texture = light_texture()
	_daylight.texture_scale = 5.0
	_daylight.color = Color(0.9, 0.93, 1.0)
	var h: Array = HATCH[kind]
	_daylight.position = Vector2((h[0] + h[1]) * 0.5 * dir, 60.0)
	add_child(_daylight)

static func light_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	return tex

func _platform(a: Vector2, b: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1 << (PLATFORM_LAYER - 1)
	body.collision_mask = 0
	var c := CollisionShape2D.new()
	var s := SegmentShape2D.new()
	s.a = a
	s.b = b
	c.shape = s
	c.one_way_collision = true
	body.add_child(c)
	add_child(body)

func _build_bodies() -> void:
	var h: Array = HATCH[kind]
	_platform(_surface_local(h[0]), _surface_local(h[1]))
	for l in LEDGES.get(kind, []):
		_platform(_p([l[0], l[2]]), _p([l[1], l[2]]))
	for d in DEPOSITS.get(kind, []):
		if not _done(d[0]):
			var n := Deposit.new()
			n.u = self
			n.id = d[0]
			n.item = d[3]
			n.pieces = d[4]
			n.position = _p([d[1], d[2]])
			add_child(n)
	for b in BLOCKS.get(kind, []):
		if not _done(b[0]):
			var n := Block.new()
			n.u = self
			n.id = b[0]
			n.half = b[2]
			n.top = b[3] - b[4]
			n.position = _p([b[1], b[4]])
			add_child(n)

## The ground at layout x, in local coordinates (the hatch lies on the real surface).
func _surface_local(lx: float) -> Vector2:
	var wx := global_position.x + lx * dir
	return Vector2(lx * dir, world.terrain.height_at(wx) - global_position.y)

func _build_spots() -> void:
	var h: Array = HATCH[kind]
	var hatch := Spot.new()
	hatch.u = self
	hatch.id = "hatch"
	hatch.span = Vector2(minf(h[0], h[1]) * dir, maxf(h[0], h[1]) * dir)
	hatch.span = Vector2(minf(hatch.span.x, hatch.span.y), maxf(hatch.span.x, hatch.span.y))
	add_child(hatch)
	for s in SPOTS[kind]:
		var n := Spot.new()
		n.u = self
		n.id = s[0]
		n.position = _p([s[1], s[2]])
		add_child(n)
	var ladders: Array = LADDERS.get(kind, [])
	for i in ladders.size():
		var l: Array = ladders[i]
		var bottom := Spot.new()
		bottom.u = self
		bottom.id = "up_%d" % i
		bottom.position = _p([l[0], l[2]])
		add_child(bottom)
		if kind != "mine" or i != 0: # the mine's ladder top is the hatch itself
			var top := Spot.new()
			top.u = self
			top.id = "down_%d" % i
			top.position = _p([l[0], l[1]])
			add_child(top)

# --- State ---------------------------------------------------------------------------

func _key(id: String) -> String:
	if kind == "cellar" and id == "shelves":
		return "site_homestead_cellar" # searched from above, in saves before the cellar opened up
	return "under_%s_%s" % [kind, id]

func _done(id: String) -> bool:
	return world.chunk_state(chunk_index).get(_key(id), false)

func _mark(id: String) -> void:
	world.chunk_state(chunk_index)[_key(id)] = true
	queue_redraw()

# --- Going down and up ---------------------------------------------------------------

## S pressed standing somewhere: if it's on this place's hatch or one of its ledges, go down.
func descend(p: Player) -> bool:
	var h: Array = HATCH[kind]
	if _on(p, h[0], h[1], NAN):
		_go_down(p, h[2])
		return true
	for l in LEDGES.get(kind, []):
		if _on(p, l[0], l[1], l[2]):
			_go_down(p, l[3])
			return true
	return false

func _on(p: Player, a: float, b: float, y: float) -> bool:
	var lx := (p.global_position.x - global_position.x) * dir
	if lx < minf(a, b) - 10.0 or lx > maxf(a, b) + 10.0:
		return false
	var want := world.terrain.height_at(p.global_position.x) if is_nan(y) else global_position.y + y
	return absf(p.global_position.y - want) < 16.0

func _go_down(p: Player, how: Variant) -> void:
	if p.carrying or p.hauling or p.pulling:
		p.message.emit("You can't get that down there. Set it down first.")
		return
	if how is String:
		p.drop_through()
	else:
		var l: Array = LADDERS[kind][how]
		var top := _w(l[0], l[1] - 2.0) if not (kind == "mine" and how == 0) else Vector2(_w(l[0], 0).x, world.terrain.height_at(_w(l[0], 0).x) - 2.0)
		p.climb(PackedVector2Array([p.global_position, top, _w(l[0], l[2] - 2.0), _w(l[4], l[2] - 2.0)]))

func _climb_up(p: Player, i: int) -> void:
	if p.carrying or p.hauling or p.pulling:
		p.message.emit("Not with your hands full.")
		return
	var l: Array = LADDERS[kind][i]
	var top_y: float = l[1] - 4.0
	var off := _w(l[3], top_y)
	if kind == "mine" and i == 0:
		off.y = world.terrain.height_at(off.x) - 4.0
	p.climb(PackedVector2Array([p.global_position, _w(l[0], l[2] - 2.0), Vector2(_w(l[0], 0).x, off.y), off]))

# --- Shelter and warmth ----------------------------------------------------------------

func covers(_x: float) -> bool:
	var p: Player = get_tree().get_first_node_in_group("player")
	return p != null and inside(p.global_position)

func heat_at(pos: Vector2) -> float:
	if not inside(pos + Vector2(0, 60)):
		return 0.0
	var outside := GameClock.weather.air_temp_c(GameClock.clock)
	return clampf((HOLDS_C - outside) / GameClock.tuning.fire_heat_c, 0.0, WARMTH)

func _process(delta: float) -> void:
	_spill = move_toward(_spill, GameClock.clock.daylight() * (1.0 - GameClock.weather.cloud * 0.4), delta)
	_daylight.energy = 0.55 * _spill
	_daylight.visible = _spill > 0.02
	var p: Player = get_tree().get_first_node_in_group("player")
	if p and inside(p.global_position):
		match kind:
			"cellar": Journal.note("cellar", "Went down into the root cellar under the old homestead. Dry, cool and dark, shelves along the wall. A good place to wait out weather.")
			"cave": Journal.note("echo_cave", "Found a cave in the foothills: a sinkhole under a fallen log, a slope of scree down into a gallery, and a shaft going deeper. Pitch dark without a light.")
			"mine": Journal.note("mine", "Climbed down the shaft of the Lucky Boy mine on the canyon floor. Old timbers, rails, and a drift running east into the dark.")

# --- Spots ---------------------------------------------------------------------------

func _title(id: String) -> String:
	match id:
		"hatch": return NAMES[kind].capitalize()
		"shelves": return "Cellar shelves"
		"barrel": return "A barrel"
		"den": return "A hollow in the dirt"
		"tin": return "An old tin"
		"fossils": return "The rock wall"
		"pool": return "A pool"
		"glyphs": return "Marks on the rock"
		"sign": return "A weathered sign"
		"cart": return "An ore cart"
		"cache": return "A miners' cache"
	return ""

func _options(id: String, p: Player) -> Array:
	var out := []
	if id.begins_with("up_"):
		var what := "rope" if kind == "cave" else "ladder"
		out.append(["Climb the " + what, _climb_up.bind(p, int(id.substr(3)))])
		return out
	if id.begins_with("down_"):
		out.append(["Climb down the rope  (%s)" % Keys.label("move_down"), _go_down.bind(p, int(id.substr(5)))])
		return out
	match id:
		"hatch":
			var h: Array = HATCH[kind]
			var verb: String = {"cellar": "Go down the cellar steps", "cave": "Drop down under the log", "mine": "Climb down the shaft"}[kind]
			out.append(["%s  (%s)" % [verb, Keys.label("move_down")], _go_down.bind(p, h[2])])
		"shelves":
			if not _done(id):
				out.append(["Search the shelves", _search.bind(p, id)])
			else:
				var n := _shelf_store().store.entries.size()
				out.append(["Keep things on the shelves (cool: food lasts about three times as long)%s" % ("" if n == 0 else "  · %d there" % n), _open_shelves.bind(p)])
		"barrel":
			out.append(["Look in the barrel", _look.bind(p, id)])
		"den":
			out.append(["Look closer", _look.bind(p, id)])
		"tin":
			if not _done(id):
				out.append(["Open the tin", _search.bind(p, id)])
		"fossils":
			out.append(["Look at the rock", _look.bind(p, id)])
		"glyphs":
			out.append(["Look at the marks", _look.bind(p, id)])
		"pool":
			if p.held and p.held.def.capacity > 0.0:
				out.append(["Fill %s (clear, cold water)" % p.held.def.name.to_lower(), _fill.bind(p)])
			out.append(["Drink from the pool", _drink.bind(p)])
		"sign":
			out.append(["Read the sign", _look.bind(p, id)])
		"cart":
			out.append(["Look in the cart", _look.bind(p, id)])
		"cache":
			if not _done(id):
				out.append(["Search the cache", _search.bind(p, id)])
	return out

## The cellar's shelves as a store (a hidden chest that saves with the chunk), made the first
## time it's wanted.
func _shelf_store() -> StorageChest:
	var at := _w(690.0, 330.0)
	for c in get_tree().get_nodes_in_group("chest"):
		if c.variety == "shelves" and c.global_position.distance_to(at) < 300.0 and not c.is_queued_for_deletion():
			return c
	return world.spawn({"kind": "chest", "variety": "shelves", "x": at.x, "y": at.y}) as StorageChest

func _open_shelves(p: Player) -> void:
	StorageChest.open_store(self, _shelf_store().store, p)
	Journal.note("cellar_store", "The root cellar keeps cool all year, about eight degrees. Meat and fish left on its shelves last about three times as long as up top, and nothing gets at them.")

func _give(p: Player, items: Array) -> void:
	var h := GameClock.clock.hours
	for it in items:
		var s := ItemStack.make(it[0], h, it[1])
		if not p.receive(s, false):
			world.spawn({"kind": "item", "x": p.global_position.x + 30.0, "y": p.global_position.y, "stack": s.to_dict()})

func _search(p: Player, id: String) -> void:
	p.work(3.0, 0.3, "Searching", func():
		_mark(id)
		match id:
			"shelves":
				_give(p, [["tinned_beans", 2], ["preserves", 2], ["cordage", 1], ["bandage", 1]])
				p.message.emit("Behind the broken jars: two tins of beans, two jars of plum preserves still sealed, a coil of rope, a roll of bandage, and a diary.")
				Journal.note("diary_1", "Homesteader's diary, found in the root cellar. \"June 3, 1921. Lights over the east ridge again tonight, three of them, moving slow along the top like lanterns carried by someone walking. Pa says it's swamp gas. There's no swamp up there.\"")
				Journal.note("diary_2", "The diary, last page: \"Aug 30. The cattle won't graze the east end anymore. Pa went up the ridge to see for himself. He said don't come looking. I will give it three days.\"")
			"tin":
				_give(p, [["matches", 1]])
				p.message.emit("A rusted tobacco tin, pushed into a crack out of the damp: a box of matches, still dry, and a stub of candle gone to nothing.")
			"cache":
				_give(p, [["lantern", 1], ["lamp_oil", 2]])
				p.message.emit("A crate nailed shut behind the timbers: a miner's lantern, two cans of lamp oil, and the shift boss's tally book.")
				Journal.note("mine_log", "The Lucky Boy shift book: \"Sept 1921. Tunnel holding. Men won't work the night shift since the lights. Hanson swears his compass turned right around in the drift and the lamps all dimmed at once. Sept 9, walked off, the lot of them. Closing her up.\" The same autumn as the homestead diary.")
		)

func _look(p: Player, id: String) -> void:
	match id:
		"barrel":
			p.message.emit("Dry rot and mouse nests. Whatever was stored in it is long gone.")
		"den":
			if get_tree().get_nodes_in_group("predators").any(func(b): return b.den == self and b.state == Predator.State.SLEEP):
				p.message.emit("The bear fills the hollow, curled nose to paws, breathing slow and deep. Every hair on your neck says back away, quietly.")
				return
			p.message.emit("A bear's winter den: a hollow scraped in the dirt, old bedding of grass and needles, black hair caught on the rock. Nobody home.")
			Journal.note("den", "A bear dens in the cave's upper gallery in winter: a scraped hollow, bedding, black hair on the rock. Better not to be down there when it's back.")
		"fossils":
			p.message.emit("The wall is full of shells: little ribbed fans and coils, turned to stone.")
			Journal.note("fossils", "Seashells in the cave wall, turned to stone, a thousand miles from any sea. This whole country was the bottom of an ocean once.")
		"glyphs":
			p.message.emit("Figures painted in red ochre: people with raised arms under a jagged line of mountains, and above the peaks, a row of pale dots.")
			Journal.note("glyphs", "Old paintings deep in the cave: red ochre figures with their arms raised under a mountain skyline, and a row of pale dots above the peaks. Older than the homestead, older than anyone. The lights have been seen for a long, long time.")
		"sign":
			p.message.emit("LUCKY BOY MINE. NO TRESPASS. 1919. Someone has scratched underneath: CLOSED SEPT 1921.")
			Journal.note("mine_sign", "The Lucky Boy mine in the canyon: worked from 1919, closed in September 1921.")
		"cart":
			p.message.emit("An ore cart on rusted rails, half full of broken rock. Nothing worth hauling.")

func _drink(p: Player) -> void:
	p.cond.drink(ItemStack.THIRST_PER_SIP)
	p.message.emit("Ice cold, and clear as glass. Water that's come up through the rock.")

func _fill(p: Player) -> void:
	var s := p.held
	if s.water > 0.001 and not s.water_clean:
		p.message.emit("It holds dirty water. Empty it first so they don't mix.")
		return
	var took := s.add_water(s.def.capacity, true)
	p.message.emit("Filled with %.2f L of clear water." % took if took > 0.0 else "It's already full.")

# --- Drawing -------------------------------------------------------------------------

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var wall: Color = {"cellar": Color("4a3b2c"), "cave": Color("4a4640"), "mine": Color("4d3d2c")}[kind]
	for poly in _back:
		draw_colored_polygon(poly, wall)
		var rim: PackedVector2Array = poly.duplicate()
		rim.append(poly[0])
		draw_polyline(rim, Color(0.08, 0.07, 0.06), 10.0) # the rock face at the edge of the hollow
	for i in 50: # stones and roots in the walls
		var v := Vector2(rng.randf_range(-1500, 1500), rng.randf_range(0, 900))
		for poly in _back:
			if Geometry2D.is_point_in_polygon(v, poly):
				draw_colored_polygon(SceneryArt.blob(v, rng.randf_range(10, 34), rng, 7, 0.3), wall.lightened(rng.randf_range(0.04, 0.12)))
	match kind:
		"cellar": _draw_cellar()
		"cave": _draw_cave(rng)
		"mine": _draw_mine(rng)
	for l in LADDERS.get(kind, []):
		var top := _p([l[0], l[1]])
		if kind == "mine":
			top.y = -140.0 # the ladder runs up out of the collar
		var bottom := _p([l[0], l[2]])
		if kind == "cave": # a knotted rope, tied off round a rock
			draw_line(top + Vector2(0, -10), bottom, Color("a89a74"), 3.0)
			var y := top.y + 30.0
			while y < bottom.y:
				draw_circle(Vector2(top.x, y), 4.5, Color("8a7a58"))
				y += 60.0
			draw_colored_polygon(SceneryArt.blob(top + Vector2(-30 * dir, -12), 20.0, rng, 8, 0.2), Palette.ROCK.darkened(0.3))
		else:
			for side in [-16.0, 16.0]:
				draw_line(Vector2(top.x + side, top.y), Vector2(bottom.x + side, bottom.y), Color("5a4630"), 5.0)
			var y := top.y + 20.0
			while y < bottom.y:
				draw_line(Vector2(top.x - 16, y), Vector2(top.x + 16, y), Color("6a5438"), 4.0)
				y += 34.0
	_draw_hatch(rng)

func _draw_hatch(rng: RandomNumberGenerator) -> void:
	var h: Array = HATCH[kind]
	var a := _surface_local(h[0])
	var b := _surface_local(h[1])
	match kind:
		"cellar": # a low door of boards on the ground, iron strap hinges, a ring
			var n := 8
			for i in n:
				var p0 := a.lerp(b, float(i) / n)
				var p1 := a.lerp(b, float(i + 1) / n)
				draw_colored_polygon(PackedVector2Array([p0 + Vector2(1, -6), p1 + Vector2(-1, -6), p1 + Vector2(-1, 6), p0 + Vector2(1, 6)]), Color("5e4b36").darkened(0.06 * (i % 3)))
			for t in [0.2, 0.75]:
				var hp := a.lerp(b, t)
				draw_line(hp + Vector2(-50, -3), hp + Vector2(50, -3), Color("3a3632"), 4.0)
			draw_arc(a.lerp(b, 0.5) + Vector2(0, -6), 7.0, PI, TAU, 8, Color("4a4540"), 2.5)
		"cave": # a fallen spruce across the sinkhole, mossed over
			var r := 26.0
			draw_line(a + Vector2(-60 * dir, -r * 0.6), b + Vector2(50 * dir, -r * 0.6), Palette.BARK_DARK, r * 1.6)
			draw_line(a + Vector2(-60 * dir, -r * 1.1), b + Vector2(50 * dir, -r * 1.1), Color("4a5a30"), 7.0) # moss
			var end := a + Vector2(-60 * dir, -r * 0.6)
			draw_circle(end, r * 0.8, Color("8a7050"))
			draw_arc(end, r * 0.5, 0.0, TAU, 12, Color("6a5038"), 2.0)
			for k in 4: # rocks at the lips
				var at := (a if k < 2 else b) + Vector2(rng.randf_range(-40, 40), 6)
				draw_colored_polygon(SceneryArt.blob(at, rng.randf_range(14, 26), rng, 7, 0.25), Palette.ROCK.darkened(0.15))
		"mine": # planks over the collar and the headframe over the shaft
			for i in 5:
				var x := lerpf(a.x, b.x, i / 4.0)
				draw_rect(Rect2(x - 15, a.y - 6, 26, 10), Color("6a5438").darkened(0.05 * (i % 2)))
			var wood := Color("4e3d2a")
			for side in [-1.0, 1.0]:
				draw_line(Vector2(side * 150, a.y), Vector2(side * 30, a.y - 560), wood, 12.0)
			draw_line(Vector2(-110, a.y - 150), Vector2(110, a.y - 150), wood, 9.0)
			draw_line(Vector2(-70, a.y - 330), Vector2(70, a.y - 330), wood, 8.0)
			draw_line(Vector2(-150, a.y), Vector2(70, a.y - 330), wood.darkened(0.1), 6.0)
			draw_arc(Vector2(0, a.y - 575), 42.0, 0.0, TAU, 20, Color("3a3632"), 6.0) # the sheave wheel
			for k in 4:
				var ang := TAU * k / 8.0
				draw_line(Vector2(0, a.y - 575) - Vector2.from_angle(ang) * 40.0, Vector2(0, a.y - 575) + Vector2.from_angle(ang) * 40.0, Color("3a3632"), 3.0)
			draw_line(Vector2(0, a.y - 575 + 42), Vector2(0, a.y - 20), Color("5a5048"), 2.0) # frayed cable
			var sx := 230.0 * dir
			draw_line(Vector2(sx, a.y + 4), Vector2(sx, a.y - 90), wood, 6.0)
			draw_rect(Rect2(sx - 55, a.y - 120, 110, 40), Color("6a5a44"))
			draw_rect(Rect2(sx - 55, a.y - 120, 110, 40), Color("3a3024"), false, 2.0)
			for k in 3:
				draw_line(Vector2(sx - 44, a.y - 108 + k * 10), Vector2(sx + 40 - k * 16, a.y - 108 + k * 10), Color("2a241c"), 2.0)

func _draw_cellar() -> void:
	var board := Color("3e3226")
	for i in 22: # plank-lined walls in the room
		var x := (400.0 + i * 20.0) * dir
		draw_line(Vector2(x, 112), Vector2(x, 328), board.darkened(0.12 * (i % 2)), 18.0)
	for k in 3: # the ceiling joists
		draw_line(Vector2((420 + k * 170) * dir, 112), Vector2((420 + k * 170) * dir, 124), Color("2a2018"), 22.0)
	draw_line(Vector2(410 * dir, 116), Vector2(815 * dir, 116), Color("4a3a2a"), 8.0)
	var steps := 12 # plank treads down the stairs
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var p0 := Vector2(lerpf(0, 380, t0) * dir, lerpf(3, 330, t0))
		var p1 := Vector2(lerpf(0, 380, t1) * dir, lerpf(3, 330, t1))
		draw_colored_polygon(PackedVector2Array([p0, Vector2(p1.x, p0.y), p1, Vector2(p1.x, p1.y + 6), Vector2(p0.x, p0.y + 6)]), Color("5a4834"))
	for row in 2: # shelves along the far wall
		var y := 225.0 + row * 60.0
		draw_line(Vector2(600 * dir, y), Vector2(800 * dir, y), Color("5a4834"), 7.0)
		for k in 7:
			var jx := (615 + k * 27) * dir
			if _done("shelves") and k % 3 != 0:
				draw_colored_polygon(PackedVector2Array([Vector2(jx - 6, y - 4), Vector2(jx + 7, y - 4), Vector2(jx, y - 11)]), Color(0.6, 0.65, 0.6, 0.5)) # broken glass
				continue
			var c: Color = [Color("8a3a2a"), Color("b0802a"), Color("5a6a3a")][k % 3]
			draw_rect(Rect2(jx - 8, y - 26, 16, 22), Color(c, 0.85))
			draw_rect(Rect2(jx - 7, y - 30, 14, 5), Color("7a7064"))
	for side in [-1.0, 1.0]: # a barrel
		draw_line(Vector2(470 * dir + side * 30, 330), Vector2(470 * dir + side * 34, 262), Color("4a3a26"), 6.0)
	draw_colored_polygon(PackedVector2Array([Vector2(470 * dir - 30, 330), Vector2(470 * dir + 30, 330), Vector2(470 * dir + 34, 262), Vector2(470 * dir - 34, 262)]), Color("5a4630"))
	for y in [280.0, 315.0]:
		draw_line(Vector2(470 * dir - 33, y), Vector2(470 * dir + 33, y), Color("3a3632"), 3.0)

func _draw_cave(rng: RandomNumberGenerator) -> void:
	for i in 22: # stalactites hanging from the ceilings
		var x := rng.randf_range(300, 1450)
		var y := _ceiling_y(x)
		if y == INF:
			continue
		var l := rng.randf_range(14, 46)
		draw_colored_polygon(PackedVector2Array([Vector2((x - 7) * dir, y - 4), Vector2((x + 7) * dir, y - 4), Vector2(x * dir, y + l)]), Color("3a3630"))
	# The pool in the lower chamber.
	draw_colored_polygon(PackedVector2Array([Vector2(766 * dir, 845), Vector2(952 * dir, 845), Vector2(925 * dir, 868), Vector2(795 * dir, 870)]), Color(0.18, 0.3, 0.34, 0.85))
	draw_line(Vector2(766 * dir, 845), Vector2(952 * dir, 845), Color(0.5, 0.65, 0.7, 0.6), 2.0)
	# Fossil shells in the west wall.
	for k in 9:
		var c := Vector2((612 + rng.randf_range(0, 40)) * dir, rng.randf_range(650, 810))
		draw_arc(c, rng.randf_range(5, 9), PI, TAU, 8, Color("8a8070"), 2.0)
		draw_line(c, c + Vector2(0, -6), Color("8a8070"), 1.2)
	# Ochre paintings on the lower chamber's back wall: figures, mountains, and the lights.
	var g0 := Vector2(1000 * dir, 700)
	var ochre := Color("8a3a22")
	for k in 4:
		var fx := g0 + Vector2((k * 30 - 30) * dir, 60)
		draw_line(fx, fx + Vector2(0, -26), ochre, 3.0)
		draw_circle(fx + Vector2(0, -32), 5.0, ochre)
		draw_line(fx + Vector2(0, -20), fx + Vector2(-10, -34), ochre, 2.5)
		draw_line(fx + Vector2(0, -20), fx + Vector2(10, -34), ochre, 2.5)
	draw_polyline(PackedVector2Array([g0 + Vector2(-70 * dir, 10), g0 + Vector2(-30 * dir, -30), g0 + Vector2(0, -5), g0 + Vector2(40 * dir, -40), g0 + Vector2(90 * dir, 10)]), ochre, 3.0)
	for k in 4:
		draw_circle(g0 + Vector2((-45 + k * 32) * dir, -60 - (k % 2) * 8), 5.0, Color("d8d0b8"))
	# The den: scraped hollow, bedding, bones.
	draw_colored_polygon(Transform2D(0.0, Vector2(1, 0.25), 0.0, Vector2(830 * dir, 398)) * SceneryArt.blob(Vector2.ZERO, 70.0, rng, 10, 0.2), Color("4a3e2c"))
	for k in 6:
		draw_line(Vector2((780 + k * 18) * dir, 396), Vector2((795 + k * 18) * dir, 390 - (k % 2) * 4), Color("8a7a4a"), 2.0)
	draw_line(Vector2(900 * dir, 398), Vector2(940 * dir, 392), Color("d8d0bc"), 4.0)
	if not _done("tin"):
		draw_rect(Rect2(Vector2(690 * dir - 10, 818), Vector2(20, 12)), Color("7a5a3a"))

## The cave's ceiling at layout x (the gallery above, the lower chamber below): the first
## cavity edge above the floor there, walking the outline.
func _ceiling_y(lx: float) -> float:
	var ys := []
	var pts: Array = CAVITY[kind]
	for i in pts.size():
		var a: Array = pts[i]
		var b: Array = pts[(i + 1) % pts.size()]
		if (a[0] - lx) * (b[0] - lx) <= 0.0 and a[0] != b[0]:
			ys.append(lerpf(a[1], b[1], (lx - a[0]) / (b[0] - a[0])))
	ys.sort()
	return ys[0] if ys.size() >= 2 and ys[0] > 20.0 else INF

func _draw_mine(rng: RandomNumberGenerator) -> void:
	var wood := Color("4a3a28")
	var x := 140.0
	while x < 1300.0: # timber sets along the drift: two posts and a cap
		for side in [-16.0, 16.0]:
			draw_line(Vector2((x + side) * dir, 700), Vector2((x + side * 0.6) * dir, 480), wood.darkened(0.1 if side < 0 else 0.0), 12.0)
		draw_line(Vector2((x - 60) * dir, 482), Vector2((x + 60) * dir, 482), wood, 12.0)
		x += 210.0
	for y in [694.0, 698.0]: # the rails
		draw_line(Vector2(80 * dir, y), Vector2(1300 * dir, y), Color("5a5048"), 2.0)
	var c := Vector2(430 * dir, 694) # the ore cart
	draw_colored_polygon(PackedVector2Array([c + Vector2(-50, -60), c + Vector2(50, -60), c + Vector2(40, -8), c + Vector2(-40, -8)]), Color("4a4440"))
	for k in 5:
		draw_colored_polygon(SceneryArt.blob(c + Vector2(-36 + k * 18, -64), 12.0, rng, 6, 0.3), Palette.ROCK.darkened(0.2))
	for wx in [-26.0, 26.0]:
		draw_circle(c + Vector2(wx, -4), 9.0, Color("2a2622"))
	# The coal seam's black band in the wall.
	var s0 := Vector2(960 * dir, 640)
	draw_colored_polygon(PackedVector2Array([s0, s0 + Vector2(160 * dir, -12), s0 + Vector2(160 * dir, 30), s0 + Vector2(0, 40)]), Color("141312"))
	if not _done("cache"):
		draw_rect(Rect2(Vector2(1240 * dir - 30, 660), Vector2(60, 40)), Color("6a5438"))
		draw_rect(Rect2(Vector2(1240 * dir - 30, 660), Vector2(60, 40)), Color("3a2e20"), false, 2.0)
	draw_circle(Vector2(1120 * dir, 500), 6.0, Color("5a5048")) # an old lamp hook

# --- Things in here ------------------------------------------------------------------

## Something to look at, search or climb, at one spot (or along the hatch).
class Spot extends Node2D:
	var u: Underground
	var id := ""
	var span := Vector2.INF ## a stretch of x (local) instead of one spot: the hatch

	func _ready() -> void:
		add_to_group("interactable")
		add_to_group("camp") # a key popup with the choices

	func interact_pos() -> Vector2:
		if span != Vector2.INF:
			var p: Player = get_tree().get_first_node_in_group("player")
			var lx := clampf(p.global_position.x - u.global_position.x, span.x, span.y)
			return Vector2(u.global_position.x + lx, u.world.terrain.height_at(u.global_position.x + lx))
		return global_position

	func interact_title(_p: Player) -> String:
		return u._title(id)

	func interact_options(p: Player) -> Array:
		return u._options(id, p)

	func interact_label(p: Player) -> String:
		return Player.first_label(interact_options(p))

	func interact(p: Player) -> void:
		Player.run_first(interact_options(p))

## A seam in the rock (flint, coal): break pieces out with the axe.
class Deposit extends Node2D:
	var u: Underground
	var id := ""
	var item := "flint"
	var pieces := 2
	var hp := 6.0

	func _ready() -> void:
		add_to_group("choppable")
		add_to_group("interactable")
		add_to_group("camp")
		hp = 3.0 * pieces

	func chop_distance(p: Player) -> float:
		return absf(p.global_position.x - global_position.x) + (0.0 if absf(p.global_position.y - global_position.y) < 120.0 else INF)

	func prompt_point(_p: Player) -> Vector2:
		return global_position + Vector2(0, -130)

	func chop_label(_p: Player) -> String:
		return "Break out " + Items.get_def(item).name.to_lower()

	func interact_pos() -> Vector2:
		return global_position

	func interact_label(p: Player) -> String:
		return "" if p.held and p.held.def.has("axe") else "%s in the rock: hold the axe and swing to break it out" % Items.get_def(item).name

	func interact(p: Player) -> void:
		p.message.emit("You'd need the axe to break it out.")

	func hit(p: Player, power: float, _aim: Vector2) -> void:
		Sfx.play_at(self, global_position + Vector2(0, -30), Sfx.chop(), 0.0, 1.4)
		var before := ceili(hp / 3.0)
		hp -= power
		if ceili(maxf(hp, 0.0) / 3.0) < before: # a piece comes away
			var s := ItemStack.make(item, GameClock.clock.hours)
			if not p.receive(s, false):
				u.world.spawn({"kind": "item", "x": global_position.x, "y": global_position.y, "stack": s.to_dict()})
			p.message.emit("A piece of %s comes away." % Items.get_def(item).name.to_lower())
		if hp <= 0.0:
			u._mark(id)
			p.message.emit("That's all of it the axe can reach.")
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id)
		var left := ceili(maxf(hp, 0.0) / 3.0)
		var c := Color("1a1918") if item == "coal" else Color("4a4e54")
		for k in maxi(left * 2, 1):
			var at := Vector2(rng.randf_range(-30, 30), -rng.randf_range(8, 60))
			draw_colored_polygon(SceneryArt.blob(at, rng.randf_range(9, 16), rng, 6, 0.35), c)
			draw_line(at + Vector2(-4, -4), at + Vector2(2, -7), c.lightened(0.45), 2.0) # glint

## Fallen timbers and rock across the way: a wall until it's cleared with the axe.
class Block extends Node2D:
	var u: Underground
	var id := ""
	var half := 30.0
	var top := -230.0
	var hp := 10.0
	var _body: StaticBody2D

	func _ready() -> void:
		add_to_group("choppable")
		add_to_group("interactable")
		add_to_group("camp")
		_body = StaticBody2D.new()
		var c := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(half * 2.0, -top)
		c.shape = r
		c.position = Vector2(0, top * 0.5)
		_body.add_child(c)
		add_child(_body)

	func chop_distance(p: Player) -> float:
		return maxf(absf(p.global_position.x - global_position.x) - half, 0.0) + (0.0 if absf(p.global_position.y - global_position.y) < 120.0 else INF)

	func prompt_point(_p: Player) -> Vector2:
		return global_position + Vector2(0, top - 20.0)

	func chop_label(_p: Player) -> String:
		return "Clear the fallen timbers"

	func interact_pos() -> Vector2:
		return global_position + Vector2(0, -60)

	func interact_label(p: Player) -> String:
		return "" if p.held and p.held.def.has("axe") else "Fallen timbers and rock block the drift: the axe could clear them"

	func interact(p: Player) -> void:
		p.message.emit("Rotten timbers wedged with rock. With the axe you could clear a way through.")

	func hit(p: Player, power: float, _aim: Vector2) -> void:
		Sfx.play_at(self, global_position + Vector2(0, -80), Sfx.chop())
		hp -= power
		if hp <= 0.0:
			u._mark(id)
			var s := ItemStack.make("sticks", GameClock.clock.hours, 4)
			if not p.receive(s, false):
				u.world.spawn({"kind": "item", "x": global_position.x, "y": global_position.y, "stack": s.to_dict()})
			p.message.emit("The last timber gives and the rubble slides down. The way east is open. (Broken timber: firewood.)")
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var k := clampf(hp / 10.0, 0.3, 1.0)
		for i in 7:
			var a := Vector2(rng.randf_range(-half, half), rng.randf_range(top, 0) * k)
			draw_line(a + Vector2(-40, 20), a + Vector2(40, -20), Color("4a3a28").darkened(rng.randf() * 0.3), 12.0)
		for i in 9:
			draw_colored_polygon(SceneryArt.blob(Vector2(rng.randf_range(-half - 20, half + 20), -rng.randf_range(0, -top * 0.6) * k), rng.randf_range(14, 30), rng, 7, 0.3), Palette.ROCK.darkened(0.3))
