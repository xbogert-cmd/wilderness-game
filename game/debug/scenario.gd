class_name Scenario extends Node
## Scripted end-to-end check of the camp loop, driven through the player's real actions:
## fell → strip → buck → haul logs → build lean-to → gather sticks → build + light fire →
## fill pot at creek → boil → pour → drink → leave and return (persistence + catch-up).
## Run: godot --headless --fixed-fps 60 -- --scenario     (exit code = failed checks)
## Mode "life": sleep, autosave, save to slot 3, die, respawn, recover the pack.
## Mode "verify": run with --load=3 after "life"; checks the save came back exactly.
## Mode "winter": woodpile, seasons, snow, tracks in snow, frozen creek, snow in the pot,
## then the camp builds: hide frame and coat, drying rack, log cabin.

var player: Player
var world: World
var shot := ""
var mode := "camp"
var EXPECT := SaveGame.DIR + "/scenario_expect.json"
var failures := 0

func _ready() -> void:
	player.message.connect(func(t): print("  msg: ", t))
	match mode:
		"life": _life.call_deferred()
		"verify": _verify.call_deferred()
		"wild": _wild.call_deferred()
		"winter": _winter.call_deferred()
		_: _run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func teleport(x: float) -> void:
	player.global_position = Vector2(x, world.terrain.height_at(x) - 4.0)
	player.velocity = Vector2.ZERO
	await frames(6)

## A left click pushed through the viewport, so GUI controls get their chance to eat it.
func click(at := Vector2.INF) -> void:
	if at == Vector2.INF:
		at = get_viewport().get_visible_rect().size * 0.5
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	get_viewport().push_input(move, true)
	await frames(2)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		get_viewport().push_input(e, true)
		await frames(1)

func swing() -> void:
	player.use_held()
	await frames(int(Player.SWING_TIME * 60.0) + 2)
	player.cond.stamina = 100.0 # the check is about the loop, not pacing

func find_fire() -> Campfire:
	for f in get_tree().get_nodes_in_group("heat"):
		if not f.is_queued_for_deletion():
			return f
	return null

func count_logs(size: String) -> int:
	return get_tree().get_nodes_in_group("log").filter(func(l): return l.size == size and not l.is_queued_for_deletion()).size()

