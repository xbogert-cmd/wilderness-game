class_name World extends Node2D
## Streams gameplay chunks around a focus x. Only the focus chunk and its neighbours exist.

signal chunk_loaded(index: int)
signal chunk_unloaded(index: int)

const WORLD_SEED := 20260924

var terrain := Terrain.new(WORLD_SEED)
var chunks := {} ## index -> Chunk

func _ready() -> void:
	for x in [-40.0, Terrain.WORLD_W + 40.0]: # hard stops beyond the edge ridges
		var wall := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(80, 6000)
		col.shape = r
		wall.add_child(col)
		wall.position = Vector2(x, -2000)
		add_child(wall)

func update_focus(x: float) -> void:
	var c := terrain.chunk_of(x)
	for i in range(c - 1, c + 2):
		if i >= 0 and i < Terrain.CHUNKS and not chunks.has(i):
			var chunk := Chunk.new()
			chunk.index = i
			chunk.name = "Chunk%d" % i
			chunk.build(terrain, WORLD_SEED)
			add_child(chunk)
			chunks[i] = chunk
			chunk_loaded.emit(i)
	for i in chunks.keys():
		if absi(i - c) > 1:
			chunks[i].queue_free()
			chunks.erase(i)
			chunk_unloaded.emit(i)
