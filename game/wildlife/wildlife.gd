class_name Wildlife extends Node2D
## Keeps a small herd living around the player: when there are too few nearby, a group
## appears out of sight on either side, on that stretch's game trail; deer that wander far
## off and out of view leave (wounded ones never do, so a blood trail always ends somewhere).
## Animals are ephemeral: they don't persist, they simply live where they're found.
## Predators come the same way, out of sight: a wolf pack after dark when there's food lying
## out or the player smells of meat, now and then just passing through. In winter wolves are
## about all day, oftener and in bigger packs, and most packs are travelling, crossing the
## country. The bear only in the foothills, likelier in spring and autumn; in winter it's
## asleep in the cave den. They leave by day or when far off.
## Also spawns small bird flocks by day, and rabbits near the player at dawn and dusk.

const SPAWN_CLEARANCE := 1400.0 ## never pop into existence near the player
const SPAWN_RANGE := Vector2(1600.0, 4500.0) ## how far out new deer appear
const DESPAWN_AT := 6000.0 ## deer farther than this, out of view, leave
const HERD := 5 ## deer kept around the player (fewer in winter)
const CHECK_EVERY := 8.0
const SPECIES := [preload("res://data/species/mule_deer.tres")]
const WOLF := preload("res://data/species/wolf.tres")
const BEAR := preload("res://data/species/black_bear.tres")
const PREDATORS := [WOLF, BEAR]
const BEAR_RANGE := Vector2(21000.0, 40000.0) ## the foothills around the rock shelter
const PREDATOR_EVERY := 10.0

var world: World
var player: Player
var tracks: Tracks
var _bird_timer := 20.0
var auto_spawn := true ## scripted checks turn this off to place their own deer
var _herd_timer := 1.0
var _pred_timer := 5.0
var _quiet_until := -INF ## game hour: after deer are spooked, no new ones turn up for a while
const QUIET_HOURS := 1.5
const LEAVE_AT := 2200.0 ## a spooked deer this far off and out of view has left
var _rabbit_timer := 12.0
var _far_howl := 60.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	world.chunk_unloaded.connect(_on_chunk_unloaded)