func _run() -> void:
	await frames(10)
	var camp_x := 3200.0
	player.draw_slot(0)
	check(player.held and player.held.def.has("axe"), "draws hatchet from strap 1")

	# --- Fell trees until the lean-to's logs exist -------------------------------
	var felled := 0
	while (count_logs("long") < 2 or count_logs("medium") < 4) and felled < 6:
		var tree: ChoppableTree = null
		for t in get_tree().get_nodes_in_group("choppable"):
			if t is ChoppableTree and t.conifer and t.height > 1150.0 and absf(t.global_position.x - camp_x) > 400.0:
				if tree == null or absf(t.global_position.x - camp_x) < absf(tree.global_position.x - camp_x):
					tree = t
		if tree == null:
			break
		player.facing = 1
		await teleport(tree.global_position.x - 70.0)
		if felled == 0:
			await click()
			check(player.swing >= 0.0, "a real left click swings the hatchet (no UI swallows it)")
			await frames(int(Player.SWING_TIME * 60.0) + 2)
		var guard := 0
		var depths := []
		while not tree.felled and guard < 60:
			await swing()
			guard += 1
			if felled == 0 and guard <= 3 and tree._notch:
				depths.append(absf(tree._notch.polygon[1].x - tree._notch.polygon[0].x))
		if felled == 0:
			check(depths.size() == 3 and depths[2] > depths[0], "each blow bites the notch deeper %s" % str(depths))
		check(tree.felled, "tree felled in %d swings" % guard)
		felled += 1
		await frames(int(ChoppableTree.FALL_TIME * 60.0) + 10)
		var trunk: FelledTrunk = null
		for t in get_tree().get_nodes_in_group("choppable"):
			if t is FelledTrunk and absf(t.base_x - tree.global_position.x) < 60.0:
				trunk = t
		check(trunk != null, "felled tree left a trunk")
		if trunk == null:
			continue
		var strip_guard := 0
		while trunk.branches > 0 and strip_guard < 20:
			await swing()
			strip_guard += 1
		check(trunk.branches == 0, "branches stripped")
		# Buck from the tip end: long pieces first, then medium.
		var cuts := 0
		while is_instance_valid(trunk) and not trunk.is_queued_for_deletion() and trunk.length >= 200.0 and cuts < 8:
			cuts += 1
			var want := "long" if count_logs("long") < 2 and trunk.length >= 320.0 else "medium"
			var mark_x: float = trunk.base_x + trunk.dir * FelledTrunk.MARKS[want]
			player.facing = int(trunk.dir)
			await teleport(mark_x - trunk.dir * 60.0) # stand by the cut, as a player would
			player.aim_override = Vector2(mark_x, world.terrain.height_at(mark_x))
			print("  cut %s: player x %.0f, trunk base %.0f dir %.0f len %.0f, dist %.0f, target %s" % [want, player.global_position.x, trunk.base_x, trunk.dir, trunk.length, trunk.chop_distance(player), player.chop_target])
			for k in FelledTrunk.HITS_PER_CUT:
				await swing()
			await frames(30)
		player.aim_override = Vector2.INF
	check(count_logs("long") >= 2 and count_logs("medium") >= 4, "logs cut: %d long, %d medium" % [count_logs("long"), count_logs("medium")])

	# --- Lean-to --------------------------------------------------------------
	player.stow()
	var bp := world.spawn({"kind": "blueprint", "build": "lean_to", "x": camp_x}) as Blueprint
	for size in ["long", "long", "medium", "medium", "medium", "medium"]:
		var lg: WorldLog = null
		for l in get_tree().get_nodes_in_group("log"):
			if l.size == size and l.holder == null and not l.is_queued_for_deletion():
				lg = l
				break
		if lg == null:
			break
		await teleport(lg.global_position.x)
		player.toggle_carry()
		check(player.carrying == lg, "lifted %s log (%s)" % [size, "drag" if lg.dragged() else "shoulder"])
		await teleport(camp_x + 40.0)
		await frames(20)
		if lg.dragged():
			check(absf(lg.global_position.y - world.terrain.height_at(lg.global_position.x)) < 140.0, "dragged log follows the ground")
		elif size == "medium":
			var above: float = player.global_position.y - lg.global_position.y
			check(above > 150.0 and above < 200.0 and lg.rotation * player.facing < 0.0, "medium log rides the shoulder, front end up (%.0f px up)" % above)
		bp.interact(player)
	check(bp.complete(), "lean-to materials delivered: " + str(bp.delivered))
	bp.interact(player)
	await frames(int(Builds.STRUCTURES.lean_to.seconds * 60.0) + 10)
	var lean := get_tree().get_first_node_in_group("shelter") as LeanTo
	check(lean != null, "lean-to built")
	check(world.sheltered_at(camp_x), "lean-to shelters")

	# --- Sticks, campfire -----------------------------------------------------
	for it in get_tree().get_nodes_in_group("interactable"):
		if it is WorldItem and it.stack.def.id == "sticks" and player.backpack.count_of("sticks") < 5:
			await teleport(it.global_position.x)
			it.interact(player)
	check(player.backpack.count_of("sticks") >= 3, "gathered sticks: %d" % player.backpack.count_of("sticks"))
	var fire_x := camp_x + 260.0
	await teleport(fire_x)
	# Through the real build UI: B, click the Campfire button, click the ground.
	var key := InputEventAction.new()
	key.action = "build"
	key.pressed = true
	get_viewport().push_input(key)
	await frames(2)
	var menu := (get_tree().get_first_node_in_group("build_mode") as BuildMode).menu
	check(menu.visible, "B opens the build menu")
	await click((menu.get_child(0) as Button).get_global_rect().get_center())
	check(player.placing, "clicking Campfire starts placement")
	player.aim_override = Vector2(fire_x, world.terrain.height_at(fire_x))
	await click()
	player.aim_override = Vector2.INF
	var fbp: Blueprint = null
	for b in get_tree().get_nodes_in_group("structure"):
		if b is Blueprint and absf(b.global_position.x - fire_x) < 40.0:
			fbp = b
			print("  blueprint at %d (aimed %d)" % [b.global_position.x, fire_x])
			fire_x = b.global_position.x
	check(fbp != null, "left click places the campfire blueprint")
	if fbp == null:
		fbp = world.spawn({"kind": "blueprint", "build": "campfire", "x": fire_x}) as Blueprint
	await teleport(fire_x)
	fbp.interact(player)
	check(fbp.complete(), "campfire sticks delivered")
	fbp.interact(player)
	await frames(int(Builds.STRUCTURES.campfire.seconds * 60.0) + 10)
	var fire := find_fire()
	check(fire != null, "campfire built")
	var strikes: int = player.backpack.find(func(s): return s.def.has("lighter")).uses_left
	fire.interact(player)
	check(fire.lit, "fire lit with the lighter")
	check(player.backpack.find(func(s): return s.def.has("lighter")).uses_left == strikes - 1, "lighter used one strike")
	var sticks_before := player.backpack.count_of("sticks")
	fire.interact(player)
	check(player.backpack.count_of("sticks") < sticks_before or sticks_before == 0, "fed sticks from the pack")

	# --- Pot tripod over the fire (the pot needs it to boil) -----------------------
	var pot: ItemStack = player.backpack.find(func(s): return s.def.id == "cook_pot")
	player.hold(pot)
	check(fire.interact_label(player).begins_with("The pot needs a tripod"), "no tripod yet: the fire says the pot needs one")
	player.stow()
	player.backpack.add(ItemStack.make("sticks", GameClock.clock.hours, 3))
	var tbp := world.spawn({"kind": "blueprint", "build": "tripod", "x": fire.global_position.x}) as Blueprint
	check(fire.interact_label(player) == "", "the fire yields the prompt to the tripod blueprint over it")
	tbp.interact(player)
	check(tbp.complete(), "tripod sticks delivered")
	tbp.interact(player)
	await frames(int(Builds.STRUCTURES.tripod.seconds * 60.0) + 10)
	check(fire.tripod and not is_instance_valid(tbp), "pot tripod built over the fire")

	# --- Water: creek → pot → boil → bottle → drink -----------------------------
	player.hold(pot)
	await teleport(Terrain.CREEK_X)
	var creek := get_tree().get_nodes_in_group("interactable").filter(func(n): return n is Creek)[0] as Creek
	check(Creek.reachable(player) == creek, "pack sees the creek in reach (Fill button)")
	var spare: ItemStack = player.backpack.find(func(s): return s.def.id == "water_bottle")
	var spare_was := [spare.water, spare.water_clean]
	spare.water = 0.0
	player.hold(spare)
	player.use_held()
	check(spare.water > 0.5 and not spare.water_clean, "click with an empty bottle at the creek fills it")
	spare.water = spare_was[0]
	spare.water_clean = spare_was[1]
	player.hold(pot)
	creek.interact(player)
	check(pot.water > 1.0 and not pot.water_clean, "pot filled with dirty creek water (%.2f L)" % pot.water)
	await teleport(fire_x)
	fire = find_fire() # the camp chunk unloaded while we were at the creek; this is its respawned fire
	check(fire != null and fire.lit and fire.tripod, "fire (and its tripod) still there after the camp chunk reloaded")
	fire.interact(player)
	check(fire.pot == pot and player.held == null, "pot set on the fire")
	var bottle: ItemStack = player.backpack.find(func(s): return s.def.id == "water_bottle")
	check(pot.pour_into(bottle) != "", "can't mix: pouring dirty pot into clean bottle refused")
	GameClock.time_scale = 30.0
	var guard := 0
	while not pot.water_clean and guard < 600:
		await frames(1)
		guard += 1
	GameClock.time_scale = 1.0
	check(pot.water_clean, "water boiled clean")
	var bottle_had := bottle.water
	bottle.water = 0.0
	player.hold(bottle)
	check(fire.interact_label(player).begins_with("Fill the water bottle from the pot"), "fill the bottle straight from the hanging pot")
	fire.interact(player)
	check(bottle.water > 0.9 and bottle.water_clean and fire.pot == pot, "bottle filled clean, pot still hanging (%.2f L)" % bottle.water)
	pot.add_water(bottle.water, true) # put it back for the rest of the loop
	bottle.water = bottle_had
	player.stow()
	fire.interact(player)
	check(player.held == pot, "took the pot back")
	check(pot.pour_into(bottle) == "", "poured clean water into the bottle")
	player.hold(bottle)
	player.cond.thirst = 50.0
	player.use_held()
	check(player.cond.thirst > 50.0 and player.cond.health >= 99.0, "drank clean water without harm")

	# --- Leave and come back: persistence and catch-up ----------------------
	var fuel_before := fire.fuel
	var hours_before := GameClock.clock.hours
	player.stow()
	await teleport(camp_x + 3.0 * Terrain.CHUNK_W)
	await frames(10)
	check(get_tree().get_nodes_in_group("shelter").is_empty(), "camp unloaded when far away")
	GameClock.clock.hours += 1.0 # time passes while away
	await teleport(camp_x + 300.0)
	await frames(10)
	var fire2 := find_fire()
	check(get_tree().get_first_node_in_group("shelter") != null, "lean-to still there on return")
	var expect := maxf(fuel_before - 1.0, 0.0)
	check(fire2 != null and absf(fire2.fuel - expect) < 0.1 and fire2.lit == (expect > 0.0),
		"fire caught up on the hour away (%.2f → %.2f h fuel, lit %s)" % [fuel_before, fire2.fuel if fire2 else -1.0, fire2.lit if fire2 else false])
	check(GameClock.clock.hours > hours_before, "time kept moving")

	if shot != "":
		get_viewport().get_camera_2d().reset_smoothing()
		await frames(60)
		get_viewport().get_texture().get_image().save_png(shot)
	print("scenario failures: ", failures)
	get_tree().quit(failures)

