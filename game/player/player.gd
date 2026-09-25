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
const DRAW_TIME := 0.9 ## seconds to full draw
const ARROW_SPEED := Vector2(1100.0, 2800.0) ## px/s at a light and a full draw
const KNIFE_REACH := 150.0
const SPEAR_REACH := 250.0
const THRUST_TIME := 0.45
const THRUST_STAMINA := 5.0
const TORCH_HOURS := 3.0 ## a torch burns this long (faster in rain)
const HAUL_SPEED := 0.42 ## dragging a whole deer
const DEATH_LOSS_CHANCE := 0.2 ## per consumable stack (doubled roll, loses half the stack)

var world: World
var footsteps: Footsteps
var cond: Condition
var backpack := Backpack.new()
var held: ItemStack ## the one object in hand
var held_slot := -1 ## attachment slot it came from, to return it there
var carrying: WorldLog ## oversized object on the shoulder or dragged
var hauling: Carcass: ## a whole carcass dragged by the neck
	get: return hauling if is_instance_valid(hauling) else null
## Interactable in reach. Getters hide nodes freed since the last focus update (a finished
## blueprint, a fully bucked trunk) so nothing reads a dead reference.
var focus: Node:
	get: return focus if is_instance_valid(focus) else null
var chop_target: Node:
	get: return chop_target if is_instance_valid(chop_target) else null
## The thing whose list of choices is open (E on something with more than one thing to do);
## number keys pick. Closes when you move off or step away.
var menu: Node:
	get: return menu if is_instance_valid(menu) else null
var swing := -1.0 ## 0..1 through a tool swing, -1 idle
var thrust := -1.0 ## 0..1 through a spear thrust, -1 idle
var _torch_light: PointLight2D
var working := 0.0 ## real seconds of busy work left
var work_label := ""
var placing := false ## BuildMode is placing a blueprint; clicks belong to it
const RECIPES: PackedStringArray = ["splint", "vine_cord", "snare", "fishing_pole", "bow", "arrows", "spear", "deer_call",
	"hide_coat", "buckskin_leggings", "wolf_hat", "wolf_mittens", "wolf_leggings", "bear_coat"]
const WEAR_PER_SWING := 0.0012 ## handle wear; a worn tool bites weaker, never breaks
var known_recipes := RECIPES
var bow_draw := -1.0 ## 0..1, -1 not drawing
var fishing: Fishing ## set by Main
var facing := 1
var running := false
var crouching := false
var wade_depth := 0.0
var auto_dir := 0.0 ## set by smoke tests to walk without input
var auto_run := false
var auto_crouch := false
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
	_torch_light = PointLight2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	_torch_light.texture = tex
	_torch_light.texture_scale = 3.2
	_torch_light.color = Color(1.0, 0.66, 0.34)
	_torch_light.position = Vector2(0, -170)
	_torch_light.visible = false
	add_child(_torch_light)
	GameClock.ticked.connect(_on_tick)
	_starting_kit()

