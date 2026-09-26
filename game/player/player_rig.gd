class_name PlayerRig extends Node2D
## Procedural cutout rig: authored gait parameters + two-bone IK feet placed on the terrain.
## Reads Player state only. Drawn in facing-right space; scale.x flips it.
## Joint layout and colours are documented in docs/art/player_reference.md.

const THIGH := 46.0
const SHIN := 46.0
const ANKLE := 7.0
const UPPER_ARM := 31.0
const FOREARM := 29.0
const HIP_H := 95.0
const TORSO := 62.0

## Gait tuning: stride = foot travel per step, lift = swing height, stance = fraction of cycle planted.
const GAITS := {
	"walk": {"stride": 62.0, "lift": 12.0, "stance": 0.62, "arm": 0.42, "elbow": 0.25, "bob": 2.5},
	"run": {"stride": 118.0, "lift": 30.0, "stance": 0.4, "arm": 0.95, "elbow": 1.35, "bob": 5.0},
	"crouch": {"stride": 40.0, "lift": 8.0, "stance": 0.7, "arm": 0.2, "elbow": 0.9, "bob": 1.0},
}

var body: Player
var phase := 0.0
var _time := 0.0
var _lean := 0.0
var _hip_y := -HIP_H
var _gait: Dictionary = GAITS.walk

func _process(delta: float) -> void:
	scale.x = body.facing
	modulate = Color(1.0, 0.55, 0.5).lerp(Color.WHITE, 1.0 - clampf(body.hurt_t / 0.55, 0.0, 1.0)) # flushed red when struck
	_time += delta
	var speed := absf(body.velocity.x)
	_gait = GAITS.run if body.running else (GAITS.crouch if body.crouching else GAITS.walk)
	var prev := phase
	phase = fposmod(phase + speed * delta / (_gait.stride * 2.0), 1.0)
	if speed > 5.0 and body.is_on_floor():
		for o in [0.0, 0.5]: # a foot plants when its cycle wraps back to the start of stance
			if fposmod(prev + o, 1.0) > fposmod(phase + o, 1.0):
				body.footsteps.step()
	var want_lean := -0.45 * clampf(body.hurt_t / 0.3, 0.0, 1.0) + speed / Player.RUN * 0.2 + (0.4 if body.crouching or body.working > 0.0 else 0.0) + (0.12 if body.carrying else 0.0) + (0.3 if body.hauling else 0.0)
	_lean = lerpf(_lean, want_lean, 1.0 - exp(-delta * 8.0))
	queue_redraw()

func _ground(local_x: float) -> float:
	var x := body.global_position.x + local_x * body.facing
	var g := (body.world.floor_y(x, body.global_position.y) if body.underground else body.world.ground_y(x)) - body.global_position.y # the ice, when the creek is frozen
	if body.is_on_floor() and g > 40.0:
		return 0.0 # standing on something built above the ground (the lookout catwalk): plant the feet there
	return g

func _ground_slope(local_x: float) -> float:
	return atan2(_ground(local_x + 6.0) - _ground(local_x - 6.0), 12.0)

func _foot(offset: float, moving: bool, airborne: bool) -> Vector2:
	if airborne:
		return Vector2(14.0 if offset == 0.0 else -10.0, _hip_y + 72.0)
	if not moving:
		var x := 9.0 if offset == 0.0 else -7.0
		return Vector2(x, _ground(x) - ANKLE)
	var p := fposmod(phase + offset, 1.0)
	var half: float = _gait.stride * 0.5
	var stance: float = _gait.stance
	var x: float
	var lift := 0.0
	if p < stance:
		x = lerpf(half, -half, p / stance)
	else:
		var u := (p - stance) / (1.0 - stance)
		x = lerpf(-half, half, smoothstep(0.0, 1.0, u))
		lift = sin(u * PI) * _gait.lift
	return Vector2(x, _ground(x) - ANKLE - lift)

