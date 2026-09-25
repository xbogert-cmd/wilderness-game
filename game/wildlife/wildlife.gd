class_name Wildlife extends Node2D
## Keeps a small herd living around the player: when there are too few nearby, a group
## appears out of sight on either side, on that stretch's game trail; deer that wander far
## off and out of view leave (wounded ones never do, so a blood trail always ends somewhere).
## Animals are ephemeral: they don't persist, they simply live where they're found.
## Also spawns small bird flocks near the player by day.

const SPAWN_CLEARANCE := 1400.0 ## never pop into existence near the player
const SPAWN_RANGE := Vector2(1600.0, 4500.0) ## how far out new deer appear
const DESPAWN_AT := 6000.0 ## deer farther than this, out of view, leave
const HERD := 5 ## deer kept around the player (fewer in winter)
const CHECK_EVERY := 8.0
const SPECIES := [preload("res://data/species/mule_deer.tres")]

var world: World
var player: Player
var tracks: Tracks
var _bird_timer := 20.0
var auto_spawn := true ## scripted checks turn this off to place their own deer
var _herd_timer := 1.0
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
	feed = clampf(feed, Animal.EDGE + 200.0, Terrain.WORLD_W - Animal.EDGE - 200.0)
	return Vector2(clampf(bed, Animal.EDGE + 200.0, Terrain.WORLD_W - Animal.EDGE - 200.0), feed)

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
		if d > DESPAWN_AT and not seen and a.wound < 0.0:
			a.queue_free()
		else:
			count += 1
	var def: SpeciesDef = SPECIES[0]
	var want := HERD - (2 if GameClock.clock.season() == 3 else 0) # winter thins the herd
	if count >= want:
		return
	# Either side, whichever has room; out beyond the edge of the screen.
	var sides := [-1.0, 1.0]
	sides.shuffle()
	for side in sides:
		var x: float = px + side * _rng.randf_range(maxf(SPAWN_RANGE.x, view + 200.0), SPAWN_RANGE.y)
		if x < Animal.EDGE + 200.0 or x > Terrain.WORLD_W - Animal.EDGE - 200.0 or not world.chunks.has(world.terrain.chunk_of(x)):
			continue
		var t := trail(world.terrain.chunk_of(x))
		var lo := minf(t.x, t.y)
		var hi := maxf(t.x, t.y)
		if absf(clampf(x, lo, hi) - px) > SPAWN_CLEARANCE:
			x = clampf(x, lo, hi) # on the trail if that keeps it out of sight
		for k in _rng.randi_range(def.group_min, mini(def.group_max, want - count)):
			var a := spawn(def, x + side * k * _rng.randf_range(90.0, 220.0), _rng.randi())
			a.bed_x = t.x
			a.feed_x = t.y
		return

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
		if a is Animal and a.wound < 0.0 and world.terrain.chunk_of(a.position.x) == i:
			a.queue_free()

func _process(delta: float) -> void:
	if auto_spawn:
		_herd_timer -= delta
		if _herd_timer <= 0.0:
			_herd_timer = CHECK_EVERY
			_manage_herd()
	for a in get_children(): # animals that wander into an unloaded chunk leave (the wounded stay to drop)
		if a is Animal and a.wound < 0.0 and not world.chunks.has(world.terrain.chunk_of(a.position.x)):
			a.queue_free()
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = _rng.randf_range(35.0, 80.0)
		var day := GameClock.clock.daylight() > 0.25 and GameClock.weather.precip < 0.3
		if day and get_tree().get_nodes_in_group("birds").size() < 2:
			var x := player.global_position.x + player.facing * _rng.randf_range(700.0, 1100.0)
			if world.terrain.water_surface_at(x) == INF and x > Animal.EDGE and x < Terrain.WORLD_W - Animal.EDGE:
				var flock := BirdFlock.new()
				flock.world = world
				flock.player = player
				flock.position = Vector2(x, world.terrain.height_at(x))
				add_child(flock)
