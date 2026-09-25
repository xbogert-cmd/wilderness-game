class_name Player extends CharacterBody2D
## Movement, hands, and survival wiring. Presentation lives in PlayerRig, which only reads this node.

signal message(text: String)

const WALK := 150.0
const RUN := 390.0
const CROUCH := 70.0
const HOP := 470.0
const GRAVITY := 1900.0
const ACCEL := 1100.0
const FALL_INJURY_SPEED := 1150.0
const HOP_STAMINA := 6.0
const REACH := 120.0
const CHOP_REACH := 110.0
const SWING_TIME := 0.6
const SWING_IMPACT := 0.62 ## fraction of the swing where the blade lands
const SWING_STAMINA := 4.0
const CARRY_STAMINA_PER_SEC := 2.5

var world: World
var footsteps: Footsteps
var cond: Condition
var backpack := Backpack.new()
var held: ItemStack ## the one object in hand
var held_slot := -1 ## attachment slot it came from, to return it there
var carrying: WorldLog ## oversized object on the shoulder or dragged
var focus: Node ## interactable in reach
var chop_target: Node
var swing := -1.0 ## 0..1 through a tool swing, -1 idle
var working := 0.0 ## real seconds of busy work left
var work_label := ""
var placing := false ## BuildMode is placing a blueprint; clicks belong to it
var known_recipes: PackedStringArray = ["splint"]
var facing := 1
var running := false
var crouching := false
var wade_depth := 0.0
var auto_dir := 0.0 ## set by smoke tests to walk without input
var auto_run := false
var _can_run := true
var _fall_vy := 0.0
var _work_done: Callable
var aim_override := Vector2.INF ## scripted checks aim without a mouse

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
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
	footsteps = Footsteps.new()
	footsteps.body = self
	add_child(footsteps)
	var rig := PlayerRig.new()
	rig.body = self
	add_child(rig)
	GameClock.ticked.connect(_on_tick)
	_starting_kit()

func _starting_kit() -> void:
	var h := GameClock.clock.hours
	backpack.attach(ItemStack.make("axe", h), 0)
	backpack.attach(ItemStack.make("knife", h), 1)
	var bottle := ItemStack.make("water_bottle", h)
	bottle.add_water(0.8, true)
	for s in [bottle, ItemStack.make("cook_pot", h), ItemStack.make("lighter", h), ItemStack.make("sleeping_bag", h),
			ItemStack.make("bandage", h, 2), ItemStack.make("jerky", h, 3)]:
		backpack.add(s)

# --- Movement ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var dir := 0.0
	if working <= 0.0 and swing < 0.0:
		dir = auto_dir if auto_dir != 0.0 else Input.get_axis("move_left", "move_right")
	var was_on_floor := is_on_floor()
	crouching = Input.is_action_pressed("crouch") and was_on_floor and working <= 0.0
	if cond.stamina < 1.0:
		_can_run = false
	elif cond.stamina > 20.0:
		_can_run = true
	running = (Input.is_action_pressed("run") or auto_run) and dir != 0.0 and not crouching and _can_run and carrying == null
	wade_depth = world.terrain.water_depth_at(global_position.x, global_position.y)

	var speed := CROUCH if crouching else (RUN if running else WALK)
	speed *= cond.move_speed_mult() * (1.0 - clampf(wade_depth / 130.0, 0.0, 0.65)) * backpack.encumbrance_mult()
	if carrying:
		speed *= carrying.speed_mult()
	velocity.x = move_toward(velocity.x, dir * speed, ACCEL * delta)
	if running:
		cond.spend_stamina(GameClock.tuning.run_stamina_per_sec * delta)
	elif carrying and dir != 0.0:
		cond.stamina = maxf(cond.stamina - CARRY_STAMINA_PER_SEC * delta, 0.0)
	elif swing < 0.0:
		cond.recover_stamina(delta * (0.5 if dir != 0.0 else 1.0))

	if not was_on_floor:
		velocity.y += GRAVITY * delta
		_fall_vy = maxf(_fall_vy, velocity.y)
	elif Input.is_action_just_pressed("hop") and carrying == null and working <= 0.0 and cond.spend_stamina(HOP_STAMINA):
		velocity.y = -HOP
	move_and_slide()
	if not was_on_floor and is_on_floor():
		_on_landed(_fall_vy)
		footsteps.step()
		_fall_vy = 0.0
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
	world.update_focus(global_position.x)

	_advance_swing(delta)
	_advance_work(delta)
	_update_focus()

