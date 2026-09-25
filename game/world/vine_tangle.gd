class_name VineTangle extends Node2D
## Wild vines trailing over the ground. Gather them (they regrow in a few days) and twist
## three into a cord: string for a bow or a fishing line.

const REGROW_HOURS := 96.0
const YIELD := 2

var chunk: Chunk
var n := 0
var picked_hour := -INF
var _seed := 0
var _was_ripe := true
var _turn := -1.0

func setup(c: Chunk, id: int, picked: float) -> void:
	chunk = c
	n = id
	picked_hour = picked
	_seed = id
	add_to_group("interactable")
	z_index = 2

func ripe() -> bool:
	return GameClock.clock.hours - picked_hour >= REGROW_HOURS

func _process(_delta: float) -> void:
	var turn := snappedf(GameClock.clock.leaf_turn(), 0.1)
	if ripe() != _was_ripe or turn != _turn:
		_was_ripe = ripe()
		_turn = turn
		queue_redraw()

func interact_pos() -> Vector2:
	return global_position

func interact_label(_p: Player) -> String:
	return "Gather vines" if ripe() else ""

func interact(p: Player) -> void:
	picked_hour = GameClock.clock.hours
	chunk.world.mark(chunk.index, "picked", n)
	p.receive(ItemStack.make("vine", picked_hour, YIELD))

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var stem := Color("5d6b36").lerp(Color("7a6038"), _turn)
	var leaf := Color("6f8a3e").lerp(Color("b08a3a"), _turn)
	var strands := 5 if ripe() else 2
	for k in strands:
		var pts := PackedVector2Array()
		var x := rng.randf_range(-60.0, -20.0)
		var y := -2.0
		var span := rng.randf_range(70.0, 120.0)
		for i in 12:
			var t := i / 11.0
			pts.append(Vector2(x + span * t, y - sin(t * PI) * rng.randf_range(10.0, 28.0) - sin(t * 13.0 + k) * 4.0))
		draw_polyline(pts, stem, 2.2)
		if ripe() and _turn < 0.95 or ripe() and GameClock.clock.leaf_drop() < 0.9:
			for i in range(1, pts.size(), 2):
				draw_colored_polygon(SceneryArt.blob(pts[i] + Vector2(0, -3), 4.5, rng, 5, 0.3), leaf)