static func ik(root: Vector2, target: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var d := clampf(root.distance_to(target), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var a := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	return root + Vector2.from_angle((target - root).angle() - a * bend) * l1

func _draw() -> void:
	if body.sleeping or body.dead:
		_draw_lying()
		return
	if body.climbing:
		_draw_climb()
		return
	var moving := absf(body.velocity.x) > 5.0 and body.is_on_floor()
	var airborne := not body.is_on_floor()
	var feet := [_foot(0.0, moving, airborne), _foot(0.5, moving, airborne)]

	# Hip height: authored bob and crouch, then drop just enough for the lower foot to reach.
	var kneel := 38.0 if body.working > 0.0 else (30.0 if body.crouching else 0.0)
	var want: float = -HIP_H - (cos(phase * TAU * 2.0) * _gait.bob if moving else 0.0) + kneel
	var reach := (THIGH + SHIN) * 0.985
	for f in feet:
		var dx: float = f.x
		if absf(dx) < reach:
			want = maxf(want, f.y - sqrt(reach * reach - dx * dx))
	_hip_y = lerpf(_hip_y, want, 0.35)
	var hip := Vector2(0, _hip_y)
	var shoulder := hip + Vector2.from_angle(-PI / 2.0 + _lean) * TORSO
	shoulder.y += sin(_time * 1.6) * 1.1 # breathing
	var head := shoulder + Vector2.from_angle(-PI / 2.0 + _lean * 0.6) * 19.0

	var swing: float = _gait.arm if moving else 0.04
	var elbow: float = _gait.elbow
	if body.wade_depth > 30.0:
		swing *= 0.4
		elbow = 1.1
	var arm_up := 0.5 if body.wade_depth > 30.0 else 0.0

	var back := 0.72
	var back_sleeve := _jacket().darkened(1.0 - back)
	var back_skin := _hand().darkened(1.0 - back)
	var targets := _hand_targets(hip, shoulder) # [near, far] or []
	if targets:
		_arm_to(shoulder, targets[1], back_sleeve, back_skin)
	else:
		_arm(shoulder, phase, swing, elbow, arm_up, back_sleeve, back_skin)
	_leg(hip, feet[1], _pants().darkened(1.0 - back), Palette.BOOTS.darkened(0.3), airborne)
	_pack(hip, shoulder)
	draw_circle(hip, 10.0, _pants())
	_leg(hip, feet[0], _pants(), Palette.BOOTS, airborne)
	_torso(hip, shoulder)
	draw_circle(head, 10.5, Palette.SKIN)
	_hat(head)
	_breath(head)
	var hand: Array # [hand, forearm direction]
	if body.swing >= 0.0:
		hand = _arm_angle(shoulder, _swing_angle(body.swing), 0.25, _jacket(), _hand())
	elif targets:
		hand = _arm_to(shoulder, targets[0], _jacket(), _hand())
	else:
		hand = _arm(shoulder, phase + 0.5, swing, elbow, arm_up, _jacket(), _hand())
	if body.held:
		_held_item(body.held, hand[0], hand[1])
	if body.shot_velocity() != Vector2.ZERO and maxf(body.bow_draw, body.throw_draw) >= 0.05:
		_aim_arc()

## Overrides for both hands while carrying, dragging or working. Local, facing-right space.
func _hand_targets(hip: Vector2, shoulder: Vector2) -> Array:
	if body.pulling: # both hands behind on the sled's rope
		return [shoulder + Vector2(-18, 34), shoulder + Vector2(-12, 38)]
	if body.hurt_t > 0.0: # arms up to fend it off
		return [shoulder + Vector2(22, -22), shoulder + Vector2(16, -34)]
	if body.hauling: # both hands on the neck behind, leaning into the pull
		var g := _to_local_space(body.hauling.grip())
		return [g, g + Vector2(6, -4)]
	if body.thrust >= 0.0: # both hands drive the spear forward and draw it back
		var ext := sin(body.thrust * PI)
		return [shoulder + Vector2(18.0 + 38.0 * ext, 20.0), shoulder + Vector2(-10.0 + 36.0 * ext, 24.0)]
	if body.carrying:
		if body.carrying.dragged():
			var g := _to_local_space(body.carrying.grip())
			return [g, g + Vector2(-4, 3)]
		var g: Array = body.carrying.grips()
		return [_to_local_space(g[0]), _to_local_space(g[1])]
	if body.throw_draw >= 0.0: # throwing arm cocked back over the shoulder, the other pointing the way
		var aim := _to_local_dir(body.launch_dir())
		return [shoulder + aim * 34.0 + Vector2(0, 6), shoulder - aim * (20.0 + 26.0 * body.throw_draw) + Vector2(0, -18)]
	if body.bow_draw >= 0.0: # bow arm out toward the aim, string hand pulled back to the chin
		var aim := _to_local_dir(body.launch_dir())
		return [shoulder + aim * 50.0, shoulder + aim * (46.0 - 40.0 * body.bow_draw)]
	if body.held and body.held.def.has("rod") and body.fishing and body.fishing.state != Fishing.State.IDLE:
		return [shoulder + Vector2(20, 14), shoulder + Vector2(12, 18)] # pole held out over the water
	if body.holding("torch") and body.swing < 0.0 and body.working <= 0.0: # the torch held up and out
		return [shoulder + Vector2(26, -6), shoulder + Vector2(-4, 44)]
	if body.working > 0.0 or body.errand_label != "":
		var w := Vector2(sin(_time * 7.0) * 6.0, cos(_time * 7.0) * 4.0)
		return [hip + Vector2(30, -8) + w, hip + Vector2(24, -4) - w]
	return []

func _aim_dir(from: Vector2) -> Vector2:
	return (_to_local_space(body.aim_point()) - from).normalized()

## A world direction in the rig's facing-right space.
func _to_local_dir(v: Vector2) -> Vector2:
	return Vector2(v.x * body.facing, v.y).normalized()

## Where the arrow or spear would go if you let go now: a dotted line all the way to where it
## lands, a dot every few steps of the path, and a ring where it comes down.
func _aim_arc() -> void:
	var p := body.arrow_origin()
	var v := body.shot_velocity()
	var alpha := 0.45 + 0.45 * maxf(body.bow_draw, body.throw_draw)
	var t := body.world.terrain
	var run := 0.0
	var k := 0
	for i in 600:
		var dt := 0.006
		var before := p
		v.y += Arrow.GRAVITY * dt
		p += v * dt
		var water := t.water_surface_at(p.x)
		if p.y > t.height_at(p.x) or (water != INF and p.y > water):
			var at := _to_local_space(before)
			draw_arc(at, 12.0, 0.0, TAU, 20, Color(0, 0, 0, alpha * 0.4), 4.0)
			draw_arc(at, 12.0, 0.0, TAU, 20, Color(1, 0.95, 0.8, alpha), 2.0)
			return
		run += before.distance_to(p)
		if run >= 34.0:
			run = 0.0
			k += 1
			var fade := alpha * clampf(1.0 - k / 70.0, 0.25, 1.0)
			draw_circle(_to_local_space(p), 4.2, Color(0, 0, 0, fade * 0.35))
			draw_circle(_to_local_space(p), 2.8, Color(1, 1, 1, fade))

## Breath shows as a small cloud in the cold, quicker when you're working hard.
func _breath(head: Vector2) -> void:
	var t_c := GameClock.weather.air_temp_c(GameClock.clock)
	if t_c > 3.0:
		return
	var period := 1.6 if body.running else 3.2
	var k := fposmod(_time, period) / period
	if k > 0.45:
		return
	var a := clampf((3.0 - t_c) / 8.0, 0.25, 0.7) * (1.0 - k / 0.45)
	var mouth := head + Vector2(12, 4)
	for i in 3:
		draw_circle(mouth + Vector2(8.0 + k * 40.0 + i * 5.0, -k * 10.0 - i * 2.0), 3.0 + k * 10.0 - i, Color(0.92, 0.94, 0.97, a * (1.0 - i * 0.25)))

## What you're wearing shows: a buckskin or bear-fur coat, fur or buckskin leggings, mittens.
func _jacket() -> Color:
	var c: ItemStack = body.backpack.worn.body
	return c.def.color if c else Palette.JACKET

func _pants() -> Color:
	var l: ItemStack = body.backpack.worn.legs
	return l.def.color.darkened(0.1) if l else Palette.PANTS

func _hand() -> Color:
	var m: ItemStack = body.backpack.worn.hands
	return m.def.color if m else Palette.SKIN

func _to_local_space(world_point: Vector2) -> Vector2:
	var d := world_point - body.global_position
	return Vector2(d.x * body.facing, d.y)

## Chop: wind up overhead, strike down-forward, recover. Angle 0 = forward, PI/2 = down.
func _swing_angle(t: float) -> float:
	if t < 0.45:
		return lerpf(1.2, -2.3, smoothstep(0.0, 1.0, t / 0.45))
	if t < 0.62:
		return lerpf(-2.3, 0.75, (t - 0.45) / 0.17)
	return lerpf(0.75, 1.2, (t - 0.62) / 0.38)

func _leg(hip: Vector2, ankle: Vector2, pants: Color, boot: Color, airborne: bool) -> void:
	var knee := ik(hip, ankle, THIGH, SHIN, 1.0)
	var end := knee + (ankle - knee).limit_length(SHIN)
	_limb(hip, knee, 15.0, 12.0, pants)
	_limb(knee, end, 12.0, 9.0, pants)
	var slope := 0.0 if airborne else _ground_slope(end.x)
	var t := Transform2D(slope, end)
	if body.backpack.wearing("snowshoes"): # a long bent-wood frame under the boot
		var frame := PackedVector2Array()
		for i in 14:
			var a := TAU * i / 14.0
			frame.append(Vector2(4.0 + cos(a) * 26.0, 9.0 + sin(a) * 3.5))
		draw_colored_polygon(t * frame, Color("9a7a52").darkened(0.1 if boot != Palette.BOOTS else 0.0))
	draw_colored_polygon(t * PackedVector2Array([Vector2(-7, -3), Vector2(5, -3), Vector2(17, 5), Vector2(17, 8), Vector2(-8, 8)]), boot)

func _arm(shoulder: Vector2, p: float, swing: float, bend: float, up: float, sleeve: Color, skin: Color) -> Array:
	return _arm_angle(shoulder, PI / 2.0 - cos(p * TAU) * swing - up - _lean * 0.5, bend, sleeve, skin)

func _arm_angle(shoulder: Vector2, a: float, bend: float, sleeve: Color, skin: Color) -> Array:
	var elbow := shoulder + Vector2.from_angle(a) * UPPER_ARM
	var hand := elbow + Vector2.from_angle(a - bend) * FOREARM
	return _draw_arm(shoulder, elbow, hand, sleeve, skin)

func _arm_to(shoulder: Vector2, target: Vector2, sleeve: Color, skin: Color) -> Array:
	var elbow := ik(shoulder, target, UPPER_ARM, FOREARM, -1.0)
	var hand := elbow + (target - elbow).limit_length(FOREARM)
	return _draw_arm(shoulder, elbow, hand, sleeve, skin)

func _draw_arm(shoulder: Vector2, elbow: Vector2, hand: Vector2, sleeve: Color, skin: Color) -> Array:
	_limb(shoulder, elbow, 11.0, 9.5, sleeve)
	_limb(elbow, hand, 9.5, 8.0, sleeve)
	draw_circle(hand, 5.0, skin)
	return [hand, (hand - elbow).normalized()]

## The held object, drawn in the near hand along the forearm.
func _held_item(s: ItemStack, hand: Vector2, dir: Vector2) -> void:
	var n := Vector2(-dir.y, dir.x) # leading side during a downward strike
	var c := s.def.color
	match s.def.id:
		"axe":
			var tip := hand + dir * 40.0
			draw_line(hand - dir * 6.0, tip, Color("8a6a4a"), 4.0)
			draw_colored_polygon(PackedVector2Array([tip - dir * 2.0, tip - dir * 14.0, tip - dir * 16.0 + n * 16.0, tip + n * 17.0]), Color("9aa0a6"))
		"knife":
			draw_line(hand, hand + dir * 8.0, Color("3a2a20"), 4.0)
			draw_colored_polygon(PackedVector2Array([hand + dir * 8.0 + n * 2.5, hand + dir * 24.0, hand + dir * 8.0 - n * 2.5]), Color("c8ccd0"))
		"cook_pot":
			draw_rect(Rect2(hand + Vector2(-2, 2), Vector2(24, 18)), c)
		"fishing_pole":
			var up := Vector2.from_angle(-0.75)
			draw_line(hand - up * 10.0, hand + up * 120.0, c, 3.0)
			draw_line(hand + up * 60.0, hand + up * 120.0, c.lightened(0.2), 2.0)
		"bow":
			var fwd := _to_local_dir(body.launch_dir()) if body.bow_draw >= 0.0 else Vector2(1, 0.2).normalized()
			var ax := fwd.orthogonal()
			var pull := maxf(body.bow_draw, 0.0)
			var bend := 10.0 + 10.0 * pull
			var top := hand + ax * 48.0 - fwd * bend
			var bot := hand - ax * 48.0 - fwd * bend
			draw_polyline(PackedVector2Array([top, hand + ax * 26.0 - fwd * bend * 0.35, hand, hand - ax * 26.0 - fwd * bend * 0.35, bot]), c, 4.0)
			var nock := hand - fwd * (bend + 4.0 + 36.0 * pull)
			draw_polyline(PackedVector2Array([top, nock, bot]), Color(0.9, 0.88, 0.8, 0.8), 1.2)
			if body.bow_draw >= 0.0:
				draw_line(nock, hand + fwd * 16.0, Color("b0966b"), 2.0)
		"torch": # held up, the flame flickering
			var up := Vector2(0.3, -1.0).normalized()
			var tip := hand + up * 42.0
			draw_line(hand - up * 10.0, tip, Color("6a4e36"), 5.0)
			draw_rect(Rect2(tip - Vector2(5, 3), Vector2(10, 7)), Color("3a2e24"))
			var f := 1.0 + 0.18 * sin(_time * 17.0) + 0.1 * sin(_time * 29.0)
			var lean := Vector2(-GameClock.weather.wind_dir * body.facing * 6.0 * GameClock.weather.wind, 0)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-9, 0), tip + Vector2(0, -34 * f) + lean, tip + Vector2(9, 0)]), Color(0.96, 0.46, 0.12))
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-5, 0), tip + Vector2(0, -20 * f) + lean * 0.6, tip + Vector2(5, 0)]), Color(1.0, 0.85, 0.45))
		"spear":
			if body.throw_draw >= 0.0 and body.pull_vec().length() >= Player.PULL_CLICK: # cocked to throw, along the line it'll fly
				var aim := _to_local_dir(body.launch_dir())
				draw_line(hand - aim * 100.0, hand + aim * 90.0, c, 4.0)
				draw_colored_polygon(PackedVector2Array([hand + aim * 86.0 + aim.orthogonal() * 5.0, hand + aim * 114.0, hand + aim * 86.0 - aim.orthogonal() * 5.0]), Color("9aa0a6"))
				return
			var fwd := Vector2(1, 0.04).normalized() if body.thrust >= 0.0 else Vector2.from_angle(-1.05)
			var tail := hand - fwd * (60.0 if body.thrust >= 0.0 else 26.0)
			var point := hand + fwd * (140.0 if body.thrust >= 0.0 else 118.0)
			draw_line(tail, point, c, 4.0)
			draw_colored_polygon(PackedVector2Array([point + fwd.orthogonal() * 4.0, point + fwd * 16.0, point - fwd.orthogonal() * 4.0]), c.darkened(0.5))
		"sticks":
			for i in 3:
				draw_line(hand + Vector2(-14, -2 + i * 4), hand + Vector2(20, -6 + i * 5), c, 3.0)
		_:
			var sz := Vector2(s.def.size()) * Vector2(6, 9)
			draw_rect(Rect2(hand + Vector2(-sz.x * 0.5, -sz.y * 0.3), sz), c)

