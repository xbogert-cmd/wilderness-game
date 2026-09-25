class_name WorldLog extends RigidBody2D
## An oversized log: never enters the pack. It rests physically, rides on the shoulder
## (short/medium) or is dragged by one end (long). Dragging is kinematic so it never jitters:
## the free end is solved onto the terrain each frame.

const SIZES := {
	"short": {"length": 100.0, "mass": 15.0, "speed": 0.85},
	"medium": {"length": 200.0, "mass": 35.0, "speed": 0.7},
	"long": {"length": 300.0, "mass": 60.0, "speed": 0.55},
}
const SLEEP_DISTANCE := 3000.0

var world: World
var size := "short"
var thickness := 26.0
var conifer := true
var holder: Player ## set while carried or dragged
var _drag_side := -1.0

func _ready() -> void:
	add_to_group("persist")
	add_to_group("log")
	collision_layer = 4
	collision_mask = 1 | 4
	var m := PhysicsMaterial.new()
	m.friction = 1.0
	m.bounce = 0.05
	physics_material_override = m
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(length(), thickness)
	shape.shape = r
	add_child(shape)
	mass = SIZES[size].mass

func length() -> float:
	return SIZES[size].length

func speed_mult() -> float:
	return SIZES[size].speed

func dragged() -> bool:
	return size == "long"

func load_state(d: Dictionary, _elapsed: float) -> void:
	size = d.size
	thickness = float(d.get("thick", 26.0))
	conifer = bool(d.get("conifer", true))
	global_position = Vector2(float(d.x), float(d.y))
	rotation = float(d.get("rot", 0.0))
	mass = SIZES[size].mass
	for c in get_children():
		if c is CollisionShape2D:
			(c.shape as RectangleShape2D).size = Vector2(length(), thickness)

func to_state() -> Dictionary:
	return {"kind": "log", "size": size, "thick": thickness, "conifer": conifer,
		"x": global_position.x, "y": global_position.y, "rot": rotation}

func can_unload() -> bool:
	return holder == null

func pick_up(p: Player) -> void:
	holder = p
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0
	z_index = 6
	_drag_side = -p.facing

func put_down() -> void:
	holder = null
	collision_layer = 4
	collision_mask = 1 | 4
	z_index = 0
	freeze = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

func _physics_process(delta: float) -> void:
	if holder:
		if dragged():
			_follow_drag(delta)
		else:
			global_position = holder.global_position + Vector2(holder.facing * 6.0, -158.0 if size == "medium" else -112.0)
			rotation = 0.0
		return
	var far := absf(global_position.x - world.get_viewport().get_camera_2d().global_position.x) > SLEEP_DISTANCE
	if far != freeze:
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		freeze = far

## One end in the hands, the other resting on the ground behind the player.
func _follow_drag(delta: float) -> void:
	var p := holder
	if absf(p.velocity.x) > 5.0:
		_drag_side = move_toward(_drag_side, -signf(p.velocity.x), delta * 2.0)
	var a := p.global_position + Vector2(_drag_side * 16.0, -78.0)
	var l := length()
	var bx := a.x + _drag_side * l
	for i in 4:
		var by := world.terrain.height_at(bx) - thickness * 0.5
		var dx := sqrt(maxf(l * l - (by - a.y) * (by - a.y), 1.0))
		bx = a.x + _drag_side * maxf(dx, l * 0.25)
	var b := Vector2(bx, world.terrain.height_at(bx) - thickness * 0.5)
	global_position = (a + b) * 0.5
	rotation = (a - b).angle() # local +x points at the hands

## World-space point where the player's hand holds the log (for the rig).
func grip() -> Vector2:
	if dragged():
		return global_position + Vector2.from_angle(rotation) * length() * 0.5
	return global_position + Vector2(0, thickness * 0.5)

func _draw() -> void:
	var l := length()
	var h := thickness
	var bark := Palette.BARK if conifer else Palette.ASPEN_BARK.darkened(0.15)
	draw_rect(Rect2(-l * 0.5, -h * 0.5, l, h), bark)
	draw_line(Vector2(-l * 0.5 + 6, -h * 0.15), Vector2(l * 0.5 - 10, -h * 0.2), bark.darkened(0.25), 2.0)
	draw_line(Vector2(-l * 0.5 + 14, h * 0.2), Vector2(l * 0.5 - 4, h * 0.18), bark.darkened(0.25), 2.0)
	for s in [-1.0, 1.0]:
		draw_rect(Rect2(s * l * 0.5 - (4.0 if s > 0 else 0.0), -h * 0.5, 4, h), Color("c9b28a"))