func _starting_kit() -> void:
	var h := GameClock.clock.hours
	backpack.attach(ItemStack.make("axe", h), 0)
	backpack.attach(ItemStack.make("knife", h), 1)
	var bottle := ItemStack.make("water_bottle", h)
	bottle.add_water(0.8, true)
	for s in [bottle, ItemStack.make("cook_pot", h), ItemStack.make("lighter", h), ItemStack.make("sleeping_bag", h),
			ItemStack.make("bandage", h, 2), ItemStack.make("jerky", h, 3), ItemStack.make("fishing_kit", h),
			ItemStack.make("cordage", h)]:
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
	crouching = (Input.is_action_pressed("crouch") or auto_crouch) and was_on_floor and working <= 0.0
	if cond.stamina < 1.0:
		_can_run = false
	elif cond.stamina > 20.0:
		_can_run = true
	running = (Input.is_action_pressed("run") or auto_run) and dir != 0.0 and not crouching and _can_run and carrying == null and hauling == null
	wade_depth = world.terrain.water_depth_at(global_position.x, global_position.y)

	if bow_draw >= 0.0:
		running = false
		bow_draw = minf(bow_draw + delta / DRAW_TIME, 1.0)
		if held == null or not held.def.has("bow"):
			bow_draw = -1.0
		else:
			facing = 1 if aim_point().x >= global_position.x else -1
	var speed := CROUCH if crouching else (RUN if running else WALK)
	if bow_draw >= 0.0:
		speed *= 0.4
	speed *= cond.move_speed_mult() * (1.0 - clampf(wade_depth / 130.0, 0.0, 0.65)) * backpack.encumbrance_mult() * snow_mult()
	if carrying:
		speed *= carrying.speed_mult()
	if hauling:
		speed *= HAUL_SPEED
	velocity.x = move_toward(velocity.x, dir * speed, ACCEL * delta)
	if running:
		cond.spend_stamina(GameClock.tuning.run_stamina_per_sec * delta)
	elif (carrying or hauling) and dir != 0.0:
		cond.stamina = maxf(cond.stamina - CARRY_STAMINA_PER_SEC * delta, 0.0)
	elif swing < 0.0:
		cond.recover_stamina(delta * (0.5 if dir != 0.0 else 1.0))

	if not was_on_floor:
		velocity.y += GRAVITY * delta
		_fall_vy = maxf(_fall_vy, velocity.y)
	elif Input.is_action_just_pressed("hop") and carrying == null and hauling == null and working <= 0.0 and cond.spend_stamina(HOP_STAMINA):
		velocity.y = -HOP
	move_and_slide()
	if not was_on_floor and is_on_floor():
		_on_landed(_fall_vy)
		footsteps.step()
		_fall_vy = 0.0
	if dir != 0.0 and bow_draw < 0.0:
		facing = 1 if dir > 0.0 else -1
	world.update_focus(global_position.x)

	_advance_swing(delta)
	_advance_thrust(delta)
	_advance_work(delta)
	var torch := holding("torch")
	_torch_light.visible = torch
	if torch:
		_torch_light.position = Vector2(facing * 34.0, -175.0)
		_torch_light.energy = (0.9 + 0.12 * sin(Time.get_ticks_msec() * 0.019) + 0.07 * sin(Time.get_ticks_msec() * 0.043)) * lerpf(0.25, 1.0, 1.0 - GameClock.clock.daylight())
	_update_focus()
	if menu and (menu != focus or dir != 0.0 or working > 0.0):
		menu = null

func _on_landed(vy: float) -> void:
	if vy > FALL_INJURY_SPEED:
		var k := clampf((vy - FALL_INJURY_SPEED) / 900.0, 0.0, 1.0)
		cond.injure("legs", "sprain", 0.3 + 0.6 * k)
		cond.health -= 10.0 + 30.0 * k
		message.emit("You land badly. Your ankle is sprained.")

## Deep snow drags at every step: knee-deep (50 cm) costs about 40% of your pace.
func snow_mult() -> float:
	var cm := GameClock.weather.snow_cm if wade_depth <= 0.0 else 0.0
	return 1.0 - clampf(cm / 125.0, 0.0, 0.45)

## How far the player's activity carries: 0 silent, ~1 loud. Animals listen for this.
func noise() -> float:
	if sleeping or dead:
		return 0.05
	var moving := absf(velocity.x) > 5.0
	var n := 0.06
	if running:
		n = 1.0
	elif moving:
		n = 0.13 if crouching else 0.42
	if swing >= 0.0 or ((carrying or hauling) and moving):
		n = maxf(n, 0.9)
	if bow_draw >= 0.0:
		n = maxf(n, 0.1)
	if wade_depth > 0.0 and moving:
		n += 0.3
	if HuntingBlind.hiding(self):
		n *= HuntingBlind.QUIET
	return n

## How easy the player is to spot: crouching and holding still help most.
func visibility() -> float:
	var moving := absf(velocity.x) > 5.0
	if crouching:
		return (0.45 if moving else 0.25) * (HuntingBlind.VISIBILITY if HuntingBlind.hiding(self) else 1.0)
	if running:
		return 1.2
	return 1.0 if moving else 0.6

