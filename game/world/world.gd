class_name World extends Node2D
## Streams gameplay chunks around a focus x. Only the focus chunk and its neighbours exist.
## Player-made changes live in `state` (per chunk) and survive unloading: persistent nodes
## (group "persist") serialize into their chunk on unload and respawn on load, catching up
## on the game hours that passed while nobody was there.

signal chunk_loaded(index: int)
signal chunk_unloaded(index: int)

const WORLD_SEED := 20260924
const KINDS := {
	"item": preload("res://game/world/world_item.gd"),
	"log": preload("res://game/world/world_log.gd"),
	"trunk": preload("res://game/world/felled_trunk.gd"),
	"campfire": preload("res://game/camp/campfire.gd"),
	"blueprint": preload("res://game/camp/blueprint.gd"),
	"lean_to": preload("res://game/camp/lean_to.gd"),
	"pack": preload("res://game/world/dropped_pack.gd"),
	"carcass": preload("res://game/hunting/carcass.gd"),
	"woodpile": preload("res://game/camp/woodpile.gd"),
	"hide_frame": preload("res://game/camp/hide_frame.gd"),
	"drying_rack": preload("res://game/camp/drying_rack.gd"),
	"cabin": preload("res://game/camp/cabin.gd"),
	"blind": preload("res://game/camp/hunting_blind.gd"),
	"workbench": preload("res://game/camp/workbench.gd"),
	"chest": preload("res://game/camp/storage_chest.gd"),
	"bait": preload("res://game/hunting/bait_pile.gd"),
	"gut_pile": preload("res://game/hunting/gut_pile.gd"),
	"snare": preload("res://game/hunting/snare.gd"),
	"bridge": preload("res://game/camp/log_bridge.gd"),
	"sled": preload("res://game/camp/sled.gd"),
}

var terrain := Terrain.new(WORLD_SEED)
var chunks := {} ## index -> Chunk
var state := {} ## "index" -> {felled: {}, picked: {}, objects: [], left: hour}
var dynamic := Node2D.new() ## persistent objects not owned by a chunk (they can move)
var tracks := Tracks.new()
var _snow_shown := -1.0
const MAP_CELL := 200.0 ## explored-map resolution
const SIGHT := 1100.0 ## how far either side you take in as you walk
var explored := PackedByteArray() ## one byte per MAP_CELL: 1 once seen

func _ready() -> void:
	tracks.world = self
	add_child(tracks)
	dynamic.name = "Dynamic"
	dynamic.z_index = 3
	add_child(dynamic)
	for x in [Terrain.WORLD_MIN - 40.0, Terrain.WORLD_MAX + 40.0]: # hard stops beyond the edge ridges
		var wall := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(80, 6000)
		col.shape = r
		wall.add_child(col)
		wall.position = Vector2(x, -2000)
		add_child(wall)

func _process(_delta: float) -> void:
	var cm := GameClock.weather.snow_cm
	if absf(cm - _snow_shown) > 0.4 or (cm == 0.0 and _snow_shown != 0.0):
		_snow_shown = cm
		for c in chunks.values():
			c.set_snow(cm)
	RenderingServer.global_shader_parameter_set("snow", clampf(cm / 12.0, 0.0, 1.0))
	RenderingServer.global_shader_parameter_set("autumn", GameClock.clock.leaf_turn())
	RenderingServer.global_shader_parameter_set("bare", GameClock.clock.leaf_drop())
	RenderingServer.global_shader_parameter_set("ice", GameClock.weather.ice)

## Where an animal or dropped thing rests: the ground, or the ice over the creek when frozen.
func ground_y(x: float) -> float:
	var s := terrain.water_surface_at(x)
	return s if s != INF and Creek.frozen() else terrain.height_at(x)

## Where the top of the lying snow is (the terrain itself when there is none).
func snow_top(x: float) -> float:
	return terrain.height_at(x) - (GameClock.weather.snow_cm if terrain.water_surface_at(x) == INF else 0.0)

func chunk_state(i: int) -> Dictionary:
	var key := str(i)
	if not state.has(key):
		state[key] = {"felled": {}, "picked": {}, "objects": _initial_objects(i), "left": GameClock.clock.hours}
	return state[key]

const MAP_CELLS := int((Terrain.WORLD_MAX - Terrain.WORLD_MIN) / MAP_CELL)

func _cell(x: float) -> int:
	return int(floor((x - Terrain.WORLD_MIN) / MAP_CELL))

## Older saves mapped only the original valley (x from 0): pad it out to the whole world.
func set_explored(a: PackedByteArray) -> void:
	if a.size() == int(48000.0 / MAP_CELL):
		var west := PackedByteArray()
		west.resize(_cell(0.0))
		west.fill(0)
		west.append_array(a)
		a = west
	a.resize(MAP_CELLS)
	explored = a

