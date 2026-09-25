class_name ChoppableTree extends Node2D
## A standing tree in the gameplay plane. Chop it down with an axe: each blow bites a
## deeper notch on your side and throws chips, and it creaks and falls away from you,
## leaving a stump plus a FelledTrunk to strip and buck into logs.

const FALL_TIME := 1.7 ## matches the crash in sfx/tree_fall.wav
const NOTCH_Y := -46.0 ## notch height above the ground
const TREE_FALL := preload("res://assets/audio/sfx/tree_fall.wav")

var chunk: Chunk
var n := 0
var height := 1000.0
var conifer := true
var art: Node2D
var hp := 10.0
var max_hp := 10.0
var felled := false
var _notch: Polygon2D ## the cut, drawn into the trunk art so it falls with the tree
var _chips: CPUParticles2D

func setup(c: Chunk, id: int, h: float, is_conifer: bool, tree_art: Node2D, already_felled: bool) -> void:
	chunk = c
	n = id
	height = h
	conifer = is_conifer
	art = tree_art
	hp = h / 100.0 * 1.2
	max_hp = hp
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

func prompt_point(p: Player) -> Vector2:
	return Vector2(global_position.x, p.global_position.y - 235.0)

func chop_label(_p: Player) -> String:
	return "Chop tree"

func hit(p: Player, power: float, _aim: Vector2) -> void:
	hp -= power
	var dir := signf(global_position.x - p.global_position.x)
	Sfx.play_at(self, global_position + Vector2(0, NOTCH_Y), Sfx.chop())
	_cut(-dir if dir != 0.0 else -1.0)
	var wobble := create_tween()
	wobble.tween_property(art, "rotation", dir * 0.012, 0.08)
	wobble.tween_property(art, "rotation", 0.0, 0.25)
	if hp <= 0.0:
		_fell(dir if dir != 0.0 else 1.0)

func _fell(dir: float) -> void:
	felled = true
	remove_from_group("choppable")
	Sfx.play_at(self, global_position + Vector2(0, -200), TREE_FALL, 2.0)
	chunk.world.mark(chunk.index, "felled", n)
	var tw := create_tween()
	tw.tween_property(art, "rotation", dir * PI * 0.5, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		art.queue_free()
		add_child(_stump())
		chunk.world.spawn({"kind": "trunk", "x": global_position.x, "dir": dir, "length": height * 0.82,
			"girth": girth(), "branches": int(height / 260.0), "conifer": conifer})
		get_viewport().get_camera_2d().shake(8.0))

## Trunk half-width at the notch, matching SceneryArt's trunk taper.
func _half_width() -> float:
	var base := maxf(height * (0.025 if conifer else 0.022), 1.5)
	return base * (1.0 + NOTCH_Y / height * 0.7)

## Deepens the wedge on the side facing the player and throws a few chips.
func _cut(side: float) -> void:
	var hw := _half_width()
	var depth := clampf(1.0 - hp / max_hp, 0.0, 1.0) * hw * 1.6 + 3.0 # up to 80% through
	var open := depth * 0.7
	var edge := side * hw
	var inner := edge - side * depth
	if _notch == null:
		_notch = Polygon2D.new()
		_notch.color = Color("d8bf94")
		var shadow := Polygon2D.new()
		shadow.color = Color(0.25, 0.17, 0.1)
		shadow.name = "Shadow"
		_notch.add_child(shadow)
		art.add_child(_notch)
		_chips = CPUParticles2D.new()
		_chips.emitting = false
		_chips.one_shot = true
		_chips.explosiveness = 0.95
		_chips.amount = 9
		_chips.lifetime = 0.7
		_chips.spread = 35.0
		_chips.gravity = Vector2(0, 900)
		_chips.initial_velocity_min = 140.0
		_chips.initial_velocity_max = 280.0
		_chips.scale_amount_min = 2.0
		_chips.scale_amount_max = 4.0
		_chips.color = Color("e2cc9f")
		_chips.z_index = 6
		_chips.z_as_relative = false
		add_child(_chips)
	_notch.polygon = PackedVector2Array([Vector2(edge, NOTCH_Y - open), Vector2(inner, NOTCH_Y), Vector2(edge, NOTCH_Y + open * 0.35)])
	(_notch.get_node("Shadow") as Polygon2D).polygon = PackedVector2Array([Vector2(inner, NOTCH_Y), Vector2(edge, NOTCH_Y + open * 0.35), Vector2(inner + side * 2.0, NOTCH_Y + 2.0)])
	_chips.position = Vector2(edge, NOTCH_Y)
	_chips.direction = Vector2(side, -0.6)
	_chips.restart()

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