func _on_landed(vy: float) -> void:
	if vy > FALL_INJURY_SPEED:
		var k := clampf((vy - FALL_INJURY_SPEED) / 900.0, 0.0, 1.0)
		cond.injure("legs", "sprain", 0.3 + 0.6 * k)
		cond.health -= 10.0 + 30.0 * k
		message.emit("You land badly. Your ankle is sprained.")

func exertion() -> float:
	if running or (carrying and absf(velocity.x) > 1.0): return 1.0
	if swing >= 0.0: return 0.8
	if working > 0.0: return 0.4
	return 0.3 if absf(velocity.x) > 1.0 else 0.0

func _on_tick(dh: float) -> void:
	var w := GameClock.weather
	cond.tick(dh, {
		"air_c": w.air_temp_c(GameClock.clock),
		"precip": w.precip,
		"sheltered": world.sheltered_at(global_position.x),
		"heat": world.heat_at(global_position + Vector2(0, -60)),
		"exertion": exertion(),
		"wading": clampf(wade_depth / 100.0, 0.0, 1.0),
	})

# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if working > 0.0:
		return
	if event.is_action_pressed("interact") and focus:
		focus.interact(self)
	elif event.is_action_pressed("lift"):
		toggle_carry()
	elif event.is_action_pressed("stow"):
		stow()
	elif event.is_action_pressed("slot_1"):
		draw_slot(0)
	elif event.is_action_pressed("slot_2"):
		draw_slot(1)
	elif event.is_action_pressed("use") and not placing:
		use_held()

func aim_point() -> Vector2:
	return aim_override if aim_override != Vector2.INF else get_global_mouse_position()

func _update_focus() -> void:
	focus = null
	var best := REACH
	for n in get_tree().get_nodes_in_group("interactable"):
		var d: float = (n.interact_pos() - global_position).length()
		if d < best and n.interact_label(self) != "":
			best = d
			focus = n
	chop_target = null
	if held and held.def.has("axe") and carrying == null:
		best = CHOP_REACH
		for n in get_tree().get_nodes_in_group("choppable"):
			var d: float = n.chop_distance(self)
			var ahead: bool = signf(n.global_position.x - global_position.x) == facing or d < 30.0
			if d < best and ahead:
				best = d
				chop_target = n

# --- Hands -------------------------------------------------------------------

func use_held() -> void:
	if held == null or swing >= 0.0:
		return
	var d := held.def
	if d.has("axe"):
		if chop_target == null:
			message.emit("Nothing to chop within reach.")
		elif cond.spend_stamina(SWING_STAMINA):
			swing = 0.0
		else:
			message.emit("Too winded to swing. Catch your breath.")
	elif d.has("food"):
		var fresh := held.freshness(GameClock.clock.hours)
		cond.eat(d.food * ItemStack.FOOD_MULT[fresh])
		if fresh == ItemStack.Fresh.SPOILED:
			cond.health -= 8.0
			message.emit("That was spoiled. Your stomach turns.")
		_consume_one()
	elif d.capacity > 0.0:
		if held.water <= 0.001:
			message.emit("The %s is empty." % d.name.to_lower())
			return
		var sip := minf(ItemStack.SIP, held.water)
		held.water -= sip
		cond.drink(ItemStack.THIRST_PER_SIP * sip / ItemStack.SIP)
		if not held.water_clean:
			cond.health -= Creek.DIRTY_HEALTH_COST
			message.emit("Gritty creek water. Boiling it first would be safer.")
	elif d.has("medical"):
		if cond.injuries.has(d.treats) and not cond.injuries[d.treats].treated:
			cond.treat(d.treats)
			message.emit("You treat your %s." % d.treats)
			_consume_one()
		else:
			message.emit("Nothing that needs a %s." % d.name.to_lower())
	else:
		message.emit("Nothing to do with that here.")