# --- Mode "life" ------------------------------------------------------------------

func _life() -> void:
	await frames(10)
	var main := get_parent()
	DirAccess.remove_absolute(SaveGame.path("auto"))
	player.sleep()
	check(not player.sleeping, "can't sleep without shelter")
	var lean_x := player.global_position.x + 200.0
	world.spawn({"kind": "lean_to", "x": lean_x, "fresh": true})
	check(absf(player.camp_x - lean_x) < 1.0, "a new lean-to becomes camp")
	check(not SaveGame.read("auto").is_empty(), "building camp autosaved")
	await teleport(lean_x)
	player.cond.fatigue = 80.0
	var h0 := GameClock.clock.hours
	player.sleep()
	check(player.sleeping, "sleeps under the lean-to")
	await frames(240)
	check(GameClock.clock.hours - h0 > 3.0, "time runs fast while asleep (%.1f h in 4 s)" % (GameClock.clock.hours - h0))
	check(player.cond.fatigue < 50.0, "sleep restores (fatigue %.0f)" % player.cond.fatigue)
	player.wake()
	check(not player.sleeping and GameClock.time_scale == 1.0, "wakes on demand, time back to normal")
	player.cond.hunger = 9.0
	player.sleep()
	await frames(120)
	check(not player.sleeping, "hunger wakes you")
	player.cond.hunger = 80.0

	# Set up a distinctive state, save it, and record what to expect after loading.
	world.spawn({"kind": "campfire", "x": lean_x + 300.0, "fuel": 5.0, "lit": true})
	world.spawn({"kind": "log", "size": "long", "x": lean_x - 250.0, "y": world.terrain.height_at(lean_x - 250.0) - 30.0})
	player.backpack.add(ItemStack.make("berries", GameClock.clock.hours - 30.0, 3)) # already stale
	var jerky: ItemStack = player.backpack.find(func(s): return s.def.id == "jerky")
	player.drop_stack(jerky)
	var bottle: ItemStack = player.backpack.find(func(s): return s.def.id == "water_bottle")
	bottle.water = 0.0
	bottle.add_water(0.6, false)
	GameClock.force_weather(Weather.Kind.DRIZZLE)
	await frames(5)
	check(main.save_to("3") == OK, "saved to slot 3")
	var ids := player.backpack.entries.map(func(e): return "%s@%d,%d" % [e.stack.def.id, e.pos.x, e.pos.y])
	ids.sort()
	var expect := {"x": player.global_position.x, "hours": GameClock.clock.hours, "weather": GameClock.weather.kind,
		"health": player.cond.health, "fatigue": player.cond.fatigue, "camp_x": player.camp_x, "pack": ids,
		"bottle": bottle.water, "bottle_clean": bottle.water_clean,
		"berries_made": player.backpack.find(func(s): return s.def.id == "berries").made_hour}
	var f := FileAccess.open(EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify(expect))
	f.close()

	# Death: the pack stays where you fell, you wake at camp, then go get it.
	var death_x := lean_x + 1500.0
	await teleport(death_x)
	var carried := player.backpack.all_stacks().size()
	player.cond.health = 0.0
	await frames(5)
	check(player.dead, "health at zero kills")
	await frames(60 * 5)
	check(not player.dead, "respawned after the fade")
	check(absf(player.global_position.x - lean_x) < 5.0, "woke at camp")
	check(player.backpack.all_stacks().is_empty(), "arrived without the pack")
	var dropped: DroppedPack = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is DroppedPack:
			dropped = n
	check(dropped != null and absf(dropped.global_position.x - death_x) < 5.0, "pack lies where you fell")
	player.receive(ItemStack.make("sticks", GameClock.clock.hours, 2)) # gathered on the way back
	await teleport(death_x)
	if dropped: dropped.interact(player)
	var back := player.backpack.all_stacks().size()
	check(back >= carried, "recovered the pack (%d stacks + sticks, had %d)" % [back - 1, carried])
	check(player.backpack.count_of("axe") == 1 and player.backpack.count_of("lighter") == 1, "essential tools never lost")
	var axe: ItemStack = player.backpack.find(func(s): return s.def.id == "axe")
	check(axe.sharpness < 1.0, "tools come back duller (%d%%)" % int(axe.sharpness * 100))
	var food: ItemStack = player.backpack.find(func(s): return s.def.has("food"))
	check(food == null or food.freshness(GameClock.clock.hours) == ItemStack.Fresh.SPOILED, "food spoiled")
	check(player.backpack.count_of("sticks") >= 2, "things gathered since were kept")
	print("scenario failures: ", failures)
	get_tree().quit(failures)

# --- Mode "verify" (run with --load=3) -------------------------------------------