## Jacket tapers from shoulders to a belted waist, ending at the hip so the legs keep their length.
func _torso(hip: Vector2, shoulder: Vector2) -> void:
	var u := (shoulder - hip).normalized()
	var f := -u.orthogonal() # toward the front
	draw_colored_polygon(PackedVector2Array([
		hip - f * 10.0 - u * 6.0, hip + f * 10.0 - u * 6.0,
		hip + u * 38.0 + f * 12.5, shoulder + f * 9.0 - u * 3.0,
		shoulder - f * 11.0 - u * 3.0, hip + u * 34.0 - f * 12.0]), _jacket())
	draw_circle(shoulder - u * 4.0, 10.5, _jacket())
	var belt := hip + u * 4.0
	draw_line(belt - f * 10.5, belt + f * 10.5, Palette.BOOTS, 3.0)
	draw_line(shoulder + u * 4.0 + f * 1.0, shoulder + u * 8.0 + f * 3.0, Palette.SKIN.darkened(0.1), 7.0) # neck

func _pack(hip: Vector2, shoulder: Vector2) -> void:
	var up := (shoulder - hip).normalized()
	var side := up.orthogonal() # toward the back
	var base := hip + up * 12.0 + side * 13.0
	var top := shoulder + up * 2.0 + side * 13.0
	draw_colored_polygon(PackedVector2Array([base - side * 2.0, base + side * 16.0, top + side * 14.0, top - side * 2.0]), Palette.PACK)
	_limb(top + side * 6.0 + up * 5.0, top + side * 6.0 + up * 5.1, 15.0, 15.0, Palette.BEDROLL)

