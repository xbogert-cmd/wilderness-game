class_name ChoppableTree extends Node2D
## A standing tree in the gameplay plane. Chop it down with an axe; it falls away from
## the player and leaves a stump plus a FelledTrunk to strip and buck into logs.

const FALL_TIME := 1.7

var chunk: Chunk
var n := 0
var height := 1000.0
var conifer := true
var art: Node2D
var hp := 10.0
var felled := false

func setup(c: Chunk, id: int, h: float, is_conifer: bool, tree_art: Node2D, already_felled: bool) -> void:
	chunk = c
	n = id
	height = h
	conifer = is_conifer
	art = tree_art
	hp = h / 100.0 * 1.2
	felled = already_felled
	if felled:
		art.free() # generated only to keep the chunk's rng sequence stable
		add_child(_stump())
	else:
		add_child(art)
		add_to_group("choppable")

func girth() -> float:
	return height * (0.03 if conifer else 0.024)

func chop_distance(p: Player) -> float:
	return absf(p.global_position.x - global_position.x)

func chop_label(_p: Player) -> String:
	return "Chop tree"

func hit(p: Player, power: float, _aim: Vector2) -> void:
	hp -= power
	var dir := signf(global_position.x - p.global_position.x)
	var wobble := create_tween()
	wobble.tween_property(art, "rotation", dir * 0.012, 0.08)
	wobble.tween_property(art, "rotation", 0.0, 0.25)
	if hp <= 0.0:
		_fell(dir if dir != 0.0 else 1.0)

func _fell(dir: float) -> void:
	felled = true
	remove_from_group("choppable")
	chunk.world.mark(chunk.index, "felled", n)
	var tw := create_tween()
	tw.tween_property(art, "rotation", dir * PI * 0.5, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		art.queue_free()
		add_child(_stump())
		chunk.world.spawn({"kind": "trunk", "x": global_position.x, "dir": dir, "length": height * 0.82,
			"girth": girth(), "branches": int(height / 260.0), "conifer": conifer})
		get_viewport().get_camera_2d().shake(8.0))

func _stump() -> Node2D:
	var g := girth()
	var s := Polygon2D.new()
	s.polygon = PackedVector2Array([Vector2(-g * 0.7, 4), Vector2(g * 0.7, 4), Vector2(g * 0.55, -g * 0.9), Vector2(-g * 0.55, -g * 0.7)])
	s.color = Palette.BARK if conifer else Palette.ASPEN_BARK.darkened(0.2)
	var top := Polygon2D.new()
	top.polygon = PackedVector2Array([Vector2(-g * 0.55, -g * 0.7), Vector2(g * 0.55, -g * 0.9), Vector2(g * 0.5, -g * 0.97), Vector2(-g * 0.5, -g * 0.78)])
	top.color = Color("c9b28a")
	s.add_child(top)
	return s
