class_name FollowCamera extends Camera2D
## Subtle adaptive framing: look ahead in the travel direction, widen when running.

const LOOK_AHEAD := 170.0
const HEIGHT := 250.0 ## matches Backdrop.FEET_BELOW_CENTER
const ZOOM_WALK := 0.95
const ZOOM_RUN := 0.86

var target: Player
var zoom_override := 0.0 ## debug close-ups
var view_zoom := 0.0 ## a wide view eased into (e.g. from the lookout); 0 = normal framing
var _look := 0.0
var _shake := 0.0

## Reserved for big physical moments (a tree coming down), never routine actions.
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 4.0
	zoom = Vector2(ZOOM_WALK, ZOOM_WALK)

func _process(delta: float) -> void:
	if zoom_override > 0.0:
		zoom = Vector2(zoom_override, zoom_override)
		global_position = target.global_position + Vector2(0, -90)
		return
	var want := target.facing * LOOK_AHEAD + target.velocity.x * 0.2
	_look = lerpf(_look, want, 1.0 - exp(-delta * 1.2))
	global_position = target.global_position + Vector2(_look, -HEIGHT)
	var z := view_zoom if view_zoom > 0.0 else (ZOOM_RUN if target.running else ZOOM_WALK)
	if view_zoom <= 0.0: # the big views: the camera draws back to take them in
		z *= lerpf(1.0, 0.8, vista(target.global_position.x))
	zoom = zoom.lerp(Vector2(z, z), 1.0 - exp(-delta * 0.7))
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_shake = move_toward(_shake, 0.0, delta * 20.0)

## Places with a view, and how far out from each the camera starts to draw back: [x, full within, none past].
const VISTAS := [[Terrain.LOOKOUT_X, 1400.0, 3200.0], [64500.0, 1600.0, 3200.0], [Terrain.FALLS_X, 700.0, 1900.0],
	[Terrain.CANYON.x, 600.0, 1700.0], [Terrain.CANYON.y, 600.0, 1700.0]]

## 0..1: how much of a view there is from x.
static func vista(x: float) -> float:
	var v := 0.0
	for s in VISTAS:
		v = maxf(v, 1.0 - smoothstep(s[1], s[2], absf(x - s[0])))
	return v