func _verify() -> void:
	await frames(10)
	var e: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
	check(absf(player.global_position.x - float(e.x)) < 5.0, "position restored")
	check(absf(GameClock.clock.hours - float(e.hours)) < 0.05, "time restored")
	check(GameClock.weather.kind == int(e.weather), "weather restored")
	check(absf(player.cond.health - float(e.health)) < 0.5 and absf(player.cond.fatigue - float(e.fatigue)) < 0.5, "condition restored")
	check(absf(player.camp_x - float(e.camp_x)) < 1.0, "camp restored")
	var ids := player.backpack.entries.map(func(x): return "%s@%d,%d" % [x.stack.def.id, x.pos.x, x.pos.y])
	ids.sort()
	check(ids == e.pack, "pack layout restored exactly")
	var bottle: ItemStack = player.backpack.find(func(s): return s.def.id == "water_bottle")
	check(bottle and absf(bottle.water - float(e.bottle)) < 0.01 and bottle.water_clean == bool(e.bottle_clean), "dirty bottle stays dirty")
	check(get_tree().get_first_node_in_group("shelter") != null, "lean-to restored")
	var fire := find_fire()
	check(fire != null and fire.lit, "campfire restored, still lit")
	var jerky := get_tree().get_nodes_in_group("interactable").filter(func(n): return n is WorldItem and n.stack.def.id == "jerky")
	check(jerky.size() == 1, "dropped jerky still on the ground")
	var logs := get_tree().get_nodes_in_group("log").filter(func(l): return l.size == "long")
	check(logs.size() == 1, "cut log still lying by camp")
	var berries: ItemStack = player.backpack.find(func(s): return s.def.id == "berries")
	check(berries and absf(berries.made_hour - float(e.berries_made)) < 0.01 and berries.freshness(GameClock.clock.hours) == ItemStack.Fresh.STALE, "food keeps its age: stale berries are still stale")
	print("scenario failures: ", failures)
	get_tree().quit(failures)

# --- Mode "wild": wildlife, tracks, fishing ---------------------------------------

func _deer(x: float, seed_value: int) -> Animal:
	for a in get_tree().get_nodes_in_group("animals"):
		a.queue_free() # a clean slate, so only this deer reacts
	await frames(2)
	var wl: Wildlife = get_parent().find_children("*", "Wildlife", false, false)[0]
	var a := wl.spawn(Wildlife.SPECIES[0], x, seed_value)
	a.state = Animal.State.GRAZE
	a.facing = 1 # grazing, facing away
	return a

func _carcasses() -> Array:
	return get_tree().get_nodes_in_group("persist").filter(func(n): return n is Carcass and not n.is_queued_for_deletion())

## Aim point that allows for the arrow's drop over the distance (a player learns this by eye).
func _lead(target: Vector2) -> Vector2:
	var t := (target - player.arrow_origin()).length() / Player.ARROW_SPEED.y
	return target - Vector2(0, 0.5 * Arrow.GRAVITY * t * t)