func exertion() -> float:
	if running or ((carrying or hauling) and absf(velocity.x) > 1.0): return 1.0
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
		"insulation_c": (GameClock.tuning.sleeping_bag_c if sleeping and backpack.count_of("sleeping_bag") > 0 else 0.0) \
			+ backpack.insulation(),
		"air_c": w.air_temp_c(GameClock.clock),
		"precip": w.rain() + w.snowfall() * 0.25, # snow wets you far less than rain
		"sheltered": world.sheltered_at(global_position.x),
		"heat": world.heat_at(global_position + Vector2(0, -60)),
		"exertion": exertion(),
		"wading": clampf(wade_depth / 100.0, 0.0, 1.0),
	})
	if holding("torch"):
		held.condition -= dh / TORCH_HOURS * (1.0 + 2.0 * w.rain())
		if held.condition <= 0.0:
			held = null
			held_slot = -1
			message.emit("The torch gutters out.")
	if cond.is_dead():
		_die()

func holding(tag: String) -> bool:
	return held != null and held.def.has(tag)

## Raw meat on you (in the pack, in hand, or a carcass in tow) or an open wound: wolves smell it.
func smells_of_meat() -> bool:
	if hauling or (held and held.def.has("raw") and held.def.id != "trout_raw" and held.def.id != "whitefish_raw"):
		return true
	if backpack.find(func(s): return s.def.id in ["venison_raw", "rabbit_raw"]) != null:
		return true
	return cond.injuries.values().any(func(i): return i.kind == "cut" and not i.treated)

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
	if menu and event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode - KEY_1
		if k >= 0 and k < 9:
			choose(k)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("interact") and menu:
		menu = null
	elif event.is_action_pressed("interact") and focus:
		open_or_interact()
	elif event.is_action_pressed("lift"):
		if hauling:
			drop_haul()
		else:
			toggle_carry()
	elif event.is_action_pressed("stow"):
		stow()
	elif event.is_action_pressed("slot_1"):
		draw_slot(0)
	elif event.is_action_pressed("slot_2"):
		draw_slot(1)
	elif event.is_action_pressed("use") and not placing:
		use_held()
	elif event.is_action_released("use") and bow_draw >= 0.0:
		loose()

## Everything E could do with n right now: [[label, Callable]], best first. An invalid
## Callable is a note (why something can't be done yet) rather than a choice.
static func options_of(n: Node, p: Player) -> Array:
	if n.has_method("interact_options"):
		return n.interact_options(p)
	var l: String = n.interact_label(p)
	return [[l, n.interact.bind(p)]] if l != "" else []

static func choices_of(n: Node, p: Player) -> Array:
	return options_of(n, p).filter(func(o): return o[1].is_valid())

## For things with a list of options: the first one's label, and running it (scripted checks
## and single-choice E both come through here).
static func first_label(opts: Array) -> String:
	return opts[0][0] if opts else ""

static func run_first(opts: Array) -> void:
	if opts and opts[0][1].is_valid():
		opts[0][1].call()

## E: one thing to do does it; several open the list of choices.
func open_or_interact() -> void:
	var c := choices_of(focus, self)
	if c.size() > 1:
		menu = focus
	elif c.size() == 1 and focus.has_method("interact_options"):
		c[0][1].call()
	else:
		focus.interact(self)

func choose(i: int) -> void:
	var opts := choices_of(menu, self)
	menu = null
	if i < opts.size():
		opts[i][1].call()

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
			var d: float = n.chop_distance(self) - (60.0 if n is FelledTrunk else 0.0) # finish processing a felled tree first
			var ahead: bool = signf(n.global_position.x - global_position.x) == facing or d < 30.0
			if d < best and ahead:
				best = d
				chop_target = n

# --- Hands -------------------------------------------------------------------

