class_name Scenario extends Node
## Scripted end-to-end check of the camp loop, driven through the player's real actions:
## fell → strip → buck → haul logs → build lean-to → gather sticks → build + light fire →
## fill pot at creek → boil → pour → drink → leave and return (persistence + catch-up).
## Run: godot --headless --fixed-fps 60 -- --scenario     (exit code = failed checks)

var player: Player
var world: World
var shot := ""
var failures := 0

func _ready() -> void:
	player.message.connect(func(t): print("  msg: ", t))
	_run.call_deferred()

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
		var guard := 0
		while not tree.felled and guard < 60:
			await swing()
			guard += 1
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
	var fbp := world.spawn({"kind": "blueprint", "build": "campfire", "x": fire_x}) as Blueprint
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

	# --- Water: creek → pot → boil → bottle → drink -----------------------------
	var pot: ItemStack = player.backpack.find(func(s): return s.def.id == "cook_pot")
	player.hold(pot)
	await teleport(Terrain.CREEK_X)
	var creek := get_tree().get_nodes_in_group("interactable").filter(func(n): return n is Creek)[0] as Creek
	creek.interact(player)
	check(pot.water > 1.0 and not pot.water_clean, "pot filled with dirty creek water (%.2f L)" % pot.water)
	await teleport(fire_x)
	fire = find_fire() # the camp chunk unloaded while we were at the creek; this is its respawned fire
	check(fire != null and fire.lit, "fire still burning after the camp chunk reloaded")
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