func _hunt() -> void:
	player.stow()
	await teleport(9000.0)
	player.cond.stamina = 100.0
	var deer: Animal = await _deer(9110.0, 21)
	player.draw_slot(1)
	check(player.held and player.held.def.has("knife"), "knife in hand")
	deer.awareness = 0.0
	player.use_held()
	await frames(3)
	check(_carcasses().size() == 1, "the knife takes a deer that never noticed you")
	await frames(int(Player.SWING_TIME * 60.0) + 2)
	deer = await _deer(9110.0, 22)
	deer.state = Animal.State.ALERT
	deer.awareness = deer.def.alert_at
	player.use_held()
	await frames(3)
	check(deer.state == Animal.State.FLEE and _carcasses().size() == 1, "an alert deer bolts before the knife reaches it")
	await frames(int(Player.SWING_TIME * 60.0) + 2)

	var carcass: Carcass = _carcasses()[0]
	await teleport(carcass.global_position.x)
	check(carcass.interact_label(player) == "Field dress", "carcass offers field dressing")
	carcass.interact(player)
	await frames(int(Carcass.DRESS_SECONDS * 60.0) + 10)
	check(player.backpack.count_of("venison_raw") == Carcass.MEAT and _carcasses().is_empty(), "field dressed: %d venison" % player.backpack.count_of("venison_raw"))
	check(player.backpack.count_of("deer_hide") == 1 or (player.held and player.held.def.id == "deer_hide"), "and a raw deer hide")

	# Scent: the same still, standing player, 700 px off: smelled downwind, not upwind.
	player.stow()
	for wind in [1, -1]:
		GameClock.weather.wind_dir = wind
		await teleport(9000.0)
		deer = await _deer(9700.0, 40 + wind)
		deer.facing = 1 # looking away: only the nose can find you
		await frames(60 * 3)
		if wind == 1:
			check(deer.awareness >= deer.def.alert_at, "downwind, it smells you at 7 m and looks up (%.2f)" % deer.awareness)
		else:
			check(deer.awareness < 0.1, "upwind, it never knows you're there (%.2f)" % deer.awareness)
	GameClock.weather.wind_dir = -1

	# Hunting blind: a deer walking toward you, looking your way, spots a crouched player in
	# the open, but walks on unaware of one crouched in the blind.
	player.stow()
	for with_blind in [false, true]:
		await teleport(9000.0)
		if with_blind:
			world.spawn({"kind": "blind", "x": 9000.0})
		player.auto_crouch = true
		await frames(10)
		deer = await _deer(9230.0, 30 if with_blind else 31)
		deer.state = Animal.State.WALK
		deer.facing = -1
		deer._timer = 60.0 # keep walking for the test
		await frames(60 * 3)
		if with_blind:
			check(HuntingBlind.hiding(player) and deer.awareness < deer.def.alert_at * 0.5 and deer.state != Animal.State.FLEE, "in the blind it walks on, unaware (%.2f)" % deer.awareness)
		else:
			check(deer.awareness >= deer.def.alert_at, "in the open it spots you crouching (%.2f)" % deer.awareness)
	player.auto_crouch = false

	# Game trail: a deer on a trail walks from its bedding cover toward the feeding ground at dawn.
	await teleport(3000.0)
	var t := Wildlife.trail(1)
	var wl: Wildlife = get_parent().find_children("*", "Wildlife", false, false)[0]
	for a in get_tree().get_nodes_in_group("animals"):
		a.queue_free()
	await frames(2)
	var trail_deer := wl.spawn(Wildlife.SPECIES[0], t.x, 50)
	trail_deer.bed_x = t.x
	trail_deer.feed_x = t.y
	trail_deer.def = trail_deer.def.duplicate()
	trail_deer.def.hearing = 0.0 # the check is about the trail, not the player
	trail_deer.def.sight = 0.0
	trail_deer.def.scent = 0.0
	trail_deer._timer = 0.1
	await frames(60 * 12)
	var moved: float = (trail_deer.position.x - t.x) * signf(t.y - t.x)
	check(moved > 300.0, "at dawn it walks its trail toward the feeding ground (%.0f px)" % moved)
	check(Chunk.on_trail(lerpf(t.x, t.y, 0.5)), "the trail between its bed and feed shows on the ground")

	# Bait: a deer drifts to a bait pile and feeds there.
	trail_deer.queue_free()
	await teleport(9000.0)
	deer = await _deer(10400.0, 51)
	deer.def = deer.def.duplicate()
	deer.def.hearing = 0.0
	deer.def.sight = 0.0
	deer.def.scent = 0.0
	var bait := world.spawn({"kind": "bait", "x": 11400.0, "laid": GameClock.clock.hours}) as BaitPile
	deer._timer = 0.1
	var walked := 0
	while absf(deer.position.x - 11400.0) > 80.0 and walked < 60 * 30:
		await frames(1)
		walked += 1
	check(absf(deer.position.x - 11400.0) <= 80.0, "it walks 10 m to the bait pile (%.0f s)" % (walked / 60.0))
	var had := bait.amount
	await frames(60 * 8)
	check(not is_instance_valid(bait) or bait.amount < had or deer.state != Animal.State.GRAZE, "and feeds on it")
	if is_instance_valid(bait):
		bait.queue_free()

	# Deer call: curious deer come toward the caller; overdo it and they turn wary.
	deer = await _deer(10500.0, 52)
	deer.def = deer.def.duplicate()
	deer.def.hearing = 0.0
	deer.def.sight = 0.0
	deer.def.scent = 0.0
	player.hold(ItemStack.make("deer_call", GameClock.clock.hours))
	var before := absf(deer.position.x - player.global_position.x)
	player.use_held()
	await frames(60 * 6)
	var after := absf(deer.position.x - player.global_position.x)
	check(after < before - 150.0, "a bleat brings it closer (%.0f → %.0f px)" % [before, after])
	player.use_held()
	player.use_held()
	check(deer.state == Animal.State.ALERT, "a third call in a row and it turns wary")
	player.stow()

	# Vines: gathered and twisted into cord, which strings a bow as well as paracord.
	var vines := get_tree().get_nodes_in_group("interactable").filter(func(n): return n is VineTangle and n.ripe())
	check(vines.size() > 0, "vine tangles grow in the valley (%d nearby)" % vines.size())
	await teleport(vines[0].global_position.x)
	vines[0].interact(player)
	check(player.backpack.count_of("vine") == VineTangle.YIELD and not vines[0].ripe(), "gathered %d vines" % VineTangle.YIELD)
	player.backpack.add(ItemStack.make("vine", GameClock.clock.hours, 1))
	for k in Builds.RECIPES.vine_cord.needs:
		player.backpack.take(k, Builds.RECIPES.vine_cord.needs[k])
	player.receive(ItemStack.make("vine_cord", GameClock.clock.hours))
	check(player.backpack.count_of("#cord") == 2, "vine cord and paracord both count as cord")

	# Bow: craft it and some arrows from sticks and the paracord in the starting kit.
	check(player.backpack.count_of("cordage") == 1, "paracord in the starting kit")
	player.backpack.add(ItemStack.make("sticks", GameClock.clock.hours, 5))
	for id in ["bow", "arrows"]:
		var r: Dictionary = Builds.RECIPES[id]
		for k in r.needs:
			check(player.backpack.take(k, r.needs[k]), "have %s for the %s" % [k, id])
		player.receive(ItemStack.make(id, GameClock.clock.hours, r.get("count", 1)))
	check(player.backpack.count_of("bow") == 1 and player.backpack.count_of("arrows") == 4, "crafted a bow and 4 arrows")
	player.hold(player.backpack.find(func(st): return st.def.has("bow")))

	# A chest shot from 9 m: it runs a short way, bleeding, and drops.
	await teleport(9000.0)
	deer = await _deer(9900.0, 23)
	await frames(2) # let it settle onto the ground before aiming
	player.aim_override = _lead(deer.position + Vector2(30.0, -92.0))
	player.use_held()
	await frames(int(Player.DRAW_TIME * 60.0) + 5)
	check(player.bow_draw >= 1.0 and deer.state != Animal.State.FLEE, "full draw at 9 m without spooking it")
	player.loose()
	check(player.backpack.count_of("arrows") == 3, "loosing spends an arrow")
	var guard := 0
	while deer.wound < 0.0 and is_instance_valid(deer) and guard < 120:
		await frames(1)
		guard += 1
	check(is_instance_valid(deer) and deer.wound >= 0.0 and deer.wound < 3.1, "chest hit: a quick kill")
	world.tracks.prints.clear()
	guard = 0
	while is_instance_valid(deer) and guard < 400:
		await frames(1)
		guard += 1
	check(_carcasses().size() == 1, "it dropped after %.1f s" % (guard / 60.0))
	var ran: float = _carcasses()[0].global_position.x - 9900.0
	check(ran > 150.0 and ran < 2500.0, "it ran %.0f px before falling" % ran)
	check(world.tracks.prints.any(func(p): return p.s == "blood"), "it left a blood trail")

	# A shot too far back only wounds: it runs much longer, but still goes down.
	_carcasses()[0].free()
	await teleport(9000.0)
	deer = await _deer(9900.0, 24)
	await frames(2) # let it settle onto the ground before aiming
	player.aim_override = _lead(deer.position + Vector2(-40.0, -92.0))
	player.use_held()
	await frames(int(Player.DRAW_TIME * 60.0) + 5)
	player.loose()
	guard = 0
	while deer.wound < 0.0 and guard < 120:
		await frames(1)
		guard += 1
	check(deer.wound > 5.0, "gut shot: wounded, not down (%.1f s left)" % deer.wound)
	guard = 0
	while is_instance_valid(deer) and guard < 60 * 20:
		await frames(1)
		guard += 1
	check(_carcasses().size() == 1, "the wounded deer goes down after %.1f s" % (guard / 60.0))
	var tr := world.tracks
	await teleport(tr.prints.filter(func(p): return p.s == "blood")[0].x)
	tr.interact(player)

	# A miss lands in the dirt: usually recoverable.
	player.aim_override = player.global_position + Vector2(400.0, 60.0)
	player.use_held()
	await frames(int(Player.DRAW_TIME * 60.0) + 5)
	player.loose()
	await frames(40)
	var left := player.backpack.count_of("arrows")
	check(get_tree().get_nodes_in_group("interactable").any(func(n): return n is WorldItem and n.stack.def.id == "arrows") or left == 1, "a missed arrow lands on the ground (or breaks)")
	player.aim_override = Vector2.INF
	player.stow()

