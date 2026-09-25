class_name Player extends CharacterBody2D
## Movement, hands, and survival wiring. Presentation lives in PlayerRig, which only reads this node.

signal message(text: String)
signal died
signal made_camp ## slept at or built a shelter: autosave and respawn point

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
const DEATH_LOSS_CHANCE := 0.2 ## per consumable stack (doubled roll, loses half the stack)

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
var sleeping := false
var dead := false
var start_x := 0.0 ## where the trail begins; respawn point until a camp exists
var camp_x := -1.0 ## last camp (shelter) used; -1 = none yet

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
	if sleeping or dead:
		velocity.x = 0.0
		velocity.y += GRAVITY * delta
		move_and_slide()
		if sleeping:
			_auto_wake()
		return
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
	if dead:
		return
	if cond.is_dead(): # damage dealt outside the tick (falls, spoiled food) must not regenerate away
		_die()
		return
	var w := GameClock.weather
	cond.tick(dh, {
		"sleeping": sleeping,
		"sleep_quality": sleep_quality() if sleeping else 1.0,
		"insulation_c": GameClock.tuning.sleeping_bag_c if sleeping and backpack.count_of("sleeping_bag") > 0 else 0.0,
		"air_c": w.air_temp_c(GameClock.clock),
		"precip": w.precip,
		"sheltered": world.sheltered_at(global_position.x),
		"heat": world.heat_at(global_position + Vector2(0, -60)),
		"exertion": exertion(),
		"wading": clampf(wade_depth / 100.0, 0.0, 1.0),
	})
	if cond.is_dead():
		_die()

# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if dead or working > 0.0:
		return
	if sleeping:
		for a in ["move_left", "move_right", "hop", "interact", "rest", "use"]:
			if event.is_action_pressed(a):
				wake()
				get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("rest"):
		sleep()
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

# --- Sleep ---------------------------------------------------------------------

## Better with a sleeping bag, a roof, a fire nearby, dry clothes, warmth and a fed belly.
func sleep_quality() -> float:
	var q := 0.45
	if backpack.count_of("sleeping_bag") > 0: q += 0.25
	if world.sheltered_at(global_position.x): q += 0.1
	if world.heat_at(global_position + Vector2(0, -40)) > 0.1: q += 0.1
	q -= cond.wetness * 0.3
	if cond.warmth < 30.0: q -= 0.2
	if cond.hunger < 20.0 or cond.thirst < 20.0: q -= 0.15
	return clampf(q, 0.15, 1.0)

func sleep() -> void:
	if not world.sheltered_at(global_position.x):
		message.emit("You need shelter to sleep. A lean-to will do.")
		return
	stow()
	drop_carried()
	sleeping = true
	GameClock.time_scale = GameClock.tuning.sleep_time_scale
	for s in get_tree().get_nodes_in_group("shelter"):
		if s.covers(global_position.x):
			camp_x = s.global_position.x
	message.emit("You settle in. Any key to wake.")
	made_camp.emit()

func wake(reason := "") -> void:
	if not sleeping:
		return
	sleeping = false
	GameClock.time_scale = 1.0
	message.emit(reason if reason != "" else "You wake. (%s)" % ("rested" if cond.fatigue < 20.0 else "still tired"))

func _auto_wake() -> void:
	if cond.hunger < 8.0: wake("Hunger wakes you.")
	elif cond.thirst < 8.0: wake("Thirst wakes you.")
	elif cond.health < 25.0: wake("You wake shivering and hurt.")

# --- Death and recovery -------------------------------------------------------

func _die() -> void:
	dead = true
	sleeping = false
	working = 0.0
	swing = -1.0
	GameClock.time_scale = 1.0
	drop_carried()
	if held and not backpack.add(held):
		drop_stack(held)
	held = null
	held_slot = -1
	message.emit("Everything goes dark.")
	died.emit()

## Called once the screen is black: leave the pack where you fell, wake at camp.
func respawn() -> void:
	var lost := _death_losses()
	world.spawn({"kind": "pack", "x": global_position.x, "pack": backpack.to_dict()})
	backpack = Backpack.new()
	var x := camp_x if camp_x >= 0.0 else start_x
	global_position = Vector2(x, world.terrain.height_at(x) - 4.0)
	velocity = Vector2.ZERO
	world.update_focus(x)
	cond.health = 45.0
	cond.stamina = 100.0
	cond.hunger = maxf(cond.hunger, 35.0)
	cond.thirst = maxf(cond.thirst, 35.0)
	cond.warmth = 50.0
	cond.wetness = 0.0
	cond.fatigue = 30.0
	cond.injuries.clear()
	dead = false
	message.emit("You come to at %s. Your pack lies where you fell." % ("camp" if camp_x >= 0.0 else "the trailhead"))
	if lost != "":
		message.emit("Lost along the way: " + lost)

## Most of the pack survives. Food spoils, tools come back duller and worn, and some
## consumables (bandages, sticks) scatter. Nothing you can't replace is ever lost:
## single items (tools, lighter, containers, gear, anything "unique") always stay.
func _death_losses() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(GameClock.clock.hours * 1000.0)
	var lost: PackedStringArray = []
	for s in backpack.all_stacks():
		if s.def.has("food") and s.def.spoil_hours > 0.0:
			s.made_hour = minf(s.made_hour, GameClock.clock.hours - s.def.spoil_hours)
		elif s.def.has("tool"):
			s.sharpness = maxf(0.35, s.sharpness - 0.25)
			s.condition = maxf(0.3, s.condition - 0.2)
		elif s.def.max_stack > 1 and not s.def.has("unique") and rng.randf() < DEATH_LOSS_CHANCE * 2.0:
			var n := maxi(1, s.count / 2)
			s.count -= n
			lost.append("%d %s" % [n, s.def.name.to_lower()])
			if s.count <= 0:
				backpack.remove(s)
	return ", ".join(lost)

# --- Saving ---------------------------------------------------------------------

## "" when it's safe to save, otherwise why not.
func unsafe_reason() -> String:
	if dead: return "You can't save now."
	if not is_on_floor(): return "Get your feet on the ground first."
	if wade_depth > 0.0: return "Get out of the water first."
	if carrying: return "Set the log down first."
	if working > 0.0 or swing >= 0.0: return "Finish what you're doing first."
	if cond.health < 15.0: return "You're in too much danger to save."
	return ""

func to_dict() -> Dictionary:
	return {"x": global_position.x, "y": global_position.y, "facing": facing, "cond": cond.to_dict(),
		"pack": backpack.to_dict(), "held": held.to_dict() if held else null, "held_slot": held_slot,
		"recipes": Array(known_recipes), "camp_x": camp_x}

func from_dict(d: Dictionary) -> void:
	global_position = Vector2(float(d.x), float(d.y))
	facing = int(d.facing)
	cond.from_dict(d.cond)
	backpack.from_dict(d.pack)
	held = ItemStack.from_dict(d.held) if d.held else null
	held_slot = int(d.held_slot)
	known_recipes = PackedStringArray(d.recipes)
	camp_x = float(d.camp_x)
