class_name Wildlife extends Node2D
## Spawns and despawns animals with the chunks. Placement is seeded per chunk and day, and
## ignores how many trees stand there, so felled areas still get animals. Animals are
## ephemeral: they don't persist, they simply live where they're found.
## Also spawns small bird flocks near the player by day.

const SPAWN_CLEARANCE := 1400.0 ## never pop into existence near the player
const SPECIES := [preload("res://data/species/mule_deer.tres")]

var world: World
var player: Player
var tracks: Tracks
var _bird_timer := 20.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	world.chunk_loaded.connect(_on_chunk_loaded)
	world.chunk_unloaded.connect(_on_chunk_unloaded)
	for i in world.chunks:
		_on_chunk_loaded(i)

func _on_chunk_loaded(i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([World.WORLD_SEED, i, GameClock.clock.day(), "animals"])
	for def: SpeciesDef in SPECIES:
		for g in def.groups_per_chunk:
			var x := i * Terrain.CHUNK_W + rng.randf_range(400.0, Terrain.CHUNK_W - 400.0)
			if GameClock.clock.season() == 3 and rng.randf() < 0.5:
				continue # winter thins the herd: many have moved down to lower valleys
			if absf(x - player.global_position.x) < SPAWN_CLEARANCE or x < Animal.EDGE or x > Terrain.WORLD_W - Animal.EDGE:
				continue
			for k in rng.randi_range(def.group_min, def.group_max):
				spawn(def, x + k * rng.randf_range(90.0, 220.0), rng.randi())

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
		if a is Animal and world.terrain.chunk_of(a.position.x) == i:
			a.queue_free()

func _process(delta: float) -> void:
	for a in get_children(): # animals that wander into an unloaded chunk leave the simulation
		if a is Animal and not world.chunks.has(world.terrain.chunk_of(a.position.x)):
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