func _winter() -> void:
	await frames(10)
	GameClock.force_weather(Weather.Kind.CLEAR)

	# Woodpile: the stack's shape follows the count; logs go in, come out, and feed a fire.
	check(Woodpile._rows(3) == PackedInt32Array([2, 1]) and Woodpile._rows(6) == PackedInt32Array([3, 2, 1]) \
		and Woodpile._rows(7) == PackedInt32Array([4, 3]) and Woodpile._rows(15) == PackedInt32Array([5, 4, 3, 2, 1]), "stack shapes: 3 → 2+1, 6 → 3+2+1, 7 → 4+3, 15 → full pyramid")
	var x := 4200.0
	await teleport(x)
	var pile := world.spawn({"kind": "woodpile", "x": x + 60.0}) as Woodpile
	for i in 3:
		var lg := world.spawn({"kind": "log", "size": "short", "x": x - 40.0, "y": world.terrain.height_at(x - 40.0) - 30.0}) as WorldLog
		await frames(2)
		player.toggle_carry()
		check(player.carrying == lg, "lifted short log %d" % (i + 1))
		check(pile.interact_label(player).begins_with("Stack log"), "woodpile offers to stack it")
		pile.interact(player)
	check(pile.logs == 3 and player.carrying == null, "three logs stacked (%d)" % pile.logs)
	pile.interact(player)
	check(player.carrying != null and player.carrying.size == "short" and pile.logs == 2, "took a log back off the pile")
	player.drop_carried()
	await frames(2)
	var fire := world.spawn({"kind": "campfire", "x": x + 300.0, "fuel": 0.5, "lit": true}) as Campfire
	await teleport(x + 300.0)
	check(fire.interact_label(player).begins_with("Add a log from the woodpile"), "the fire feeds from the woodpile nearby")
	fire.interact(player)
	check(pile.logs == 1 and fire.fuel > 3.0, "one log from the pile went on the fire (fuel %.1f h)" % fire.fuel)

	# Into winter: the cold turns rain to snow, it lies, slows you, and holds every track.
	GameClock.clock.hours = 24.0 * GameClock.clock.days_per_season * 1.5 + 11.0 # midwinter morning
	check(GameClock.clock.season_name() == "midwinter", "it's %s" % GameClock.clock.season_name())
	check(GameClock.weather.air_temp_c(GameClock.clock) < -2.0, "and cold: %.0f °C" % GameClock.weather.air_temp_c(GameClock.clock))
	GameClock.force_weather(Weather.Kind.RAIN)
	GameClock.time_scale = 40.0
	await frames(120) # ~2 game hours of heavy snow
	GameClock.time_scale = 1.0
	var w := GameClock.weather
	check(w.snowfall() > 0.9 and w.rain() < 0.1, "it falls as snow")
	check(w.snow_cm > 5.0, "snow lies %.0f cm deep" % w.snow_cm)
	check(player.snow_mult() < 1.0, "deep snow slows you (%.0f%% pace)" % (player.snow_mult() * 100.0))
	GameClock.force_weather(Weather.Kind.CLEAR)
	world.tracks.prints.clear()
	var dry := 6500.0
	while world.terrain.soft_at(dry) or world.terrain.soft_at(dry + 200.0):
		dry += 50.0 # somewhere that would take no prints without snow
	await teleport(dry)
	player.auto_dir = 1.0
	await frames(90)
	player.auto_dir = 0.0
	check(world.tracks.prints.any(func(p): return p.s == "boot"), "boots print in the snow anywhere")

	# The creek freezes: the ice bears you, holes must be chopped, fishing waits for one.
	w.ice = 1.0
	await frames(3)
	var s := world.terrain.water_surface_at(Terrain.CREEK_X)
	player.global_position = Vector2(Terrain.CREEK_X, s - 60.0)
	player.velocity = Vector2.ZERO
	await frames(40)
	check(absf(player.global_position.y - s) < 6.0 and player.wade_depth == 0.0, "standing on the ice, not wading (%.0f vs %.0f)" % [player.global_position.y, s])
	var creek: Creek = get_tree().get_first_node_in_group("creek")
	check(creek.interact_label(player) == "Chop a hole in the ice", "the creek offers to chop a hole")
	var pot: ItemStack = player.backpack.find(func(st): return st.def.id == "cook_pot")
	pot.water = 0.0
	player.hold(pot)
	player.use_held()
	check(pot.water > 0.0 and not pot.water_clean, "no hole yet: the pot packs with snow instead (%.2f L)" % pot.water)
	pot.water = 0.0
	creek.interact(player)
	await frames(int(Player.SWING_TIME * 60.0) + 2)
	check(creek.hole_open(), "chopped a hole")
	player.use_held()
	check(pot.water > 1.0, "filled the pot through the hole")

	# Snow in the pot melts and boils clean on the fire.
	pot.water = 0.0
	await teleport(x + 380.0)
	player.hold(pot)
	player.use_held()
	check(pot.water > 0.5 and not pot.water_clean, "packed the pot with snow")
	await teleport(x + 300.0)
	fire = find_fire() # the camp chunk unloaded while we were at the creek
	fire.tripod = true
	fire.fuel = 4.0
	fire.lit = true
	fire.interact(player)
	check(fire.pot == pot, "pot of snow on the fire")
	fire._on_tick(Campfire.BOIL_HOURS * 1.2)
	check(pot.water_clean, "snow melted and boiled clean")
	w.ice = 0.0
	w.snow_cm = 0.0
	await _builds()

	print("scenario failures: ", failures)
	get_tree().quit(failures)

