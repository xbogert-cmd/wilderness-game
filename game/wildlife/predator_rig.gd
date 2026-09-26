class_name PredatorRig extends Node2D
## Procedural wolf and black bear, in the deer's flat-shape style. Poses: walk, gallop, head
## low (stalking, feeding), and the bear rearing up at the end of a bluff charge.
## Facing right, origin on the ground under the body; scale.x flips it.

var animal: Predator
var _phase := 0.0
var _t := 0.0
var _low := 0.0 ## head and body lowered (stalking, feeding), smoothed
var _rear := 0.0 ## bear up on its hind legs, smoothed
var _leap := 0.0 ## wolf springing at you: 0 on the ground, 1 at the top of the spring

func _process(delta: float) -> void:
	scale = Vector2(animal.facing, 1.0)
	_t += delta
	var s := animal.state
	var gallop: bool = animal.speed > animal.stat("trot") * 1.6
	_phase = fposmod(_phase + animal.speed * delta / (150.0 if gallop else 95.0), 1.0)
	var low := s in [Predator.State.STALK, Predator.State.FEED] or (s == Predator.State.SEEK and animal.speed < 1.0)
	_low = move_toward(_low, 1.0 if low else 0.0, delta * 2.5)
	var rear := s == Predator.State.BLUFF and animal.speed < 30.0
	var d := absf(animal.player.global_position.x - animal.position.x)
	var closing := s == Predator.State.LUNGE and d < 260.0
	var want_rear := 1.0 if rear else (0.45 if closing or animal.strike_t > 0.0 else 0.0) # the bear rises to swipe
	_rear = move_toward(_rear, want_rear, delta * 4.0)
	var want_leap := 0.0
	if animal.is_wolf() and s == Predator.State.LUNGE:
		want_leap = 0.55 if animal.strike_t > 0.0 else clampf((260.0 - d) / 160.0, 0.0, 1.0) # springs, then hangs on
	_leap = move_toward(_leap, want_leap, delta * 6.0)
	queue_redraw()

func _draw() -> void:
	var d := animal.def
	if animal.is_wolf():
		_wolf(d)
	else:
		_bear(d)

func _gallop() -> float:
	return absf(sin(_phase * TAU)) if animal.speed > animal.stat("trot") * 1.6 else 0.0

