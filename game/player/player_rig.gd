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
	_time += delta
	var speed := absf(body.velocity.x)
	_gait = GAITS.run if body.running else (GAITS.crouch if body.crouching else GAITS.walk)
	var prev := phase
	phase = fposmod(phase + speed * delta / (_gait.stride * 2.0), 1.0)
	if speed > 5.0 and body.is_on_floor():
		for o in [0.0, 0.5]: # a foot plants when its cycle wraps back to the start of stance
			if fposmod(prev + o, 1.0) > fposmod(phase + o, 1.0):
				body.footsteps.step()
	var want_lean := speed / Player.RUN * 0.2 + (0.4 if body.crouching or body.working > 0.0 else 0.0) + (0.12 if body.carrying else 0.0)
	_lean = lerpf(_lean, want_lean, 1.0 - exp(-delta * 8.0))
	queue_redraw()

func _ground(local_x: float) -> float:
	return body.world.ground_y(body.global_position.x + local_x * body.facing) - body.global_position.y # the ice, when the creek is frozen

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
	var back_skin := Palette.SKIN.darkened(1.0 - back)
	var targets := _hand_targets(hip, shoulder) # [near, far] or []
	if targets:
		_arm_to(shoulder, targets[1], back_sleeve, back_skin)
	else:
		_arm(shoulder, phase, swing, elbow, arm_up, back_sleeve, back_skin)
	_leg(hip, feet[1], Palette.PANTS.darkened(1.0 - back), Palette.BOOTS.darkened(0.3), airborne)
	_pack(hip, shoulder)
	draw_circle(hip, 10.0, Palette.PANTS)
	_leg(hip, feet[0], Palette.PANTS, Palette.BOOTS, airborne)
	_torso(hip, shoulder)
	draw_circle(head, 10.5, Palette.SKIN)
	_hat(head)
	_breath(head)
	var hand: Array # [hand, forearm direction]
	if body.swing >= 0.0:
		hand = _arm_angle(shoulder, _swing_angle(body.swing), 0.25, _jacket(), Palette.SKIN)
	elif targets:
		hand = _arm_to(shoulder, targets[0], _jacket(), Palette.SKIN)
	else:
		hand = _arm(shoulder, phase + 0.5, swing, elbow, arm_up, _jacket(), Palette.SKIN)
	if body.held:
		_held_item(body.held, hand[0], hand[1])
	if body.bow_draw >= 0.5:
		_aim_arc()

## Overrides for both hands while carrying, dragging or working. Local, facing-right space.
func _hand_targets(hip: Vector2, shoulder: Vector2) -> Array:
	if body.carrying:
		if body.carrying.dragged():
			var g := _to_local_space(body.carrying.grip())
			return [g, g + Vector2(-4, 3)]
		if body.carrying.size == "short":
			return [shoulder + Vector2(18, 26), shoulder + Vector2(10, 30)]
		return [shoulder + Vector2(8, -16), shoulder + Vector2(-6, -16)]
	if body.bow_draw >= 0.0: # bow arm out toward the aim, string hand pulled back to the chin
		var aim := _aim_dir(shoulder)
		return [shoulder + aim * 50.0, shoulder + aim * (46.0 - 40.0 * body.bow_draw)]
	if body.held and body.held.def.has("rod") and body.fishing and body.fishing.state != Fishing.State.IDLE:
		return [shoulder + Vector2(20, 14), shoulder + Vector2(12, 18)] # pole held out over the water
	if body.working > 0.0:
		var w := Vector2(sin(_time * 7.0) * 6.0, cos(_time * 7.0) * 4.0)
		return [hip + Vector2(30, -8) + w, hip + Vector2(24, -4) - w]
	return []

func _aim_dir(from: Vector2) -> Vector2:
	return (_to_local_space(body.aim_point()) - from).normalized()

## Where a loosed arrow would go for the first half second: a steadying hint at a good draw.
func _aim_arc() -> void:
	var p := body.arrow_origin()
	var v := body.arrow_velocity()
	var alpha := (body.bow_draw - 0.5) * 0.9
	for i in 14:
		var dt := 0.035
		v.y += Arrow.GRAVITY * dt
		p += v * dt
		if p.y > body.world.terrain.height_at(p.x):
			break
		draw_circle(_to_local_space(p), 2.2, Color(1, 1, 1, alpha * (1.0 - i / 14.0)))

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

## Buckskin once the hide coat is in the pack.
func _jacket() -> Color:
	return Color("a78a5d") if body.backpack.count_of("hide_coat") > 0 else Palette.JACKET

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
			var fwd := _aim_dir(hand) if body.bow_draw >= 0.0 else Vector2(1, 0.2).normalized()
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
	draw_colored_polygon(t * PackedVector2Array([Vector2(-19, -6), Vector2(19, -6), Vector2(21, -4), Vector2(-17, -3)]), Palette.HAT)
	draw_colored_polygon(t * PackedVector2Array([Vector2(-9, -6), Vector2(9, -6), Vector2(8, -17), Vector2(1, -14), Vector2(-8, -17)]), Palette.HAT)

func _limb(a: Vector2, b: Vector2, wa: float, wb: float, color: Color) -> void:
	var n := (b - a).orthogonal().normalized()
	if n == Vector2.ZERO:
		n = Vector2.RIGHT
	draw_colored_polygon(PackedVector2Array([a + n * wa * 0.5, b + n * wb * 0.5, b - n * wb * 0.5, a - n * wa * 0.5]), color)
	draw_circle(a, wa * 0.5, color)
	draw_circle(b, wb * 0.5, color)

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
	_limb(hip, knee, 15.0, 12.0, Palette.PANTS)
	_limb(knee, ankle, 12.0, 9.0, Palette.PANTS)
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
