class_name DeerRig extends Node2D
## Procedural mule deer. Same visual language as the player: flat shapes on jointed limbs.
## Poses: graze (head down), walk, alert (head up, ears forward), bedded, and the mule deer's
## stotting bound when fleeing (all four hooves leave the ground together).
## Facing right, origin on the ground under the body; scale.x flips it.

var animal: Animal
var _phase := 0.0
var _t := 0.0
var _head := 0.0 ## 0 = up, 1 = down grazing, smoothed
var _low := 0.0 ## 1 = bedded, smoothed

func _process(delta: float) -> void:
	scale = Vector2(animal.facing, 1.0) * animal.def.size
	_t += delta
	var s: int = animal.state
	_phase = fposmod(_phase + animal.speed * delta / (140.0 if s == Animal.State.FLEE else 90.0), 1.0)
	_head = move_toward(_head, 1.0 if s == Animal.State.GRAZE else 0.0, delta * 1.5)
	_low = move_toward(_low, 1.0 if s == Animal.State.BEDDED else 0.0, delta * 1.2)
	queue_redraw()

func _draw() -> void:
	var d := animal.def
	var flee := animal.state == Animal.State.FLEE
	var alert := animal.state == Animal.State.ALERT
	var bound := absf(sin(_phase * TAU)) if flee else 0.0 # stotting height 0..1
	var body_y := -92.0 + 58.0 * _low - 48.0 * bound
	var breath := sin(_t * 1.5) * 0.8
	var chest := Vector2(40, body_y - 4)
	var rump := Vector2(-46, body_y - 2)
	var far := d.body_color.darkened(0.3)

	if _low < 0.9:
		for leg in [[chest + Vector2(-6, 10), 0.5, true], [rump + Vector2(6, 12), 0.0, false]]:
			_leg(leg[0], leg[1], leg[2], far, flee, bound)

	# Body
	var body := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		body.append(Vector2(cos(a) * 62.0, sin(a) * (24.0 + breath)) + Vector2(-3, body_y))
	draw_colored_polygon(body, d.body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-40, body_y + 14), Vector2(36, body_y + 14), Vector2(28, body_y + 23), Vector2(-30, body_y + 23)]), d.belly_color)
	var patch := PackedVector2Array()
	for i in 12:
		var ang := TAU * i / 12.0
		patch.append(rump + Vector2(-12, -2) + Vector2(cos(ang) * 10.0, sin(ang) * 15.0))
	draw_colored_polygon(patch, d.rump_color) # white rump patch
	draw_line(rump + Vector2(-20, -10), rump + Vector2(-26, 8), d.rump_color, 7.0) # tail
	draw_circle(rump + Vector2(-26, 9), 4.0, d.dark_color) # black tail tip

	if _low < 0.9:
		for leg in [[chest + Vector2(2, 12), 0.0, true], [rump + Vector2(14, 14), 0.5, false]]:
			_leg(leg[0], leg[1], leg[2], d.body_color, flee, bound)
	else:
		draw_rect(Rect2(chest.x - 20, -12, 40, 10), d.body_color.darkened(0.15)) # folded legs

	# Neck and head: up when alert or walking, down to the grass when grazing.
	var head_up := chest + Vector2(26, -58 if alert else -48)
	var head_down := Vector2(chest.x + 44, -18)
	var head := head_up.lerp(head_down, _head) + Vector2(0, bound * -4.0)
	var neck_top := head + Vector2(-10, 6)
	_limb(chest + Vector2(2, -2), neck_top, 26.0, 15.0, d.body_color)
	var dir := Vector2.from_angle(lerpf(0.35, 1.3, _head))
	var muzzle := head + dir * 24.0
	draw_colored_polygon(PackedVector2Array([head + dir.orthogonal() * 10.0, muzzle + dir.orthogonal() * 4.0, muzzle - dir.orthogonal() * 5.0, head - dir.orthogonal() * 9.0]), d.body_color)
	draw_circle(head, 11.0, d.body_color)
	draw_circle(muzzle, 4.5, d.dark_color)
	draw_circle(head + dir * 6.0 + dir.orthogonal() * 3.0, 2.2, d.dark_color) # eye
	# Mule deer ears: big, swivelled forward when alert.
	var ear_dir := Vector2.from_angle(-1.9 if alert else -2.4 + sin(_t * 0.7) * 0.15)
	for k in [1.0, 0.0]: # far ear first
		var base := head + Vector2(-5 + k * 4, -7)
		var e := ear_dir.rotated(k * 0.3)
		var o := e.orthogonal()
		var ear := PackedVector2Array([base - o * 4.0, base + e * 10.0 - o * 8.0, base + e * 22.0, base + e * 10.0 + o * 8.0, base + o * 4.0])
		draw_colored_polygon(ear, d.body_color.darkened(0.15 * k))
		draw_colored_polygon(PackedVector2Array([base + e * 5.0 - o * 2.0, base + e * 11.0 - o * 5.0, base + e * 18.0, base + e * 11.0 + o * 5.0, base + e * 5.0 + o * 2.0]), d.belly_color.darkened(0.15 * k))

## One leg: joint bends forward for the foreleg, back for the hind leg (hock).
func _leg(top: Vector2, offset: float, fore: bool, color: Color, flee: bool, bound: float) -> void:
	var swing := sin((_phase + offset) * TAU) * (0.0 if flee else 0.38) * clampf(animal.speed / 40.0, 0.0, 1.0)
	var reach := -top.y
	var tuck := bound * 0.45 # legs fold up at the top of a bound
	var length := reach * (1.0 - tuck)
	var foot := top + Vector2.from_angle(PI / 2.0 - swing) * length
	if flee:
		foot.x += (12.0 if fore else -12.0) * (1.0 - bound)
	var joint := top.lerp(foot, 0.5) + Vector2((-6.0 if fore else 8.0) * (1.0 + tuck * 2.0), 0)
	draw_line(top, joint, color, 9.0)
	draw_line(joint, foot, color, 6.0)
	draw_circle(joint, 4.0, color)
	draw_rect(Rect2(foot + Vector2(-3, -5), Vector2(8, 6)), animal.def.dark_color)

## Tapered segment with round ends; valid for any pose (never self-intersects).
func _limb(a: Vector2, b: Vector2, wa: float, wb: float, color: Color) -> void:
	var n := (b - a).orthogonal().normalized()
	if n == Vector2.ZERO:
		return
	draw_colored_polygon(PackedVector2Array([a + n * wa * 0.5, b + n * wb * 0.5, b - n * wb * 0.5, a - n * wa * 0.5]), color)
	draw_circle(a, wa * 0.5, color)
	draw_circle(b, wb * 0.5, color)