func _builds() -> void:
	var x := 5200.0
	await teleport(x)
	var h := GameClock.clock.hours

	# Hide frame: a raw hide cures in about a day; two tanned hides and cord make a coat.
	var frame := world.spawn({"kind": "hide_frame", "x": x + 80.0}) as HideFrame
	player.backpack.add(ItemStack.make("deer_hide", h))
	check(frame.interact_label(player) == "Stretch the deer hide", "hide frame offers to stretch the hide")
	frame.interact(player)
	await frames(int(HideFrame.STRETCH_SECONDS * 60.0) + 10)
	check(frame.curing and player.backpack.count_of("deer_hide") == 0, "hide laced onto the frame")
	frame._on_tick(HideFrame.CURE_HOURS)
	check(frame.done() and frame.interact_label(player) == "Take the tanned hide", "cured after %d hours" % HideFrame.CURE_HOURS)
	frame.interact(player)
	check(player.backpack.count_of("hide") == 1 and not frame.curing, "took the tanned hide")
	var rotten := ItemStack.make("deer_hide", h - 60.0)
	player.backpack.add(rotten)
	frame.interact(player)
	check(not frame.curing and player.backpack.count_of("deer_hide") == 1, "a rotted hide is refused")
	player.backpack.take("deer_hide", 1)
	player.backpack.add(ItemStack.make("hide", h))
	if player.backpack.count_of("cordage") == 0:
		player.backpack.add(ItemStack.make("cordage", h))
	var r: Dictionary = Builds.RECIPES.hide_coat
	for k in r.needs:
		check(player.backpack.take(k, r.needs[k]), "have %s for the coat" % k)
	player.receive(ItemStack.make("hide_coat", h))
	check(player.backpack.count_of("hide_coat") == 1, "sewed a hide coat")
	var cold := {"air_c": -10.0}
	var bare_c := Condition.new(GameClock.tuning)
	bare_c.tick(3.0, cold)
	var coat_c := Condition.new(GameClock.tuning)
	coat_c.tick(3.0, cold.merged({"insulation_c": GameClock.tuning.hide_coat_c}))
	check(coat_c.warmth > bare_c.warmth + 10.0, "the coat keeps you warmer at -10 °C (%d vs %d)" % [coat_c.warmth, bare_c.warmth])

	# Drying rack: raw meat hangs, dries (faster by a fire), and comes down as jerky.
	var rack := world.spawn({"kind": "drying_rack", "x": x + 320.0}) as DryingRack
	await teleport(x + 320.0)
	player.hold(ItemStack.make("venison_raw", h, 4))
	check(rack.interact_label(player).begins_with("Hang venison"), "rack offers to hang the venison")
	rack.interact(player)
	check(rack.pieces.size() == 4 and player.held == null, "four strips hanging")
	rack._on_tick(DryingRack.DRY_HOURS * 0.5)
	check(rack.dried() == 0, "half a day in, still drying")
	rack._on_tick(DryingRack.DRY_HOURS)
	var jerky := player.backpack.count_of("jerky")
	check(rack.interact_label(player) == "Take jerky  (4)", "dried: jerky ready")
	rack.interact(player)
	check(player.backpack.count_of("jerky") == jerky + 4 and rack.pieces.is_empty(), "took down 4 jerky")

	# Workbench: the bow needs one; handles are repaired there; a whetstone sharpens anywhere.
	check(Builds.RECIPES.bow.get("bench", false) and not Workbench.near(player), "the bow is bench work, and there's no bench here")
	world.spawn({"kind": "workbench", "x": x + 480.0})
	await teleport(x + 480.0)
	check(Workbench.near(player), "at the workbench")
	var ui: BackpackUI = get_tree().get_first_node_in_group("backpack_ui")
	var axe: ItemStack = player.backpack.find(func(st): return st.def.has("axe"))
	axe.sharpness = 0.5
	axe.condition = 0.5
	var whets := player.backpack.count_of("whetstone")
	if whets == 0:
		player.backpack.add(ItemStack.make("whetstone", h))
	var whet: ItemStack = player.backpack.find(func(st): return st.def.has("whetstone"))
	var uses := whet.uses_left
	ui.toggle()
	ui.selected = axe
	ui._refresh()
	var labels: Array = ui._actions.get_children().filter(func(n): return n is Button).map(func(b): return b.text)
	check(labels.any(func(t): return t.begins_with("Sharpen on the whetstone")) and labels.any(func(t): return t.begins_with("Repair the handle")), "the pack offers to sharpen and repair the hatchet")
	ui._sharpen()
	await frames(int(2.5 * 60.0) + 10)
	check(axe.sharpness == 1.0 and whet.uses_left == uses - 1, "sharpened: keen edge, one use off the whetstone")
	player.backpack.add(ItemStack.make("sticks", h, 2))
	ui.toggle()
	ui.selected = axe
	ui._repair()
	await frames(int(3.0 * 60.0) + 10)
	check(axe.condition == 1.0, "new handle fitted at the bench")

	# Storage chest: items move from the pack into it, stay there through a save, and come back.
	var chest := world.spawn({"kind": "chest", "x": x + 640.0}) as StorageChest
	var jerky_n := player.backpack.count_of("jerky")
	var jerky_stack: ItemStack = player.backpack.find(func(st): return st.def.id == "jerky")
	await teleport(x + 640.0)
	chest.interact(player)
	check(ui.visible and ui.storage == chest.store, "the chest opens beside the pack")
	while jerky_stack: # every stack of it
		ui._lift(jerky_stack)
		chest.store.add(jerky_stack)
		jerky_stack = player.backpack.find(func(st): return st.def.id == "jerky")
	ui.toggle()
	check(player.backpack.count_of("jerky") == 0 and chest.store.count_of("jerky") == jerky_n and ui.storage == null, "jerky stored in the chest (%d)" % jerky_n)
	var again := world.spawn(chest.to_state()) as StorageChest
	check(again.store.count_of("jerky") == jerky_n, "and it's still there after a save round-trip")
	again.queue_free()

	# Log cabin: shelter that holds warmth; sleeping there makes it camp.
	var cx := x + 900.0
	var cabin := world.spawn({"kind": "cabin", "x": cx, "fresh": true}) as Cabin
	await teleport(cx)
	check(player.camp_x == cx, "finishing the cabin makes it camp")
	check(world.sheltered_at(cx) and world.heat_at(player.global_position + Vector2(0, -60)) >= Cabin.WARMTH, "inside is sheltered and holds warmth")
	check(world.heat_at(Vector2(cx + 600.0, player.global_position.y - 60.0)) < Cabin.WARMTH, "outside it doesn't")
	check(cabin.interact_label(player).begins_with("Sleep in the cabin"), "the cabin offers sleep")