func _wolf(d: SpeciesDef) -> void:
	var bound := _gallop() * (1.0 - _leap)
	# A spring at you: the body lifts and tilts up toward your arm or leg, forelegs reaching.
	var shake := sin(_t * 38.0) * 3.0 if animal.strike_t > 0.0 else 0.0
	draw_set_transform(Vector2(shake, -70.0 * _leap), -0.35 * _leap, Vector2.ONE)
	var body_y := -60.0 + 12.0 * _low - 16.0 * bound
	var chest := Vector2(34, body_y - 2)
	var rump := Vector2(-40, body_y)
	var far := d.body_color.darkened(0.3)
	for leg in [[chest + Vector2(-4, 8), 0.5, true], [rump + Vector2(6, 8), 0.0, false]]:
		_leg(leg[0], leg[1], leg[2], far, d.dark_color, 7.0, bound)
	# Tail: low and straight when stalking, a loose curve otherwise.
	var tail_end := rump + Vector2(-44, 26 if _low > 0.5 else 12 + sin(_t * 2.0) * 3.0)
	_limb(rump + Vector2(-6, -4), tail_end, 12.0, 9.0, d.body_color.darkened(0.08))
	draw_circle(tail_end, 5.0, d.dark_color)
	var body := _ellipse(Vector2(-3, body_y), 52.0, 18.0 + sin(_t * 1.6) * 0.6)
	draw_colored_polygon(body, d.body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-34, body_y + 10), Vector2(30, body_y + 10), Vector2(24, body_y + 17), Vector2(-26, body_y + 17)]), d.belly_color)
	draw_colored_polygon(_ellipse(chest + Vector2(4, -2), 20.0, 17.0), d.body_color.lightened(0.05)) # ruff
	for leg in [[chest + Vector2(4, 10), 0.0, true], [rump + Vector2(12, 10), 0.5, false]]:
		_leg(leg[0], leg[1], leg[2], d.body_color, d.dark_color, 8.0, bound)
	# Neck and head: carried level, or low and forward when stalking or feeding.
	var head := chest + Vector2(28, -16).lerp(Vector2(36, 30), _low) + Vector2(0, -bound * 4.0)
	_limb(chest + Vector2(4, -6), head + Vector2(-8, 2), 20.0, 13.0, d.body_color)
	var dir := Vector2.from_angle(lerpf(0.15, 0.6, _low))
	var muzzle := head + dir * 24.0
	var jaw := 0.0
	if animal.state == Predator.State.STALK:
		jaw = 3.0 + sin(_t * 9.0) * 1.5 # a snarl
	elif animal.state == Predator.State.LUNGE:
		jaw = 1.0 if animal.strike_t > 0.0 else 9.0 # wide open, then clamped shut
	draw_colored_polygon(PackedVector2Array([head + dir.orthogonal() * 8.0, muzzle + dir.orthogonal() * 3.0, muzzle - dir.orthogonal() * (4.0 + jaw), head - dir.orthogonal() * 8.0]), d.body_color)
	draw_circle(head, 10.0, d.body_color)
	draw_circle(muzzle, 3.2, d.dark_color)
	draw_circle(head + dir * 5.0 + dir.orthogonal() * 3.5, 1.8, Color("d8b04a") if GameClock.clock.daylight() < 0.3 else d.dark_color) # eyes catch the light at night
	for k in [0.0, 1.0]: # pointed ears, flat back when stalking
		var base := head + Vector2(-4 + k * 5, -6)
		var e := Vector2.from_angle(lerpf(-1.7, -2.6, _low) + k * 0.25)
		draw_colored_polygon(PackedVector2Array([base - e.orthogonal() * 4.0, base + e * 13.0, base + e.orthogonal() * 4.0]), d.body_color.darkened(0.15 * k))
	if jaw > 5.0: # teeth showing
		draw_line(muzzle - dir * 10.0 - dir.orthogonal() * 1.0, muzzle - dir.orthogonal() * 1.0, Color("e8e2d0"), 2.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _bear(d: SpeciesDef) -> void:
	var bound := _gallop()
	# Rearing pivots the whole bear up around its hind feet.
	draw_set_transform(Vector2(-60, 0), -0.75 * _rear, Vector2.ONE)
	var o := Vector2(60, 0) # back into bear space after the pivot
	var body_y := -84.0 + 10.0 * _low - 18.0 * bound
	var chest := o + Vector2(52, body_y + 4)
	var rump := o + Vector2(-56, body_y)
	var far := d.body_color.darkened(0.3)
	for leg in [[chest + Vector2(-6, 18), 0.5, true], [rump + Vector2(8, 16), 0.0, false]]:
		_leg(leg[0], leg[1], leg[2], far, d.dark_color, 16.0, bound)
	var breath := sin(_t * 1.3) * 1.2
	draw_colored_polygon(_ellipse(o + Vector2(-4, body_y), 84.0, 38.0 + breath), d.body_color)
	draw_colored_polygon(_ellipse(chest + Vector2(-18, -26), 34.0, 22.0), d.body_color.lightened(0.04)) # shoulder hump
	for leg in [[chest + Vector2(4, 20), 0.0, true], [rump + Vector2(18, 18), 0.5, false]]:
		_leg(leg[0], leg[1], leg[2], d.body_color, d.dark_color, 18.0, bound)
	var head := chest + Vector2(38, -14).lerp(Vector2(44, 34), _low)
	_limb(chest + Vector2(6, -8), head + Vector2(-10, 2), 36.0, 26.0, d.body_color)
	draw_circle(head, 21.0, d.body_color)
	var dir := Vector2.from_angle(lerpf(0.2, 0.7, _low))
	var muzzle := head + dir * 26.0
	var roar := 5.0 if animal.state == Predator.State.BLUFF and _rear > 0.3 else 0.0
	draw_colored_polygon(PackedVector2Array([head + dir.orthogonal() * 12.0, muzzle + dir.orthogonal() * 7.0, muzzle - dir.orthogonal() * (7.0 + roar), head - dir.orthogonal() * 12.0]), Color("8a6a4a"))
	draw_circle(muzzle, 5.0, d.dark_color)
	draw_circle(head + dir * 8.0 + dir.orthogonal() * 6.0, 2.4, d.dark_color)
	for k in [0.0, 1.0]: # small round ears
		draw_circle(head + Vector2(-8 + k * 10, -18), 7.0, d.body_color.darkened(0.12 * k))
	if _rear > 0.2 and animal.state == Predator.State.LUNGE or animal.strike_t > 0.0:
		# A foreleg raised and raking down: up while it closes, sweeping through on the strike.
		var sweep := 1.0 - animal.strike_t / 0.45 if animal.strike_t > 0.0 else 0.0
		var ang := lerpf(-1.3, 0.9, sweep)
		var shoulder := chest + Vector2(10, -6)
		var elbow := shoulder + Vector2.from_angle(ang) * 40.0
		var paw := elbow + Vector2.from_angle(ang + 0.5) * 38.0
		draw_line(shoulder, elbow, d.body_color, 20.0)
		draw_line(elbow, paw, d.body_color, 16.0)
		draw_circle(paw, 11.0, d.body_color.darkened(0.1))
		for c in 4: # claws
			var cd := Vector2.from_angle(ang + 0.5 + (c - 1.5) * 0.28)
			draw_line(paw + cd * 8.0, paw + cd * 20.0, Color("d8cfb8"), 2.5)
		if animal.strike_t > 0.0: # the rake of the swipe
			for c in 3:
				draw_arc(shoulder, 78.0 + c * 7.0, ang - 0.9, ang + 0.2, 10, Color(1, 1, 1, 0.35 * animal.strike_t / 0.45), 2.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _leg(top: Vector2, offset: float, fore: bool, color: Color, paw: Color, width: float, bound: float) -> void:
	var swing := sin((_phase + offset) * TAU) * (0.1 if bound > 0.0 else 0.42) * clampf(animal.speed / 50.0, 0.0, 1.0)
	var reach := -top.y
	var length := reach * (1.0 - bound * 0.35)
	var foot := top + Vector2.from_angle(PI / 2.0 - swing) * length
	if bound > 0.0 or animal.speed > animal.stat("trot") * 1.6:
		foot.x += (18.0 if fore else -18.0) * (1.0 - bound)
	var joint := top.lerp(foot, 0.5) + Vector2(-5.0 if fore else 7.0, 0)
	draw_line(top, joint, color, width)
	draw_line(joint, foot, color, width * 0.7)
	draw_circle(joint, width * 0.45, color)
	draw_colored_polygon(_ellipse(foot + Vector2(3, -2), width * 0.6, width * 0.3), paw)

static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out

func _limb(a: Vector2, b: Vector2, wa: float, wb: float, color: Color) -> void:
	var n := (b - a).orthogonal().normalized()
	if n == Vector2.ZERO:
		return
	draw_colored_polygon(PackedVector2Array([a + n * wa * 0.5, b + n * wb * 0.5, b - n * wb * 0.5, a - n * wa * 0.5]), color)
	draw_circle(a, wa * 0.5, color)
	draw_circle(b, wb * 0.5, color)

## Dead, on its side (drawn by the carcass). Skinned: only the red carcass and bones.
static func draw_dead(ci: CanvasItem, d: SpeciesDef, skinned: bool) -> void:
	var wolf := d.id == "wolf"
	var k := 1.0 if wolf else 1.55
	var body_c := Color("7a3a30") if skinned else d.body_color
	for i in 2:
		var hip := Vector2(-34 + i * 58, -12) * k
		ci.draw_line(hip, hip + Vector2(30, 8) * k, body_c.darkened(0.25), 6.0 * k)
		ci.draw_circle(hip + Vector2(32, 9) * k, 4.0 * k, d.dark_color)
	ci.draw_colored_polygon(_ellipse(Vector2(-4, -16) * k, 54.0 * k, 17.0 * k), body_c)
	if not skinned:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-34, -4) * k, Vector2(32, -5) * k, Vector2(26, -1) * k, Vector2(-28, 0) * k]), d.belly_color)
	if wolf and not skinned:
		ci.draw_line(Vector2(-56, -14), Vector2(-96, -6), d.body_color.darkened(0.08), 10.0) # tail
	ci.draw_circle(Vector2(62, -10) * k, 11.0 * k, body_c)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(66, -18) * k, Vector2(90, -10) * k, Vector2(66, -3) * k]), body_c)
	ci.draw_circle(Vector2(90, -9) * k, 3.0 * k, d.dark_color)
	if not skinned:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(56, -18) * k, Vector2(50, -34) * k, Vector2(64, -20) * k]), d.body_color.darkened(0.15))