func use_held() -> void:
	if held == null or swing >= 0.0:
		return
	var d := held.def
	if d.has("rod"):
		fishing.press()
	elif d.has("bow"):
		if backpack.count_of("arrows") == 0:
			message.emit("No arrows. Craft some from sticks.")
		else:
			bow_draw = 0.0
	elif d.has("knife"):
		_knife()
	elif d.has("spear"):
		if thrust < 0.0 and cond.spend_stamina(THRUST_STAMINA):
			thrust = 0.0
	elif d.has("torch"):
		_wave_torch()
	elif d.has("call"):
		_call()
	elif d.has("axe"):
		if chop_target == null:
			message.emit("Nothing to chop within reach.")
		elif cond.spend_stamina(SWING_STAMINA):
			swing = 0.0
		else:
			message.emit("Too winded to swing. Catch your breath.")
	elif d.has("food"):
		var fresh := held.freshness(GameClock.clock.hours)
		cond.eat(d.food * ItemStack.FOOD_MULT[fresh])
		if d.has("raw"):
			cond.health -= 6.0
			message.emit("That was raw. It sits badly; cooking it would be better.")
		elif fresh == ItemStack.Fresh.SPOILED:
			cond.health -= 8.0
			message.emit("That was spoiled. Your stomach turns.")
		_consume_one()
	elif d.capacity > 0.0:
		if held.water <= 0.001:
			var creek := Creek.reachable(self)
			if creek and not (Creek.frozen() and not creek.hole_open()):
				creek.fill(self, held)
			elif d.has("pot") and GameClock.weather.snow_cm > 5.0 and wade_depth <= 0.0:
				held.add_water(d.capacity, false)
				message.emit("You pack the pot with snow. Melt it on the fire.")
			else:
				message.emit("The %s is empty. Fill it at the creek." % d.name.to_lower())
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

## The bow hand holds; the arrow leaves from about shoulder height toward the aim.
func arrow_origin() -> Vector2:
	return global_position + Vector2(facing * 24.0, -150.0 + (30.0 if crouching else 0.0))

func arrow_velocity() -> Vector2:
	var dir := (aim_point() - arrow_origin()).normalized()
	return dir * lerpf(ARROW_SPEED.x, ARROW_SPEED.y, maxf(bow_draw, 0.0))

func loose() -> void:
	var v := arrow_velocity()
	var power := bow_draw
	bow_draw = -1.0
	if power < 0.2 or not backpack.take("arrows", 1):
		return # let down gently
	var a := Arrow.new()
	a.world = world
	a.position = arrow_origin()
	a.velocity = v
	a.arm_x = aim_point().x
	world.add_child(a)

const CALL_REACH := 3000.0

func _call() -> void:
	Sfx.play_at(self, global_position + Vector2(facing * 20.0, -170.0), Sfx.bleat(), -2.0)
	for a: Animal in get_tree().get_nodes_in_group("animals"):
		if absf(a.position.x - global_position.x) < CALL_REACH:
			a.hear_call(global_position.x)

## Waving a torch: anything wild close by backs away from the flame.
func _wave_torch() -> void:
	swing = 0.0
	for p in get_tree().get_nodes_in_group("predators"):
		if absf(p.position.x - global_position.x) < 800.0:
			p.scare(global_position.x)

## Something wild close in front (a wolf or the bear at your throat, a rabbit): the nearest
## one within reach, or null.
func _nearest_in(group: String, reach: float) -> Node2D:
	var best: Node2D = null
	for a in get_tree().get_nodes_in_group(group):
		var dx: float = a.position.x - global_position.x
		if absf(dx) < reach and (signf(dx) == facing or absf(dx) < 40.0) and (best == null or absf(dx) < absf(best.position.x - global_position.x)):
			best = a
	return best

## The spear's point lands partway through the thrust: predators are hurt, small game and
## unaware deer taken, a deer that's seen you bolts.
func _advance_thrust(delta: float) -> void:
	if thrust < 0.0:
		return
	var before := thrust
	thrust += delta / THRUST_TIME
	if before < 0.4 and thrust >= 0.4:
		var pr := _nearest_in("predators", SPEAR_REACH)
		var small := _nearest_in("small_game", SPEAR_REACH)
		var deer := _nearest_in("animals", SPEAR_REACH) as Animal
		if pr:
			pr.hurt(0.7, global_position.x)
		elif small:
			small.hurt(1.0, global_position.x)
		elif deer:
			if deer.wound < 0.0 and deer.state in [Animal.State.GRAZE, Animal.State.WALK, Animal.State.BEDDED] and deer.awareness < deer.def.alert_at:
				deer.kill()
				message.emit("One clean thrust.")
			else:
				deer.bolt()
	if thrust >= 1.0:
		thrust = -1.0