func _wild() -> void:
	await frames(10)
	GameClock.clock.hours = 7.0 # morning: deer are up and feeding
	GameClock.force_weather(Weather.Kind.CLEAR)
	GameClock.weather.wind_dir = -1 # blowing toward us from the deer (east of us): hunt into the wind

	# Running at a deer spooks it; it bolts away, then calms once far enough off.
	await teleport(9000.0)
	var deer: Animal = await _deer(9900.0, 11)
	player.auto_dir = 1.0
	player.auto_run = true
	var guard := 0
	while deer.state != Animal.State.FLEE and guard < 600:
		await frames(1)
		guard += 1
	player.auto_dir = 0.0
	player.auto_run = false
	var gap := deer.position.x - player.global_position.x
	check(deer.state == Animal.State.FLEE and gap > 600.0, "running toward a deer spooks it from far off (bolted at %.0f px)" % gap)
	check(deer.facing == 1, "it flees away from you")
	guard = 0
	while deer.state == Animal.State.FLEE and guard < 900:
		await frames(1)
		guard += 1
	var far := deer.position.x - player.global_position.x
	check(deer.state != Animal.State.FLEE and far > deer.def.flee_distance * 0.8, "it calms down once well away (%.0f px), no map-wide chase" % far)

	# A slow crouched approach gets much closer than running did.
	await teleport(9000.0)
	player.cond.stamina = 100.0
	deer = await _deer(9700.0, 12)
	player.auto_dir = 1.0
	player.auto_crouch = true
	guard = 0
	while deer.state != Animal.State.FLEE and deer.position.x - player.global_position.x > 330.0 and guard < 900:
		await frames(1)
		guard += 1
	var closest := deer.position.x - player.global_position.x
	player.auto_dir = 0.0
	player.auto_crouch = false
	check(deer.state != Animal.State.FLEE and closest < 400.0, "stalking crouched gets within %.0f px unnoticed (running spooked it at %.0f)" % [closest, gap])

	# Tracks: boots print in mud, age through stages, and fade away.
	var tr := world.tracks
	tr.prints.clear()
	await teleport(Terrain.CREEK_X - Terrain.CREEK_HALF - 600.0)
	player.auto_dir = 1.0
	await frames(90)
	player.auto_dir = 0.0
	var boots := tr.prints.filter(func(p): return p.s == "boot").size()
	check(boots >= 2, "boot prints left in the bank mud (%d)" % boots)
	check(tr.interact_label(player) == "", "your own prints don't nag for attention")
	tr.add(player.global_position.x + 30.0, "deer", 1)
	check(tr.interact_label(player) == "Examine tracks", "deer tracks can be examined")
	tr.interact(player)
	var stages := []
	for h in [1.0, 5.0, 20.0]: # age only the tracks, not the whole world
		tr._on_tick(h)
		stages.append(Tracks.stage(tr.prints[0].age) if tr.prints else -1)
	tr._on_tick(30.0)
	check(stages == [0, 1, 2] and tr.prints.is_empty(), "prints read fresh → hours old → old, then fade away %s" % str(stages))

	# Fishing: craft a pole, cast, hook, reel, cook.
	player.backpack.add(ItemStack.make("sticks", GameClock.clock.hours, 2))
	var r: Dictionary = Builds.RECIPES.fishing_pole
	for k in r.needs:
		player.backpack.take(k, r.needs[k])
	player.receive(ItemStack.make("fishing_pole", GameClock.clock.hours))
	player.hold(player.backpack.find(func(s): return s.def.has("rod")))
	check(player.held and player.held.def.has("rod"), "crafted and holding a fishing pole")
	player.facing = 1
	await teleport(Terrain.CREEK_X - Terrain.CREEK_HALF - 30.0)
	player.aim_override = Vector2(Terrain.CREEK_X, 0)
	var fishing := player.fishing
	player.use_held()
	check(fishing.state == Fishing.State.CAST, "cast toward the creek")
	await frames(int(Fishing.CAST_TIME * 60.0) + 5)
	check(fishing.state == Fishing.State.WAIT, "bobber on the water, waiting")
	fishing.force_bite("trout")
	await frames(2)
	check(fishing.state == Fishing.State.BITE, "bite!")
	player.use_held()
	check(fishing.state == Fishing.State.REEL, "hooked")
	guard = 0
	while fishing.state == Fishing.State.REEL and guard < 3000:
		await frames(1)
		guard += 1
		if fishing.fight and fishing.fight.in_zone() and absf(fishing.fight.needle - fishing.fight.zone) < fishing.fight.zone_half() * 0.5:
			player.use_held()
	check(player.backpack.count_of("trout_raw") == 1, "landed a trout")
	player.aim_override = Vector2.INF
	world.spawn({"kind": "campfire", "x": player.global_position.x - 150.0, "fuel": 4.0, "lit": true})
	await teleport(player.global_position.x - 150.0)
	player.hold(player.backpack.find(func(s): return s.def.id == "trout_raw"))
	find_fire().interact(player)
	await frames(60 * 4)
	check(player.backpack.count_of("trout_cooked") == 1 or (player.held and player.held.def.id == "trout_cooked"), "cooked the trout over the fire")

	# Hunting: the knife takes only an unaware deer; the bow works from range.
	await _hunt()

	# Birds burst up when you come close.
	var flock := BirdFlock.new()
	flock.world = world
	flock.player = player
	flock.position = Vector2(player.global_position.x + 600.0, world.terrain.height_at(player.global_position.x + 600.0))
	world.get_parent().add_child(flock)
	player.auto_dir = 1.0
	await frames(120)
	player.auto_dir = 0.0
	check(flock.flushed, "birds flush as you approach")

	print("scenario failures: ", failures)
	get_tree().quit(failures)
