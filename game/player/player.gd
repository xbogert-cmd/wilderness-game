class_name Player extends CharacterBody2D
## Movement and survival wiring. Presentation lives in PlayerRig, which only reads this node.

const WALK := 150.0
const RUN := 390.0
const CROUCH := 70.0
const HOP := 470.0
const GRAVITY := 1900.0
const ACCEL := 1100.0
const FALL_INJURY_SPEED := 1150.0
const HOP_STAMINA := 6.0

var world: World
var cond: Condition
var facing := 1
var running := false
var crouching := false
var wade_depth := 0.0
var auto_dir := 0.0 ## set by smoke tests to walk without input
var auto_run := false
var _can_run := true
var _fall_vy := 0.0

func _ready() -> void:
	cond = Condition.new(GameClock.tuning)
	var shape := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 16.0
	cap.height = 150.0
	shape.shape = cap
	shape.position = Vector2(0, -75)
	add_child(shape)
	floor_snap_length = 28.0
	floor_max_angle = deg_to_rad(52.0)
	floor_constant_speed = true
	var rig := PlayerRig.new()
	rig.body = self
	add_child(rig)
	GameClock.ticked.connect(_on_tick)

func _physics_process(delta: float) -> void:
	var dir := auto_dir if auto_dir != 0.0 else Input.get_axis("move_left", "move_right")
	var was_on_floor := is_on_floor()
	crouching = Input.is_action_pressed("crouch") and was_on_floor
	if cond.stamina < 1.0:
		_can_run = false
	elif cond.stamina > 20.0:
		_can_run = true
	running = (Input.is_action_pressed("run") or auto_run) and dir != 0.0 and not crouching and _can_run
	wade_depth = world.terrain.water_depth_at(global_position.x, global_position.y)

	var speed := CROUCH if crouching else (RUN if running else WALK)
	speed *= cond.move_speed_mult() * (1.0 - clampf(wade_depth / 130.0, 0.0, 0.65))
	velocity.x = move_toward(velocity.x, dir * speed, ACCEL * delta)
	if running:
		cond.spend_stamina(GameClock.tuning.run_stamina_per_sec * delta)
	else:
		cond.recover_stamina(delta * (0.5 if dir != 0.0 else 1.0))

	if not was_on_floor:
		velocity.y += GRAVITY * delta
		_fall_vy = maxf(_fall_vy, velocity.y)
	elif Input.is_action_just_pressed("hop") and cond.spend_stamina(HOP_STAMINA):
		velocity.y = -HOP
	move_and_slide()
	if not was_on_floor and is_on_floor():
		_on_landed(_fall_vy)
		_fall_vy = 0.0
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
	world.update_focus(global_position.x)

func _on_landed(vy: float) -> void:
	if vy > FALL_INJURY_SPEED:
		var k := clampf((vy - FALL_INJURY_SPEED) / 900.0, 0.0, 1.0)
		cond.injure("legs", "sprain", 0.3 + 0.6 * k)
		cond.health -= 10.0 + 30.0 * k

func exertion() -> float:
	if running: return 1.0
	return 0.3 if absf(velocity.x) > 1.0 else 0.0

func _on_tick(dh: float) -> void:
	var w := GameClock.weather
	cond.tick(dh, {
		"air_c": w.air_temp_c(GameClock.clock),
		"precip": w.precip,
		"exertion": exertion(),
		"wading": clampf(wade_depth / 100.0, 0.0, 1.0),
	})