## Close work: only an animal that hasn't noticed you can be taken with the knife. A wolf or
## the bear on top of you can be fought off with it.
func _knife() -> void:
	var pr := _nearest_in("predators", KNIFE_REACH)
	if pr:
		swing = 0.0
		pr.hurt(0.45, global_position.x)
		return
	var best: Animal = null
	for a: Animal in get_tree().get_nodes_in_group("animals"):
		var d := absf(a.position.x - global_position.x)
		if d < KNIFE_REACH * a.def.size and (best == null or d < absf(best.position.x - global_position.x)):
			best = a
	if best == null:
		message.emit("Nothing to do with that here.")
		return
	swing = 0.0
	if best.wound < 0.0 and best.state in [Animal.State.GRAZE, Animal.State.WALK, Animal.State.BEDDED] and best.awareness < best.def.alert_at:
		best.kill()
		message.emit("Quick and quiet. It never knew you were there.")
	else:
		best.bolt()
		message.emit("It sees you coming and bolts.")

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
		var power := held.sharpness * lerpf(0.6, 1.0, held.condition) * cond.tool_speed_mult()
		held.sharpness = maxf(0.35, held.sharpness - 0.003)
		held.condition = maxf(0.3, held.condition - WEAR_PER_SWING)
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
	if held.def.has("torch"):
		held = null
		held_slot = -1
		message.emit("You snuff the torch in the dirt.")
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
	if s.def.has("torch"):
		stow()
		return
	if held == s:
		held = null
		held_slot = -1
	backpack.remove(s)
	world.spawn({"kind": "item", "x": global_position.x + facing * 40.0, "stack": s.to_dict()})

# --- Oversized objects -------------------------------------------------------

func nearest_log() -> WorldLog:
	var best: WorldLog = null
	var best_d := INF
	for l in get_tree().get_nodes_in_group("log"):
		var d := absf(l.global_position.x - global_position.x)
		if l.holder == null and not l.is_queued_for_deletion() and d < l.length() * 0.5 + 60.0 \
				and absf(l.global_position.y - global_position.y) < 120.0 and d < best_d:
			best = l
			best_d = d
	return best

## Takes hold of a carcass to drag it home whole: slow, hard work, both hands.
func start_haul(c: Carcass) -> void:
	stow()
	drop_carried()
	hauling = c
	c.hauler = self
	message.emit("You take hold and start dragging. Slow going. (%s to let go)" % Keys.label("lift"))

func drop_haul() -> void:
	if hauling:
		hauling.hauler = null
		hauling.queue_redraw()
	hauling = null

func toggle_carry() -> void:
	if carrying:
		drop_carried()
		return
	var l := nearest_log()
	if l:
		stow() # both hands on the log
		carrying = l
		l.pick_up(self)

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
	if not holding("torch"): # a torch stays lit in your hand while you work
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
	drop_haul()
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
	drop_haul()
	if held and held.def.has("torch"):
		held = null
	if held and not backpack.add(held):
		drop_stack(held)
	held = null
	held_slot = -1
	message.emit("Everything goes dark.")
	died.emit()

## Called once the screen is black: leave the pack where you fell, wake at camp.
func respawn() -> void:
	var lost := _death_losses()
	var worn := backpack.worn.duplicate() # your clothes stay on you
	for k in Backpack.WEAR:
		backpack.worn[k] = null
	world.spawn({"kind": "pack", "x": global_position.x, "pack": backpack.to_dict()})
	backpack = Backpack.new()
	backpack.worn = worn
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
	if hauling: return "Let go of the carcass first."
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
	if "bow" not in known_recipes: # saves from before hunting: learn it, and get the cord for a string
		backpack.add(ItemStack.make("cordage", GameClock.clock.hours))
	for r in RECIPES:
		if r not in known_recipes:
			known_recipes.append(r)
	var coat := backpack.find(func(s): return s.def.id == "hide_coat")
	if coat and backpack.worn.body == null: # before clothing slots a coat in the pack was worn
		backpack.wear(coat)
	camp_x = float(d.camp_x)