func _hat(head: Vector2) -> void:
	var t := Transform2D(_lean * 0.6, head)
	var fur: ItemStack = body.backpack.worn.head
	if fur: # a round fur hat, ear flaps down
		draw_colored_polygon(t * PackedVector2Array([Vector2(-12, -2), Vector2(-11, -13), Vector2(0, -19), Vector2(11, -13), Vector2(12, -2)]), fur.def.color)
		draw_colored_polygon(t * PackedVector2Array([Vector2(-13, -6), Vector2(13, -6), Vector2(13, -1), Vector2(-13, -1)]), fur.def.color.lightened(0.15))
		draw_colored_polygon(t * PackedVector2Array([Vector2(-10, -2), Vector2(-4, -2), Vector2(-5, 9), Vector2(-9, 8)]), fur.def.color.darkened(0.08))
		return
	draw_colored_polygon(t * PackedVector2Array([Vector2(-19, -6), Vector2(19, -6), Vector2(21, -4), Vector2(-17, -3)]), Palette.HAT)
	draw_colored_polygon(t * PackedVector2Array([Vector2(-9, -6), Vector2(9, -6), Vector2(8, -17), Vector2(1, -14), Vector2(-8, -17)]), Palette.HAT)

func _limb(a: Vector2, b: Vector2, wa: float, wb: float, color: Color) -> void:
	var n := (b - a).orthogonal().normalized()
	if n == Vector2.ZERO:
		n = Vector2.RIGHT
	draw_colored_polygon(PackedVector2Array([a + n * wa * 0.5, b + n * wb * 0.5, b - n * wb * 0.5, a - n * wa * 0.5]), color)
	draw_circle(a, wa * 0.5, color)
	draw_circle(b, wb * 0.5, color)

