class_name FelledTrunk extends Node2D
## A felled tree lying along the ground. Axe hits strip branches first (dropping sticks),
## then buck the trunk: aim at a guide mark (short / medium / long from the nearer end)
## and each finished cut rolls off a WorldLog of that length.

const MARKS := {"short": 100.0, "medium": 200.0, "long": 300.0}
const HITS_PER_CUT := 3
const CUT_REACH := 190.0 ## how far from the player a cut mark can be

var world: World
var base_x := 0.0 ## the end nearest the stump
var dir := 1.0 ## which way it lies from the base
var length := 1000.0
var girth := 30.0
var branches := 4
var conifer := true
var cut_hits := 0
var _aim_end := 1.0 ## +1 tip end, -1 base end
var _aim_size := "long"

func _ready() -> void:
	add_to_group("persist")
	add_to_group("choppable")
	z_as_relative = false
	z_index = 3 # above the ground (1) and grass (2), below the player (5)

func load_state(d: Dictionary, _elapsed: float) -> void:
	base_x = float(d.x) + float(d.dir) * 25.0 if not d.has("base") else float(d.base)
	dir = float(d.dir)
	length = float(d.length)
	girth = float(d.girth)
	branches = int(d.branches)
	conifer = bool(d.conifer)
	_place()

func to_state() -> Dictionary:
	return {"kind": "trunk", "x": global_position.x, "base": base_x, "dir": dir, "length": length,
		"girth": girth, "branches": branches, "conifer": conifer}

func can_unload() -> bool:
	return true

func _place() -> void:
	var a := _end(-1.0)
	var b := _end(1.0)
	var lift := 0.0 # rest on the high points, bridging dips, never sinking into a rise
	for i in 11:
		var t := i / 10.0
		var x := lerpf(a.x, b.x, t)
		lift = maxf(lift, lerpf(a.y, b.y, t) - (world.terrain.height_at(x) - girth * 0.5 + 4.0))
	a.y -= lift
	b.y -= lift
	global_position = (a + b) * 0.5
	rotation = (b - a).angle() if dir > 0.0 else (a - b).angle()
	queue_redraw()

## World point of an end: -1 = base end, +1 = tip end.
func _end(which: float) -> Vector2:
	var x := base_x if which < 0.0 else base_x + dir * length
	return Vector2(x, world.terrain.height_at(x) - girth * 0.5 + 4.0)

func chop_distance(p: Player) -> float:
	var x := p.global_position.x
	var lo := minf(base_x, base_x + dir * length)
	var hi := maxf(base_x, base_x + dir * length)
	return 0.0 if x >= lo and x <= hi else minf(absf(x - lo), absf(x - hi))

func prompt_point(p: Player) -> Vector2:
	var x := _mark_x() if branches == 0 else clampf(p.global_position.x + p.facing * 60.0, minf(base_x, base_x + dir * length), maxf(base_x, base_x + dir * length))
	return Vector2(x, world.terrain.height_at(x) - girth - 60.0)

func chop_label(p: Player) -> String:
	if branches > 0:
		return "Strip branches (%d left)" % branches
	_update_aim(p, p.aim_point())
	if not _mark_in_reach(p):
		return "Step closer to the %s mark" % _aim_size
	return "Cut %s log (%d/%d)" % [_aim_size, cut_hits, HITS_PER_CUT]

## Cuts come off the end nearest the player; the mouse picks which length.
func _update_aim(p: Player, aim: Vector2) -> void:
	var tip := _end(1.0)
	var base := _end(-1.0)
	var px := p.global_position.x
	_aim_end = 1.0 if absf(px - tip.x) < absf(px - base.x) else -1.0
	var from_end := absf(aim.x - (tip.x if _aim_end > 0.0 else base.x))
	var best := "long"
	for k in MARKS:
		if MARKS[k] < length - 20.0 and absf(from_end - MARKS[k]) < absf(from_end - MARKS[best]):
			best = k
	if MARKS[best] >= length - 20.0:
		best = "short"
	if _aim_size != best:
		cut_hits = 0
	_aim_size = best
	queue_redraw()

func _mark_x() -> float:
	var end := _end(_aim_end)
	return end.x - dir * _aim_end * MARKS[_aim_size]

func _mark_in_reach(p: Player) -> bool:
	return absf(_mark_x() - p.global_position.x) < CUT_REACH

func hit(p: Player, _power: float, aim: Vector2) -> void:
	Sfx.play_at(self, p.global_position + Vector2(p.facing * 60.0, -30.0), Sfx.split(), -3.0, 1.1 if branches > 0 else 1.0)
	if branches > 0:
		branches -= 1
		world.spawn({"kind": "item", "x": p.global_position.x + p.facing * 40.0, "stack": ItemStack.make("sticks", 0.0, 2).to_dict()})
		queue_redraw()
		return
	_update_aim(p, aim)
	if not _mark_in_reach(p):
		p.message.emit("Step closer to the mark to cut there.")
		return
	cut_hits += 1
	if cut_hits < HITS_PER_CUT:
		return
	cut_hits = 0
	var piece: float = MARKS[_aim_size]
	var end := _end(_aim_end)
	var along := Vector2(-dir * _aim_end, 0.0) # from that end toward the middle
	var center_x := end.x + along.x * piece * 0.5
	world.spawn({"kind": "log", "size": _aim_size, "thick": minf(girth, 34.0), "conifer": conifer,
		"x": center_x, "y": world.terrain.height_at(center_x) - 30.0, "rot": 0.0})
	length -= piece
	if _aim_end < 0.0:
		base_x += dir * piece
	if length < 90.0:
		queue_free()
	else:
		_place()

func _draw() -> void:
	var l := length
	var g := girth
	var bark := Palette.BARK if conifer else Palette.ASPEN_BARK.darkened(0.1)
	# local +x runs from the base end to the tip end in world terms when dir > 0
	var tip_sign := 1.0 if dir > 0.0 else -1.0
	var pts := PackedVector2Array([
		Vector2(-tip_sign * l * 0.5, -g * 0.5), Vector2(tip_sign * l * 0.5, -g * 0.22),
		Vector2(tip_sign * l * 0.5, g * 0.22), Vector2(-tip_sign * l * 0.5, g * 0.5)])
	draw_colored_polygon(pts, bark)
	draw_rect(Rect2(-tip_sign * l * 0.5 - (4.0 if tip_sign > 0 else 0.0), -g * 0.5, 4, g), Color("c9b28a"))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(base_x)
	for i in branches:
		var x := lerpf(-tip_sign * l * 0.1, tip_sign * l * 0.48, float(i + 1) / (branches + 1))
		var up := -1.0 if i % 2 == 0 else 1.0
		draw_line(Vector2(x, up * g * 0.3), Vector2(x + tip_sign * rng.randf_range(30, 70), up * rng.randf_range(40, 80)), bark.darkened(0.2), 5.0)
		if conifer:
			draw_circle(Vector2(x + tip_sign * 50, up * 60), 22.0, Palette.FIR_DARK)
	if branches == 0:
		# Guide marks from both ends: short, medium, long.
		for e in [-1.0, 1.0]:
			var end_x: float = e * tip_sign * l * 0.5
			for k in MARKS:
				if MARKS[k] < l - 20.0:
					var x: float = end_x - e * tip_sign * MARKS[k]
					var chosen: bool = e == _aim_end and k == _aim_size
					draw_line(Vector2(x, -g * 0.6), Vector2(x, g * 0.6), Color(1, 0.95, 0.7, 0.9 if chosen else 0.35), 3.0 if chosen else 1.5)