## Each chunk's game trail: (bedding x, feeding x). Deer bed in cover by day and walk the same
## line to feed at dawn and dusk, so their tracks and the worn path build up along it.
static func trail(i: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([World.WORLD_SEED, i, "trail"])
	var bed := i * Terrain.CHUNK_W + rng.randf_range(900.0, Terrain.CHUNK_W - 900.0)
	var feed := bed + (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(1600.0, 2600.0)
	feed = clampf(feed, Terrain.WORLD_MIN + Animal.EDGE + 200.0, Terrain.WORLD_MAX - Animal.EDGE - 200.0)
	return Vector2(clampf(bed, Terrain.WORLD_MIN + Animal.EDGE + 200.0, Terrain.WORLD_MAX - Animal.EDGE - 200.0), feed)

## Tops up the herd around the player and lets far-off deer go.
func _manage_herd() -> void:
	var px := player.global_position.x
	var cam := get_viewport().get_camera_2d()
	var view := get_viewport().get_visible_rect().size.x * 0.5 / (cam.zoom.x if cam else 1.0) + 200.0
	var count := 0
	for a in get_children():
		if not a is Animal or a.is_queued_for_deletion():
			continue
		var d := absf(a.position.x - px)
		var seen := cam != null and absf(a.position.x - cam.get_screen_center_position().x) < view
		if (d > DESPAWN_AT or (a.leaving and d > LEAVE_AT)) and not seen and a.wound < 0.0:
			a.queue_free()
		else:
			count += 1
	var def: SpeciesDef = SPECIES[0]
	var want := HERD - (2 if GameClock.clock.season() == 3 else 0) # winter thins the herd
	if count >= want or GameClock.clock.hours < _quiet_until:
		return
	# Either side, whichever has room; out beyond the edge of the screen.
	var sides := [-1.0, 1.0]
	sides.shuffle()
	for side in sides:
		var x: float = px + side * _rng.randf_range(maxf(SPAWN_RANGE.x, view + 200.0), SPAWN_RANGE.y)
		if not Terrain.inside(x, Animal.EDGE + 200.0) or not world.chunks.has(world.terrain.chunk_of(x)):
			continue
		var t := trail(world.terrain.chunk_of(x))
		var lo := minf(t.x, t.y)
		var hi := maxf(t.x, t.y)
		if absf(clampf(x, lo, hi) - px) > SPAWN_CLEARANCE:
			x = clampf(x, lo, hi) # on the trail if that keeps it out of sight
		for k in _rng.randi_range(mini(def.group_min, want - count), mini(def.group_max, want - count)):
			var a := spawn(def, x + side * k * _rng.randf_range(90.0, 220.0), _rng.randi())
			a.bed_x = t.x
			a.feed_x = t.y
		return

## Wolves and the bear: come when there's reason, leave when there isn't.
func _manage_predators() -> void:
	var px := player.global_position.x
	var cam := get_viewport().get_camera_2d()
	var view := get_viewport().get_visible_rect().size.x * 0.5 / (cam.zoom.x if cam else 1.0) + 200.0
	var clock := GameClock.clock
	var winter := clock.season() == 3
	var wolf_hours := clock.daylight() < 0.3 or winter
	var wolves := 0
	var bears := 0
	for n in get_children():
		if not n is Predator or n.is_queued_for_deletion():
			continue
		var seen := cam != null and absf(n.position.x - cam.get_screen_center_position().x) < view
		var busy: bool = n.state in [Predator.State.FEED, Predator.State.STALK, Predator.State.LUNGE, Predator.State.BLUFF]
		var leave := absf(n.position.x - px) > DESPAWN_AT
		if n.is_wolf():
			leave = leave or (not wolf_hours and not busy)
		else:
			leave = leave or winter != (n.den != null) # the den bear is only there in winter
		if leave and not seen:
			n.queue_free()
		elif n.is_wolf():
			wolves += 1
		else:
			bears += 1
	if wolves == 0 and wolf_hours:
		var food := _food_near(px, 7000.0, "wolf")
		var chance := 0.35 if food or player.smells_of_meat() else (0.1 if px > Terrain.CREEK_X else 0.05)
		if winter:
			chance = maxf(chance, 0.2)
		if _rng.randf() < chance:
			var side := signf(food.global_position.x - px) if food and food.global_position.x != px else (1.0 if _rng.randf() < 0.5 else -1.0)
			var x := _out_of_sight(px, side, view)
			if not is_nan(x):
				var pack := []
				var travel := -side if winter and not food and _rng.randf() < 0.6 else 0.0 # passing through, toward and past you
				for k in _rng.randi_range(WOLF.group_min, WOLF.group_max + (1 if winter else 0)):
					var w := spawn_predator(WOLF, x + side * k * _rng.randf_range(60.0, 140.0), _rng.randi())
					w.travel = travel
					w.pack = pack
					pack.append(w)
	if winter and bears == 0:
		_den_bear()
	var in_range := px > BEAR_RANGE.x - 2500.0 and px < BEAR_RANGE.y + 2500.0
	var y := clock.year_pos()
	var roaming := 0.2 if y < 0.125 or (y >= 0.5 and y < 0.75) else 0.12 # hungry in spring, fattening in autumn
	if bears == 0 and not winter and in_range and _rng.randf() < (0.3 if _food_near(px, 7000.0, "black_bear") else roaming):
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var x := _out_of_sight(px, side, view)
		if is_nan(x):
			x = _out_of_sight(px, -side, view)
		if not is_nan(x) and x > BEAR_RANGE.x - 1500.0 and x < BEAR_RANGE.y + 1500.0:
			spawn_predator(BEAR, x, _rng.randi())

## In winter the bear is asleep in the cave den (unless it was killed there this winter).
## It beds down while you're elsewhere, never with you down in the cave.
func _den_bear() -> void:
	for u in get_tree().get_nodes_in_group("underground"):
		if u.kind != "cave" or player.underground == u or absf(u.global_position.x - player.global_position.x) > DESPAWN_AT:
			continue
		if GameClock.clock.hours - float(world.chunk_state(u.chunk_index).get("den_bear_killed", -INF)) < GameClock.clock.season_hours():
			return
		bed_bear(u)

func bed_bear(u: Underground) -> Predator:
	var b := Predator.new()
	b.world = world
	b.player = player
	b.tracks = tracks
	b.setup(BEAR, u.global_position.x, _rng.randi())
	b.bed_down(u)
	add_child(b)
	return b

## Deer were scared off: the area stays quiet for a while before any more wander in.
func spooked() -> void:
	_quiet_until = GameClock.clock.hours + QUIET_HOURS

func _food_near(x: float, reach: float, kind: String) -> Node:
	for n in get_tree().get_nodes_in_group("food_scent"):
		if not n.is_queued_for_deletion() and n.appeals(kind) and absf(n.global_position.x - x) < reach and not Predator.safe_at(get_tree(), n.global_position.x):
			return n
	return null

## A spot on one side, beyond the edge of the screen, in a loaded chunk and not at a camp.
func _out_of_sight(px: float, side: float, view: float) -> float:
	var x := px + side * _rng.randf_range(maxf(1800.0, view + 250.0), 4200.0)
	if not Terrain.inside(x, Animal.EDGE + 200.0) or not world.chunks.has(world.terrain.chunk_of(x)) \
			or Predator.safe_at(get_tree(), x) or world.terrain.water_surface_at(x) != INF:
		return NAN
	return x

func spawn_predator(def: SpeciesDef, x: float, seed_value: int) -> Predator:
	var a := Predator.new()
	a.world = world
	a.player = player
	a.tracks = tracks
	a.setup(def, x, seed_value)
	add_child(a)
	return a

## Rabbits at the edges of the day, a couple at most, out ahead of the player.
func _manage_rabbits() -> void:
	var h := GameClock.clock.hour_of_day()
	var dawn_dusk := (h > 5.0 and h < 9.5) or (h > 16.5 and h < 21.0)
	if not dawn_dusk or get_tree().get_nodes_in_group("small_game").size() >= 2:
		return
	var x := player.global_position.x + player.facing * _rng.randf_range(800.0, 1300.0)
	if not Terrain.inside(x, Animal.EDGE) or world.terrain.water_surface_at(x) != INF:
		return
	var r := Rabbit.new()
	r.world = world
	r.player = player
	r.position = Vector2(x, world.ground_y(x))
	add_child(r)

## Now and then after dark, wolves somewhere off in the valley.
func _distant_howl() -> void:
	var winter := GameClock.clock.season() == 3 # wolves are loudest in winter, and not only at night
	if GameClock.clock.daylight() > (0.35 if winter else 0.15) or get_tree().get_nodes_in_group("predators").any(func(p): return p.is_wolf()):
		return
	if _rng.randf() < 0.4:
		var at := player.global_position + Vector2((1.0 if _rng.randf() < 0.5 else -1.0) * 2300.0, -300.0)
		Sfx.play_at(self, at, Sfx.howl(), -9.0, 0.95)
		Journal.note("wolves", "Wolves howling after dark. They'll be drawn to anything dead I leave lying out, and they won't come near a fire.")

func spawn(def: SpeciesDef, x: float, seed_value: int) -> Animal:
	var a := Animal.new()
	a.world = world
	a.player = player
	a.tracks = tracks
	a.setup(def, x, seed_value)
	add_child(a)
	return a

func _on_chunk_unloaded(i: int) -> void:
	for a in get_children():
		if (a is Predator or a is Rabbit or (a is Animal and a.wound < 0.0)) and world.terrain.chunk_of(a.position.x) == i:
			a.queue_free()

func _process(delta: float) -> void:
	if auto_spawn:
		_herd_timer -= delta
		if _herd_timer <= 0.0:
			_herd_timer = CHECK_EVERY
			_manage_herd()
		_pred_timer -= delta
		if _pred_timer <= 0.0:
			_pred_timer = PREDATOR_EVERY
			_manage_predators()
		_rabbit_timer -= delta
		if _rabbit_timer <= 0.0:
			_rabbit_timer = _rng.randf_range(25.0, 60.0)
			_manage_rabbits()
		_far_howl -= delta
		if _far_howl <= 0.0:
			_far_howl = _rng.randf_range(80.0, 200.0)
			_distant_howl()
	for a in get_children(): # animals that wander into an unloaded chunk leave (the wounded stay to drop)
		if (a is Predator or a is Rabbit or (a is Animal and a.wound < 0.0)) and not world.chunks.has(world.terrain.chunk_of(a.position.x)):
			a.queue_free()
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = _rng.randf_range(35.0, 80.0)
		var day := GameClock.clock.daylight() > 0.25 and GameClock.weather.precip < 0.3
		if day and get_tree().get_nodes_in_group("birds").size() < 2:
			var x := player.global_position.x + player.facing * _rng.randf_range(700.0, 1100.0)
			if world.terrain.water_surface_at(x) == INF and Terrain.inside(x, Animal.EDGE):
				var flock := BirdFlock.new()
				flock.world = world
				flock.player = player
				flock.position = Vector2(x, world.terrain.height_at(x))
				add_child(flock)