## On a ladder: hands reach up the rungs in turn, each foot stepping up with the other hand.
func _draw_climb() -> void:
	var k := body.climb_phase
	var s1 := 0.5 + 0.5 * sin(k * PI)
	var s2 := 1.0 - s1
	var hip := Vector2(-4, -HIP_H + 8)
	var shoulder := hip + Vector2(6, -TORSO)
	var head := shoulder + Vector2(3, -19)
	var back := 0.72
	_arm_to(shoulder, shoulder + Vector2(9, -30 - 26 * s2), _jacket().darkened(1.0 - back), _hand().darkened(1.0 - back))
	_leg(hip, Vector2(12, -10 - 30 * s1), _pants().darkened(1.0 - back), Palette.BOOTS.darkened(0.3), true)
	_pack(hip, shoulder)
	draw_circle(hip, 10.0, _pants())
	_leg(hip, Vector2(12, -10 - 30 * s2), _pants(), Palette.BOOTS, true)
	_torso(hip, shoulder)
	draw_circle(head, 10.5, Palette.SKIN)
	_hat(head)
	_arm_to(shoulder, shoulder + Vector2(9, -30 - 26 * s1), _jacket(), _hand())

## On the back, head on the pack; under the sleeping bag when asleep with one.
func _draw_lying() -> void:
	var g := _ground(0.0)
	var breath := sin(_time * 1.2) * 1.4 if body.sleeping else 0.0
	var hip := Vector2(8, g - 12)
	var knee := Vector2(48, g - 16)
	var ankle := Vector2(86, g - 9)
	var shoulder := Vector2(-50, g - 14 - breath)
	var head := Vector2(-68, g - 16)
	draw_colored_polygon(PackedVector2Array([Vector2(-96, g), Vector2(-66, g), Vector2(-70, g - 14), Vector2(-94, g - 12)]), Palette.PACK) # pillow
	_limb(hip, knee, 15.0, 12.0, _pants())
	_limb(knee, ankle, 12.0, 9.0, _pants())
	draw_colored_polygon(PackedVector2Array([ankle + Vector2(-4, 6), ankle + Vector2(6, 6), ankle + Vector2(6, -14), ankle + Vector2(0, -14)]), Palette.BOOTS)
	_limb(hip, shoulder, 22.0, 26.0, _jacket())
	draw_circle(head, 10.5, Palette.SKIN)
	_limb(shoulder + Vector2(6, -6), hip + Vector2(-18, -14), 10.0, 9.0, _jacket()) # arm across the chest
	draw_circle(hip + Vector2(-16, -14), 5.0, Palette.SKIN)
	if body.sleeping and body.backpack.count_of("sleeping_bag") > 0:
		var bag := Items.get_def("sleeping_bag").color
		draw_colored_polygon(PackedVector2Array([shoulder + Vector2(-6, 14), shoulder + Vector2(-2, -10 - breath),
			hip + Vector2(0, -14 - breath), ankle + Vector2(14, -8), ankle + Vector2(16, 10)]), bag)
	# hat tipped over the face
	draw_colored_polygon(PackedVector2Array([head + Vector2(-6, -14), head + Vector2(8, -16), head + Vector2(14, -2), head + Vector2(-2, 2)]), Palette.HAT)