func _consume_one() -> void:
	held.count -= 1
	if held.count <= 0:
		held = null
		held_slot = -1

func _advance_swing(delta: float) -> void:
	if swing < 0.0:
		return
	var before := swing
	swing += delta / SWING_TIME
	if before < SWING_IMPACT and swing >= SWING_IMPACT and chop_target and is_instance_valid(chop_target) and held:
		var power := held.sharpness * cond.tool_speed_mult()
		held.sharpness = maxf(0.35, held.sharpness - 0.003)
		chop_target.hit(self, power, aim_point())
	if swing >= 1.0:
		swing = -1.0

## Takes an item: into the pack, else into empty hands. Returns false if there is no room.
func receive(stack: ItemStack, allow_hands := true) -> bool:
	var label := stack.label(GameClock.clock.hours)
	if backpack.add(stack):
		message.emit("Packed: " + label)
		return true
	if allow_hands and held == null and carrying == null:
		held = stack
		message.emit("No room in the pack, carrying %s in hand." % label)
		return true
	message.emit("No room for %s." % label)
	return false

func hold(stack: ItemStack) -> void:
	if held == stack:
		return
	stow()
	for i in Backpack.ATTACH_SLOTS:
		if backpack.attachments[i] == stack:
			held_slot = i
	backpack.remove(stack)
	held = stack

func stow() -> void:
	if held == null:
		return
	var s := held
	held = null
	if held_slot >= 0 and backpack.attachments[held_slot] == null:
		backpack.attachments[held_slot] = s
	elif not backpack.add(s):
		drop_stack(s)
		message.emit("No room in the pack. You set the %s down." % s.def.name.to_lower())
	held_slot = -1

func draw_slot(i: int) -> void:
	if held and held_slot == i:
		stow()
		return
	var s: ItemStack = backpack.attachments[i]
	if s:
		hold(s)

func drop_stack(s: ItemStack) -> void:
	if held == s:
		held = null
		held_slot = -1
	backpack.remove(s)
	world.spawn({"kind": "item", "x": global_position.x + facing * 40.0, "stack": s.to_dict()})

# --- Oversized objects -------------------------------------------------------

func toggle_carry() -> void:
	if carrying:
		drop_carried()
		return
	for l in get_tree().get_nodes_in_group("log"):
		if l.holder == null and absf(l.global_position.x - global_position.x) < l.length() * 0.5 + 60.0 \
				and absf(l.global_position.y - global_position.y) < 120.0:
			stow() # both hands on the log
			carrying = l
			l.pick_up(self)
			return

func drop_carried() -> void:
	if carrying == null:
		return
	var l := carrying
	carrying = null
	if not l.dragged():
		l.global_position = global_position + Vector2(facing * (l.length() * 0.5 + 30.0), -60.0)
	l.put_down()

# --- Timed work (crafting, building) -----------------------------------------

## Busy for `seconds` of real time while `hours` of game time pass visibly, then `done` runs.
func work(seconds: float, hours: float, label: String, done: Callable) -> void:
	stow()
	working = seconds
	work_label = label
	_work_done = done
	GameClock.time_scale = hours / (seconds * 24.0 / GameClock.clock.day_length_sec)

func _advance_work(delta: float) -> void:
	if working <= 0.0:
		return
	working -= delta
	if working <= 0.0:
		GameClock.time_scale = 1.0
		work_label = ""
		_work_done.call()