func explore(x: float) -> void:
	explore_range(x - SIGHT, x + SIGHT)
	_biome_notes(x)
	var b := Terrain.biome(x)
	match b:
		"river": Journal.note("river", "Came down to the Sweetwater River, west of the valley. Wide, cold and deep enough to soak you to the chest. A bridge of logs would make it easy.")
		"marsh": Journal.note("marsh", "West of the river the ground goes soft: a marsh of cattails and willows, and a pond. Everything that walks here leaves tracks.")
		"sage": Journal.note("sage", "Out on the sage flats at the western edge of the valley. Open country, wind, a small creek, and not much cover.")
		"burn": Journal.note("burn", "Down the far side of the ridge into an old burn: standing dead trees, fireweed, black ground. Quiet here.")
		"alpine": Journal.note("alpine", "Up into a high basin with a tarn, a small cold lake under the peaks. Twisted little firs and boulders.")

func explore_range(a: float, b: float) -> void:
	if explored.size() != MAP_CELLS:
		explored.resize(MAP_CELLS)
	for i in range(maxi(_cell(a), 0), mini(_cell(b) + 1, explored.size())):
		explored[i] = 1

func _biome_notes(x: float) -> void:
	if x > Terrain.FOOTHILLS_X and x < Terrain.RIDGE_X:
		Journal.note("foothills", "Walked out of the creek valley into the foothills. Rockier ground, fewer aspens, and the land climbing toward the ridge and the lookout.")

func reveal_all() -> void:
	explored.resize(MAP_CELLS)
	explored.fill(1)

func seen(x: float) -> bool:
	var i := _cell(x)
	return i >= 0 and i < explored.size() and explored[i] == 1

func update_focus(x: float) -> void:
	explore(x)
	var c := terrain.chunk_of(x)
	for i in chunks.keys():
		if absi(i - c) > 1:
			_unload(i)
	for i in range(c - 1, c + 2):
		if i >= Terrain.FIRST and i <= Terrain.LAST and not chunks.has(i):
			_load(i)

func _load(i: int) -> void:
	var st := chunk_state(i)
	var chunk := Chunk.new()
	chunk.index = i
	chunk.world = self
	chunk.name = "Chunk%d" % i
	chunk.build(terrain, WORLD_SEED, st)
	add_child(chunk)
	chunks[i] = chunk
	chunk.set_snow(maxf(_snow_shown, 0.0))
	var elapsed := maxf(GameClock.clock.hours - float(st.left), 0.0)
	for d in st.objects:
		spawn(d, elapsed)
	st.objects = []
	if chunk._contains(Terrain.CREEK_X) and not st.get("whetstones", false): # also reaches saves from before whetstones
		st.whetstones = true
		for side in [-1.0, 1.0]:
			spawn({"kind": "item", "x": Terrain.CREEK_X + side * (Terrain.CREEK_HALF + 140.0 + 90.0 * side), "stack": ItemStack.make("whetstone").to_dict()})
	chunk_loaded.emit(i)

func _unload(i: int) -> void:
	var st := chunk_state(i)
	for n in get_tree().get_nodes_in_group("persist"):
		if not n.is_queued_for_deletion() and terrain.chunk_of(n.global_position.x) == i and n.can_unload():
			st.objects.append(n.to_state())
			n.queue_free()
	st.left = GameClock.clock.hours
	chunks[i].queue_free()
	chunks.erase(i)
	chunk_unloaded.emit(i)

func spawn(d: Dictionary, elapsed := 0.0) -> Node2D:
	var n: Node2D = KINDS[d.kind].new()
	n.world = self
	dynamic.add_child(n)
	n.load_state(d, elapsed)
	return n

func mark(i: int, table: String, id: int) -> void:
	chunk_state(i)[table][str(id)] = GameClock.clock.hours

## Fallen branches scattered on first visit, so there is always kindling to find.
func _initial_objects(i: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([WORLD_SEED, i, "sticks"])
	var out := []
	for k in 6:
		var x := i * Terrain.CHUNK_W + rng.randf_range(300, Terrain.CHUNK_W - 300)
		if terrain.water_surface_at(x) == INF and Terrain.inside(x, 500.0) and (i != 0 or x > 500.0):
			out.append({"kind": "item", "x": x, "stack": ItemStack.make("sticks", 0.0, rng.randi_range(1, 3)).to_dict()})
	return out

## Everything needed to bring the world back exactly: stored chunk state plus live objects.
func snapshot() -> Dictionary:
	var now := GameClock.clock.hours
	var out: Dictionary = state.duplicate(true)
	for key in out:
		if chunks.has(int(key)):
			out[key].left = now
	for n in get_tree().get_nodes_in_group("persist"):
		if n.is_queued_for_deletion():
			continue
		var key := str(terrain.chunk_of(n.global_position.x))
		if not out.has(key):
			out[key] = {"felled": {}, "picked": {}, "objects": [], "left": now}
		out[key].objects.append(n.to_state())
	return out

## Call before the first update_focus on a fresh world.
func restore(saved: Dictionary) -> void:
	state = saved.duplicate(true)

func heat_at(p: Vector2) -> float:
	var h := 0.0
	for f in get_tree().get_nodes_in_group("heat"):
		h = maxf(h, f.heat_at(p))
	return h

func sheltered_at(x: float) -> bool:
	for s in get_tree().get_nodes_in_group("shelter"):
		if s.covers(x):
			return true
	return false
