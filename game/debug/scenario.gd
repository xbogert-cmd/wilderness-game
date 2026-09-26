class_name Scenario extends Node
## Scripted end-to-end check of the camp loop, driven through the player's real actions:
## fell → strip → buck → haul logs → build lean-to → gather sticks → build + light fire →
## fill pot at creek → boil → pour → drink → leave and return (persistence + catch-up).
## Run: godot --headless --fixed-fps 60 -- --scenario     (exit code = failed checks)
## Mode "life": sleep, autosave, save to slot 3, die, respawn, recover the pack.
## Mode "verify": run with --load=3 after "life"; checks the save came back exactly.
## Mode "winter": woodpile, seasons, snow, tracks in snow, frozen creek, snow in the pot,
## then the camp builds: hide frame and coat, drying rack, log cabin.
## Mode "world": the foothills, the rock shelter, the fire lookout, the map, and the herd.
## Mode "predators": choice menus, torch, wolves and the bear around food and camps, the spear,
## butchering and dragging, snares and rabbits, pelts and clothing.
## Mode "frontier": the wider world: new waters and biomes, the homestead, the trapper's camp,
## the plane wreck, the log bridge, flares, the far lights, and old saves' maps.
## Mode "health": sickness, infection and fever, frostbite, wild plants and learning them,
## pot cooking (stews, teas), crafting from nearby chests, winter travel.
## Mode "under": the root cellar, the cave and the mine (drop-through hatches, ladders, ropes,
## the dark, flint and coal), the newest country, finds, springs, the falls, and regrowth.

var player: Player
var world: World
var shot := ""
var mode := "camp"
var EXPECT := SaveGame.DIR + "/scenario_expect.json"
var failures := 0

func _ready() -> void:
	player.message.connect(func(t): print("  msg: ", t))
	var wl: Wildlife = get_parent().find_children("*", "Wildlife", false, false)[0]
	wl.auto_spawn = false # the checks place their own deer
	match mode:
		"world": _world_tour.call_deferred()
		"life": _life.call_deferred()
		"verify": _verify.call_deferred()
		"wild": _wild.call_deferred()
		"winter": _winter.call_deferred()
		"predators": _predators.call_deferred()
		"frontier": _frontier.call_deferred()
		"health": _health.call_deferred()
		"under": _under.call_deferred()
		"icons": _icons.call_deferred()
		"sounds": _sounds.call_deferred()
		"stores": _stores.call_deferred()
		"hunts": _hunts.call_deferred()
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
	var piles := get_tree().get_nodes_in_group("interactable").filter(func(it): return it is WorldItem and it.stack.def.id == "sticks" and absf(it.global_position.x - camp_x) < 5000.0)
	for it in piles:
		if is_instance_valid(it) and not it.is_queued_for_deletion() and player.backpack.count_of("sticks") < 5:
			await teleport(it.global_position.x)
			if is_instance_valid(it):
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
	var book := (get_tree().get_first_node_in_group("build_mode") as BuildMode).book
	check(book.visible and get_tree().paused, "B opens the build book (paused)")
	await frames(2)
	await click(book.entry_button("lean_to").get_global_rect().get_center())
	check(book.chosen == "lean_to", "clicking Lean-to turns to its page")
	var rows := book.page().find_children("*", "Label", true, false).map(func(l): return l.text)
	check(rows.any(func(t): return t.begins_with("Long Logs") and "short" in t) and rows.any(func(t): return t.begins_with("Fell a tree")), "it shows what you're short of and where to get it")
	await click(book.entry_button("campfire").get_global_rect().get_center())
	await frames(2)
	await click(book.action.get_global_rect().get_center())
	check(not book.visible and player.placing, "Place the blueprint: the book closes and placement starts")
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
	Player.choices_of(fire, player).filter(func(o): return o[0] == "Take pot")[0][1].call()
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
	check(get_tree().get_nodes_in_group("shelter").filter(func(n): return not n is Underground).is_empty(), "camp unloaded when far away")
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
	var bag := player.backpack.find(func(st): return st.def.id == "sleeping_bag")
	player.backpack.remove(bag)
	player.sleep()
	check(not player.sleeping, "can't sleep without shelter or a sleeping bag")
	player.backpack.add(bag)
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
		"berries_made": player.backpack.find(func(s): return s.def.id == "berries").made_hour,
		"journal": Journal.current.entries.size(), "explored": Array(world.explored).count(1)}
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
	check(Journal.current.entries.size() == int(e.journal) and Array(world.explored).count(1) >= int(e.explored), "journal (%d entries) and explored map restored" % Journal.current.entries.size())
	print("scenario failures: ", failures)
	get_tree().quit(failures)

# --- Mode "world": foothills, rock shelter, lookout, map, herd ------------------------

func _world_tour() -> void:
	await frames(10)
	GameClock.clock.hours = 10.0
	GameClock.force_weather(Weather.Kind.CLEAR)
	var t := world.terrain
	check(t.height_at(40000.0) < t.height_at(20000.0) - 800.0 and t.summit_y < t.height_at(40000.0) - 500.0, "the land climbs east through the foothills to the summit")

	# The rock shelter: shelter, a little warmth when it's cold, and an old cache.
	await teleport(Terrain.CAVE_X)
	var cave: Cave = get_tree().get_first_node_in_group("landmark") if get_tree().get_first_node_in_group("landmark") is Cave else null
	for n in get_tree().get_nodes_in_group("landmark"):
		if n is Cave:
			cave = n
	check(cave != null and world.sheltered_at(player.global_position.x), "the rock shelter keeps the weather off")
	check(Journal.has("cave"), "finding it goes in the journal")
	await teleport(cave.interact_pos().x)
	check(cave.interact_label(player) == "Search the old camp", "there's an old camp to search at the back")
	var kits := player.backpack.count_of("fishing_kit")
	cave.interact(player)
	check(player.backpack.count_of("fishing_kit") == kits + 1 and Journal.has("cave_page") and cave.interact_label(player) == "", "cache found once: line & hooks, and a torn page")

	# The fire lookout: climb, take in the view (the whole map fills in), search, sleep, climb down.
	await teleport(Terrain.LOOKOUT_X + Lookout.LADDER_X)
	var lk: Lookout = null
	for n in get_tree().get_nodes_in_group("landmark"):
		if n is Lookout:
			lk = n
	check(lk != null and lk.interact_label(player) == "Climb the lookout tower", "the ladder at the foot of the tower")
	lk.interact(player)
	await frames(30)
	var mid := lk.global_position.y - player.global_position.y
	check(player.climbing and player.on_ladder() and mid > 20.0 and mid < -Lookout.FLOOR, "climbing the ladder hand over hand (%.0f px up)" % mid)
	await _wait_until(func(): return not player.climbing, 60 * 10)
	await frames(10)
	check(lk.on_top(player), "up on the catwalk (%.0f px up)" % (lk.global_position.y - player.global_position.y))
	await frames(30)
	check(world.seen(0.0) and world.seen(Terrain.CREEK_X) and world.seen(Terrain.CRASH_X) and world.seen(73500.0) and not world.seen(Terrain.WORLD_MAX - 300.0) and not world.seen(Terrain.HOMESTEAD_X) and Journal.has("lookout"),
		"the valley and the country east to the basin rim fill in from up here (the far west, and past the falls, are too far)")
	var cam := get_viewport().get_camera_2d() as FollowCamera
	check(cam.view_zoom == Lookout.VIEW_ZOOM, "the view pulls back over the valley")
	var cupboard: Node2D = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.get_script() and n.get("lookout") == lk:
			cupboard = n
	player.global_position.x = cupboard.global_position.x
	await frames(5)
	check(player.focus == cupboard, "the keeper's cupboard is in reach")
	cupboard.interact(player)
	check(Journal.has("log_3") and player.backpack.count_of("lighter") >= 2, "supplies and the keeper's logbook (3 pages)")
	check(world.sheltered_at(player.global_position.x), "the cab is shelter: you can sleep up here")
	player.global_position.x = lk.global_position.x + Lookout.LADDER_X
	await frames(5)
	check(lk.interact_label(player) == "Climb down", "the ladder back down")
	lk.interact(player)
	await _wait_until(func(): return not player.climbing, 60 * 10)
	await frames(20)
	check(not lk.on_top(player) and player.is_on_floor(), "back on the ground")
	await frames(60)
	check(cam.view_zoom == 0.0, "and the view comes back in")

	# The map: opens paused, lists what you've built.
	var map: MapUI = get_tree().get_root().find_children("*", "MapUI", true, false)[0]
	map.toggle()
	check(map.visible and get_tree().paused, "M opens the map and pauses")
	check(map._list.get_child_count() >= 4 or Journal.current.entries.size() >= 4, "the journal is filling up (%d entries)" % Journal.current.entries.size())
	map.toggle()
	check(not get_tree().paused, "and closes")

	# The herd: deer appear out of sight on either side and far ones leave.
	var wl: Wildlife = get_parent().find_children("*", "Wildlife", false, false)[0]
	await teleport(18000.0)
	var sides := {}
	for k in 12:
		for a in get_tree().get_nodes_in_group("animals"):
			a.free()
		wl._manage_herd()
		for a in get_tree().get_nodes_in_group("animals"):
			sides[signf(a.position.x - player.global_position.x)] = true
			check(absf(a.position.x - player.global_position.x) >= Wildlife.SPAWN_CLEARANCE, "spawned out of sight (%.0f px)" % absf(a.position.x - player.global_position.x)) if k == 0 else null
	check(sides.has(-1.0) and sides.has(1.0), "deer turn up on both sides of you")
	await teleport(21000.0) # both test deer within loaded ground
	for a in get_tree().get_nodes_in_group("animals"):
		a.free()
	var far := wl.spawn(Wildlife.SPECIES[0], player.global_position.x + 7000.0, 1)
	var hurt := wl.spawn(Wildlife.SPECIES[0], player.global_position.x - 7000.0, 2)
	hurt.wound = 30.0
	wl._manage_herd()
	await frames(2)
	check(not is_instance_valid(far) and is_instance_valid(hurt), "a far-off deer leaves; a wounded one stays to be tracked")

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
func _lead(target: Vector2, speed := Player.ARROW_SPEED.y) -> Vector2:
	var t := (target - player.arrow_origin()).length() / speed
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
	deer.facing = -1 # looking straight at you
	player.use_held()
	await frames(3)
	check(deer.state == Animal.State.FLEE and deer.wound >= 0.0 and _carcasses().size() == 1, "an alert deer bolts, but the knife cuts it: it bleeds")
	deer.queue_free()
	await frames(int(Player.SWING_TIME * 60.0) + 2)

	var carcass: Carcass = _carcasses()[0]
	await teleport(carcass.global_position.x)
	check(carcass.interact_label(player) == "Butcher it here", "carcass offers butchering")
	check(Player.choices_of(carcass, player).size() == 2, "two choices: butcher it here, or drag it home")
	carcass.interact(player)
	await frames(int(Carcass.DRESS_SECONDS * 60.0) + 10)
	check(player.backpack.count_of("venison_raw") == int(Carcass.MEAT) and _carcasses().is_empty(), "butchered: %d venison straight into the pack" % player.backpack.count_of("venison_raw"))
	check(get_tree().get_nodes_in_group("food_scent").any(func(n): return n is GutPile), "butchering in the field leaves a gut pile")
	check(player.backpack.count_of("deer_hide") == 1 or (player.held and player.held.def.id == "deer_hide"), "and a raw deer hide")
	player.backpack.take("venison_raw", player.backpack.count_of("venison_raw")) # make room for what follows
	player.backpack.take("deer_hide", player.backpack.count_of("deer_hide"))

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
	deer.facing = -1 # grazing toward you: the arrow meets its chest first (from behind it'd hit the haunch)
	await frames(2) # let it settle onto the ground before aiming
	player.aim_override = _lead(deer.position + Vector2(-30.0, -92.0))
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
	var sewn := player.backpack.find(func(st): return st.def.id == "hide_coat")
	check(player.backpack.insulation() == 0.0, "a coat in the pack doesn't warm you")
	check(player.backpack.wear(sewn) and player.backpack.worn.body == sewn and player.backpack.count_of("hide_coat") == 0, "wearing it moves it out of the pack into the coat slot")
	var cold := {"air_c": -10.0}
	var bare_c := Condition.new(GameClock.tuning)
	bare_c.tick(3.0, cold)
	var coat_c := Condition.new(GameClock.tuning)
	coat_c.tick(3.0, cold.merged({"insulation_c": player.backpack.insulation()}))
	check(coat_c.warmth > bare_c.warmth + 8.0, "the coat keeps you warmer at -10 °C (%d vs %d)" % [coat_c.warmth, bare_c.warmth])

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


# --- Mode "predators" ------------------------------------------------------------------

func _wl() -> Wildlife:
	return get_parent().find_children("*", "Wildlife", false, false)[0]

func _clear_wild() -> void:
	for g in ["animals", "predators", "small_game"]:
		for a in get_tree().get_nodes_in_group(g):
			a.queue_free()
	await frames(2)

func _wait_until(cond: Callable, max_frames: int) -> int:
	var n := 0
	while not cond.call() and n < max_frames:
		await frames(1)
		n += 1
	return n

func _den_and_winter_wolves() -> void:
	var saved := GameClock.clock.hours
	var year := GameClock.clock.season_hours() * 4.0
	GameClock.clock.hours = ceilf(saved / year) * year + GameClock.clock.season_hours() * 1.4 + 12.0
	check(GameClock.clock.season() == 3, "it's winter (%s)" % GameClock.clock.season_name())
	var cave := _under_place("cave")
	await teleport(Terrain.ECHO_CAVE_X - 600.0)
	await frames(10)
	cave = _under_place("cave")
	_wl()._manage_predators()
	var bears := get_tree().get_nodes_in_group("predators").filter(func(b): return not b.is_wolf())
	check(bears.size() == 1 and bears[0].den == cave and bears[0].state == Predator.State.SLEEP, "winter: the bear is asleep in the cave den, not out on the surface")
	if bears.is_empty():
		GameClock.clock.hours = saved
		return
	var bear: Predator = bears[0]
	check(absf(bear.position.y - (cave.global_position.y + Predator.DEN.y)) < 30.0, "lying in the upper gallery")
	await teleport(bear.position.x)
	player.auto_run = true
	player.auto_dir = 1.0
	await frames(60 * 2)
	player.auto_dir = 0.0
	player.auto_run = false
	check(bear.rouse == 0.0, "running about on the ground overhead doesn't wake it")
	await teleport_under(cave.global_position.x + 1250.0, cave.global_position.y + 400.0)
	check(player.underground == cave, "down in the gallery")
	await frames(60 * 4)
	check(bear.state == Predator.State.SLEEP and bear.rouse < 0.1, "keeping still in the dark, 400 px off: it sleeps on (rouse %.2f)" % bear.rouse)
	player.held = ItemStack.make("torch", GameClock.clock.hours)
	player.cond.health = 100.0
	var woke := await _walk(-1.0, func(): return bear.state != Predator.State.SLEEP or player.global_position.x < bear.position.x + 140.0, 60 * 8)
	if bear.state == Predator.State.SLEEP:
		await _wait_until(func(): return bear.state != Predator.State.SLEEP, 60 * 10)
	check(bear.state != Predator.State.SLEEP, "walking up with a torch rouses it (%s)" % woke)
	await _wait_until(func(): return bear.state == Predator.State.BLUFF, 60 * 4)
	check(bear.state == Predator.State.BLUFF and player.cond.health == 100.0, "woken: a warning charge first")
	var lo := cave.global_position.x + Predator.DEN_SPAN.x
	await _walk(-1.0, func(): return player.global_position.x < lo - 300.0, 60 * 10)
	await frames(60 * 3)
	check(bear.position.x >= lo - 1.0, "it won't follow you up out of the gallery (%.0f)" % (bear.position.x - cave.global_position.x))
	player.held = null
	await teleport(Terrain.ECHO_CAVE_X - 900.0)
	var n := await _wait_until(func(): return bear.state == Predator.State.SLEEP, 60 * 40)
	check(bear.state == Predator.State.SLEEP, "once you're gone it settles back to sleep (%d s)" % (n / 60))
	await teleport_under(bear.position.x - 150.0, bear.position.y)
	bear.hurt(99.0, player.global_position.x)
	await frames(3)
	var dead := _carcasses().filter(func(c): return c.species == "black_bear")
	check(dead.size() == 1 and dead[0].global_position.y > cave.global_position.y + 300.0, "killed in the den, it lies in the den")
	if dead:
		check(not dead[0]._ravens.active and dead[0].to_state().has("y"), "no ravens down here; it stays underground when saved")
		dead[0].queue_free()
	await teleport(Terrain.ECHO_CAVE_X - 900.0)
	_wl()._manage_predators()
	check(get_tree().get_nodes_in_group("predators").filter(func(b): return not b.is_wolf()).is_empty(), "the den stays empty the rest of the winter")
	await _clear_wild()

	# Winter wolves: about all day, oftener, some packs travelling through.
	await teleport(9000.0)
	GameClock.clock.hours = floorf(GameClock.clock.hours / 24.0) * 24.0 + 12.0 # noon
	var packs := 0
	var travelling := 0
	var biggest := 0
	for k in 40:
		_wl()._manage_predators()
		var wolves := get_tree().get_nodes_in_group("predators").filter(func(w): return w.is_wolf() and not w.is_queued_for_deletion())
		if wolves:
			packs += 1
			biggest = maxi(biggest, wolves.size())
			if wolves[0].travel != 0.0:
				travelling += 1
			await _clear_wild()
	check(packs >= 3, "winter noon: wolf packs come by day (%d in 40 checks)" % packs)
	check(travelling >= 1, "some are passing through (%d of %d)" % [travelling, packs])
	await _clear_wild() # (no deer to hunt, no kill to smell: this is about travelling)
	for c in get_tree().get_nodes_in_group("food_scent"):
		c.queue_free()
	await frames(2)
	var w := _wl().spawn_predator(Wildlife.WOLF, 12000.0, 9)
	w.travel = 1.0
	await frames(60 * 10)
	check(w.position.x - 12000.0 > 900.0, "a travelling pack covers ground (%.0f px in 10 s)" % (w.position.x - 12000.0))
	check(w._range() == Wildlife.WOLF.home_range * 2.0, "wolves range twice as wide in winter")
	await _clear_wild()
	GameClock.clock.hours = ceilf(GameClock.clock.hours / year) * year + year * 0.5 + 12.0 # early spring
	var b := _wl().spawn_predator(Wildlife.BEAR, 30000.0, 10)
	check(b._hunger() > 1.0, "spring: the bear's just out of the den and hungry")
	await _clear_wild()
	GameClock.clock.hours = saved

func _predators() -> void:
	await frames(10)
	var x := 9000.0
	var h := GameClock.clock.hours
	GameClock.force_weather(Weather.Kind.CLEAR)
	GameClock.clock.hours = floorf(h / 24.0) * 24.0 + 23.0 # night
	await teleport(x)
	player.cond.health = 100.0

	# --- Choices: E on something with several things to do opens a numbered list.
	var fire := world.spawn({"kind": "campfire", "x": x + 60.0, "fuel": 4.0, "lit": true}) as Campfire
	player.backpack.add(ItemStack.make("sticks", GameClock.clock.hours, 4))
	await frames(4)
	check(player.focus == fire, "standing at the fire")
	var opts := Player.choices_of(fire, player)
	check(opts.size() >= 3, "a lit fire offers several choices (%s)" % ", ".join(opts.map(func(o): return o[0])))
	player.open_or_interact()
	check(player.menu == fire, "E opens the list of choices")
	var fuel := fire.fuel
	var torch_i := opts.map(func(o): return o[0]).find("Light a torch from the fire")
	check(torch_i >= 0, "one of them lights a torch")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_1 + torch_i
	ev.pressed = true
	player._unhandled_input(ev)
	check(player.menu == null and player.holding("torch"), "its number key lights a torch")
	check(fire.fuel == fuel, "the fire kept its fuel")
	player.open_or_interact()
	player.auto_dir = 1.0
	await frames(3)
	player.auto_dir = 0.0
	check(player.menu == null, "walking off closes the list")
	check(not player.backpack.add(ItemStack.make("torch")), "a burning torch won't go in the pack")

	# --- Camp is safe: a wolf drawn to meat right beside the fire won't come in.
	await _clear_wild()
	var meat := world.spawn({"kind": "item", "x": x + 300.0, "stack": ItemStack.make("venison_raw", GameClock.clock.hours).to_dict()})
	check(Predator.safe_at(get_tree(), meat.global_position.x), "meat by the fire is inside camp")
	player.stow()
	var wolf := _wl().spawn_predator(Wildlife.WOLF, x + 2600.0, 3)
	await frames(60 * 12)
	check(is_instance_valid(meat) and absf(wolf.position.x - fire.global_position.x) >= Predator.SAFE_R - 5.0, "the wolf never comes into camp (%.0f px from the fire)" % absf(wolf.position.x - fire.global_position.x))
	meat.queue_free()
	fire.queue_free()
	await frames(2)

	# --- Out in the open, it finds a carcass and eats; the hide is ruined.
	await _clear_wild()
	var cx := x + 400.0
	var carcass := world.spawn({"kind": "carcass", "x": cx, "facing": 1, "species": "mule_deer", "hour": GameClock.clock.hours}) as Carcass
	await teleport(x - 1500.0)
	wolf = _wl().spawn_predator(Wildlife.WOLF, cx + 2200.0, 4)
	var n := await _wait_until(func(): return wolf.state == Predator.State.FEED, 60 * 20)
	check(wolf.state == Predator.State.FEED, "a wolf smells the carcass and comes to feed (%d s)" % (n / 60))
	await frames(60 * 4)
	check(carcass.meat < Carcass.MEAT and carcass.torn, "it eats into it; the hide is torn (%.1f cuts left)" % carcass.meat)

	# --- A torch keeps it off, and waving it drives it away.
	player.hold(ItemStack.make("torch", GameClock.clock.hours))
	await teleport(cx - 300.0)
	player.facing = 1
	await frames(60)
	check(wolf.state == Predator.State.FLEE, "walking up with a torch sends it off the carcass")
	await frames(60 * 4)
	check(absf(wolf.position.x - player.global_position.x) > Predator.TORCH_R, "it keeps out of the torchlight")
	player.stow()
	check(not player.holding("torch"), "stowing a torch snuffs it")

	# --- After dark, a wolf stalks someone carrying meat; the spear drives it off.
	await _clear_wild()
	carcass.queue_free()
	for g in get_tree().get_nodes_in_group("food_scent"):
		g.queue_free()
	await frames(2)
	await teleport(x)
	player.backpack.add(ItemStack.make("venison_raw", GameClock.clock.hours, 2))
	check(player.smells_of_meat(), "raw meat in the pack: you smell of it")
	wolf = _wl().spawn_predator(Wildlife.WOLF, x + 1200.0, 5)
	var pk := [wolf]
	wolf.pack = pk
	var hp := player.cond.health
	n = await _wait_until(func(): return player.cond.health < hp, 60 * 25)
	check(player.cond.health < hp and player.cond.injuries.has("legs"), "it stalks in and bites (%d s, health %d)" % [n / 60, player.cond.health])
	player.cond.health = 100.0
	player.hold(ItemStack.make("spear", GameClock.clock.hours))
	n = await _wait_until(func(): return wolf.state == Predator.State.STALK and absf(wolf.position.x - player.global_position.x) < 400.0, 60 * 10)
	player.facing = int(signf(wolf.position.x - player.global_position.x))
	await frames(60 * 2)
	check(absf(wolf.position.x - player.global_position.x) >= Predator.BRACED_R - 20.0, "a braced spear holds it off (%.0f px)" % absf(wolf.position.x - player.global_position.x))
	await teleport(wolf.position.x - player.facing * 180.0)
	player.use_held()
	check(player.throw_draw >= 0.0 and player.thrust < 0.0, "pressing with the spear: ready to pull back and throw")
	player.release_held() # let go without pulling back: a click
	await frames(40)
	check(not is_instance_valid(wolf) or wolf.state == Predator.State.FLEE, "a click thrusts: it hurts the wolf and it runs")
	player.backpack.take("venison_raw", 2)
	player.cond.injuries.clear()

	# --- Pull back and let go: the spear flies; it takes a wolf in the chest and drops beside it.
	await _clear_wild()
	await teleport(x)
	player.cond.stamina = 100.0
	player.hold(ItemStack.make("spear", GameClock.clock.hours))
	wolf = _wl().spawn_predator(Wildlife.WOLF, x + 520.0, 11)
	wolf.set_physics_process(false)
	wolf.position.y = world.ground_y(wolf.position.x)
	wolf.facing = -1
	player.facing = 1
	player.use_held()
	player.aim_override = _lead(wolf.position + Vector2(30.0 * wolf.facing, -60.0), Player.SPEAR_SPEED.y)
	player.throw_draw = 1.0
	check(player.shot_velocity().length() > Player.SPEAR_SPEED.y * 0.9, "pulled back all the way: a hard throw")
	player.release_held()
	player.aim_override = Vector2.INF
	check(player.held == null, "the spear leaves your hands")
	await frames(60)
	var sp := get_tree().get_nodes_in_group("interactable").filter(func(it): return it is WorldItem and it.stack.def.id == "spear" and not it.is_queued_for_deletion())
	check(not is_instance_valid(wolf) and _carcasses().any(func(c): return c.species == "wolf"), "a thrown spear takes a wolf in the chest")
	check(sp.size() == 1 and absf(sp[0].global_position.x - (x + 520.0)) < 150.0, "the spear lies by it, to pick up again")
	for c in _carcasses():
		c.queue_free()
	for it in sp:
		it.queue_free()
	player.hold(ItemStack.make("spear", GameClock.clock.hours)) # a miss: thrown up high it flies long and sticks in the ground
	player.use_held()
	player.aim_override = player.arrow_origin() + Vector2(300, -300)
	player.throw_draw = 0.8
	player.release_held()
	player.aim_override = Vector2.INF
	await frames(150)
	sp = get_tree().get_nodes_in_group("interactable").filter(func(it): return it is WorldItem and it.stack.def.id == "spear" and not it.is_queued_for_deletion())
	check(sp.size() == 1 and sp[0].global_position.x - x > 900.0, "thrown high and long, it lands far off (%.0f px)" % (sp[0].global_position.x - x if sp else 0.0))
	for it in sp:
		it.queue_free()

	# --- An arrow to the chest kills a wolf; skin it for a pelt.
	await _clear_wild()
	await teleport(x)
	wolf = _wl().spawn_predator(Wildlife.WOLF, x + 700.0, 6)
	wolf.set_physics_process(false)
	wolf.position.y = world.ground_y(wolf.position.x)
	wolf.facing = -1
	player.receive(ItemStack.make("arrows", GameClock.clock.hours, 3))
	player.hold(ItemStack.make("bow", GameClock.clock.hours))
	var chest := wolf.position + Vector2(30.0 * wolf.facing, -60.0)
	check(wolf.zone_at(chest) == 2, "the chest is the vitals")
	player.facing = 1
	player.aim_override = _lead(chest)
	player.bow_draw = 1.0
	player.loose()
	await frames(60)
	player.aim_override = Vector2.INF
	var dead := _carcasses().filter(func(c): return c.species == "wolf")
	check(dead.size() == 1, "an arrow in the chest kills it")
	if dead:
		await teleport(dead[0].global_position.x)
		check(dead[0].interact_label(player) == "Skin the wolf", "a dead wolf can be skinned")
		dead[0].interact(player)
		await frames(int(4.0 * 60.0))
		check(player.backpack.count_of("wolf_pelt") == 1, "a raw wolf pelt")

	# --- The bear: a bluff first; press it and the charge is real.
	await _clear_wild()
	GameClock.clock.hours = floorf(GameClock.clock.hours / 24.0) * 24.0 + 24.0 + 12.0 # next day, noon
	var bx := 30000.0
	await teleport(bx)
	var bear := _wl().spawn_predator(Wildlife.BEAR, bx + 900.0, 7)
	player.cond.health = 100.0
	player.auto_dir = 1.0
	n = await _wait_until(func(): return bear.state == Predator.State.BLUFF, 60 * 15)
	player.auto_dir = 0.0
	check(bear.state == Predator.State.BLUFF, "walking up on the bear: it bluff-charges")
	await _wait_until(func(): return bear.state != Predator.State.BLUFF, 60 * 6)
	check(player.cond.health == 100.0, "the bluff stops short: no harm done")
	player.auto_dir = 1.0 # keep coming
	n = await _wait_until(func(): return player.cond.health < 100.0, 60 * 20)
	player.auto_dir = 0.0
	check(player.cond.health < 80.0, "pushing it: the next charge is real (health %d)" % player.cond.health)
	await _clear_wild()
	player.cond.health = 100.0
	player.cond.injuries.clear()

	# --- The seasons: the bear dens up in winter, wolves range wide.
	await _den_and_winter_wolves()

	# --- Butchering: what fits goes into the pack, the rest waits; or drag it home.
	await teleport(x)
	var deer := world.spawn({"kind": "carcass", "x": x + 80.0, "facing": 1, "species": "mule_deer", "hour": GameClock.clock.hours}) as Carcass
	await frames(2)
	var filler := []
	while player.backpack.add(ItemStack.make("snare")):
		pass
	for k in 3: # free just enough for the hide and two cuts
		var sn := player.backpack.find(func(st): return st.def.id == "snare")
		player.backpack.remove(sn)
	var snares := player.backpack.count_of("snare")
	player.stow()
	deer.interact(player)
	await frames(int(Carcass.DRESS_SECONDS * 60.0) + 10)
	var packed := player.backpack.count_of("venison_raw")
	check(is_instance_valid(deer) and packed >= 1 and deer.meat >= 1.0, "a full pack: %d cuts packed, %d left on the carcass" % [packed, floori(deer.meat) if is_instance_valid(deer) else 0])
	player.backpack.take("snare", snares)
	if is_instance_valid(deer):
		check(Player.first_label(deer.interact_options(player)).begins_with("Take the rest of the meat"), "come back for the rest")
		deer.interact(player)
		check(not is_instance_valid(deer) or deer.is_queued_for_deletion(), "took the rest; nothing left")
	player.backpack.take("venison_raw", player.backpack.count_of("venison_raw"))
	player.backpack.take("deer_hide", 1)
	var whole := world.spawn({"kind": "carcass", "x": x + 80.0, "facing": 1, "species": "mule_deer", "hour": GameClock.clock.hours}) as Carcass
	await frames(2)
	player.start_haul(whole)
	var start := player.global_position.x
	player.auto_dir = 1.0
	await frames(60 * 2)
	player.auto_dir = 0.0
	var went := player.global_position.x - start
	check(player.hauling == whole and went > 50.0 and went < Player.WALK * 2.0 * 0.6, "dragging a whole deer: slow going (%.0f px in 2 s)" % went)
	check(absf(whole.global_position.x - (player.global_position.x - Carcass.DRAG_OFFSET)) < 5.0, "it follows behind you")
	check(player.unsafe_reason() != "", "no saving mid-drag")
	player.drop_haul()
	check(whole.hauler == null, "let go")

	# --- Left out overnight, away from camp: scavenged by morning.
	var left := whole.to_state()
	whole.queue_free()
	await frames(1)
	var back := world.spawn(left, 12.0) as Carcass
	await frames(3)
	check(back.meat < Carcass.MEAT - 2.0 and back.torn, "left out 12 hours: scavenged (%.1f cuts left)" % back.meat)
	back.queue_free()

	# --- Snares and rabbits.
	var snare := world.spawn({"kind": "snare", "x": x + 200.0}) as Snare
	snare.caught = true
	await teleport(x + 200.0)
	check(Player.choices_of(snare, player).size() == 2, "a caught snare: take the rabbit, or pick up the snare")
	snare.interact(player)
	check(player.backpack.count_of("rabbit_raw") == 1 and not snare.caught, "a rabbit from the snare")
	snare.caught = true
	await teleport(x + 4000.0)
	snare._advance(200.0)
	check(not snare.caught and snare.sprung, "a rabbit left hanging out in the open gets taken")
	await teleport(x)
	var rabbit := Rabbit.new()
	rabbit.world = world
	rabbit.player = player
	rabbit.position = Vector2(x + 500.0, world.ground_y(x + 500.0))
	_wl().add_child(rabbit)
	rabbit.set_physics_process(false)
	player.hold(ItemStack.make("bow", GameClock.clock.hours))
	player.facing = 1
	player.aim_override = _lead(rabbit.position + Vector2(0, -14))
	player.bow_draw = 1.0
	player.loose()
	await frames(50)
	player.aim_override = Vector2.INF
	check(not is_instance_valid(rabbit), "an arrow takes a rabbit")

	# --- Pelts on the frame, fur clothing at the bench, and changing clothes.
	var frame := world.spawn({"kind": "hide_frame", "x": x + 100.0}) as HideFrame
	world.spawn({"kind": "workbench", "x": x - 100.0})
	player.stow()
	await frames(2)
	player.backpack.add(ItemStack.make("deer_hide", GameClock.clock.hours))
	if player.backpack.count_of("wolf_pelt") == 0:
		player.backpack.add(ItemStack.make("wolf_pelt", GameClock.clock.hours))
	check(Player.choices_of(frame, player).size() == 2, "the frame offers both the deer hide and the wolf pelt")
	Player.choices_of(frame, player).filter(func(o): return o[0] == "Stretch the wolf pelt")[0][1].call()
	await frames(int(HideFrame.STRETCH_SECONDS * 60.0) + 10)
	frame._on_tick(HideFrame.KINDS.wolf_pelt[1])
	frame.interact(player)
	check(player.backpack.count_of("wolf_fur") == 1, "cured wolf fur off the frame")
	player.backpack.take("deer_hide", 1)
	var bu := player.backpack.find(func(st): return st.def.id == "wolf_fur")
	check(bu != null, "fur in the pack")
	var ui: BackpackUI = get_tree().get_first_node_in_group("backpack_ui")
	var bench: Workbench = get_tree().get_nodes_in_group("workbench")[0]
	await teleport(bench.global_position.x)
	check(player.focus == bench and bench.interact_label(player) == "Open the recipe book", "at the workbench: E opens the recipe book (focus %s, bench at %+.0f)" % [player.focus, bench.global_position.x - player.global_position.x])
	bench.interact(player)
	var rb: RecipeBook = get_tree().get_first_node_in_group("recipe_book")
	check(rb.visible and get_tree().paused, "the recipe book is open (paused)")
	rb.choose("bear_coat")
	var said := rb.page().find_children("*", "Label", true, false).map(func(l): return l.text)
	check(rb.action.disabled and said.any(func(t): return t.begins_with("Bring down the bear")), "the bear coat: short of bear fur, and it says where to get it")
	rb.choose("wolf_hat")
	check(not rb.action.disabled, "the wolf fur hat: everything's here")
	rb.action.pressed.emit()
	check(not rb.visible and not get_tree().paused, "Make it: the book closes and the work starts")
	await frames(int(Builds.RECIPES.wolf_hat.seconds * 60.0) + 10)
	var hat := player.backpack.find(func(st): return st.def.id == "wolf_hat")
	check(hat != null, "made a wolf fur hat at the bench")
	var buck := ItemStack.make("hide_coat", GameClock.clock.hours)
	player.backpack.add(buck)
	player.backpack.wear(buck)
	player.backpack.wear(hat)
	var deer_c := player.backpack.insulation()
	var bearc := ItemStack.make("bear_coat", GameClock.clock.hours)
	player.backpack.add(bearc)
	check(player.backpack.wear(bearc) and player.backpack.worn.body == bearc and player.backpack.count_of("hide_coat") == 1, "putting on the bear coat puts the buckskin back in the pack")
	check(player.backpack.insulation() > deer_c + 4.0, "fur is much warmer than buckskin (+%d vs +%d °C)" % [player.backpack.insulation(), deer_c])

	# --- Playtest fixes ---------------------------------------------------------------
	player.stow()
	GameClock.clock.hours = floorf(GameClock.clock.hours / 24.0) * 24.0 + 24.0 + 10.0 # a fresh morning
	await teleport(x)
	await _clear_wild()
	# The hanging pot and the bottle in the pack: pour in, fill back up.
	var pf := world.spawn({"kind": "campfire", "x": x + 40.0, "fuel": 6.0, "lit": true, "tripod": true,
		"pot": ItemStack.make("cook_pot", GameClock.clock.hours).to_dict()}) as Campfire
	var bottle := player.backpack.find(func(st): return st.def.id == "water_bottle")
	bottle.water = 0.0
	bottle.add_water(0.8, false)
	await frames(3)
	var labels := Player.options_of(pf, player).map(func(o): return o[0])
	check("Pour the water bottle into the pot" in labels, "bottle in the pack: pour it into the hanging pot (%s)" % ", ".join(labels))
	Player.choices_of(pf, player).filter(func(o): return o[0] == "Pour the water bottle into the pot")[0][1].call()
	check(pf.pot.water > 0.7 and not pf.pot.water_clean and bottle.water < 0.01, "poured in: %.2f L of creek water in the pot" % pf.pot.water)
	pf._on_tick(Campfire.BOIL_HOURS + 0.05)
	labels = Player.options_of(pf, player).map(func(o): return o[0])
	check("Fill the water bottle from the pot" in labels, "boiled: fill the bottle back up from the pot")
	Player.choices_of(pf, player).filter(func(o): return o[0] == "Fill the water bottle from the pot")[0][1].call()
	check(bottle.water > 0.7 and bottle.water_clean, "the bottle is full of clean water")
	pf.queue_free()
	await frames(2)

	# The knife always strikes: an alert deer facing you is cut and bleeds.
	player.draw_slot(1)
	var dd: Animal = await _deer(x + 120.0, 31)
	dd.state = Animal.State.ALERT
	dd.awareness = dd.def.alert_at
	dd.facing = -1
	player.facing = 1
	player.use_held()
	await frames(3)
	check(player.swing >= 0.0 and dd.wound >= 0.0, "the knife strikes an alert deer: it's cut and bleeding")
	dd.queue_free()
	await frames(int(Player.SWING_TIME * 60.0) + 2)
	player.use_held()
	check(player.swing >= 0.0, "a stab even with nothing in reach")
	await frames(int(Player.SWING_TIME * 60.0) + 2)
	player.stow()

	# Spooked deer leave for good, and no new ones turn up straight away.
	var wl := _wl()
	dd = await _deer(x + 700.0, 32)
	dd.bolt()
	await _wait_until(func(): return dd.state != Animal.State.FLEE, 60 * 20)
	await frames(60 * 6)
	var gone := dd.position.x - player.global_position.x
	check(dd.leaving and gone > 2500.0, "a spooked deer keeps going, away from you (%.0f px off)" % gone)
	wl.auto_spawn = true
	wl._manage_herd()
	await frames(2)
	check(not is_instance_valid(dd) or dd.is_queued_for_deletion(), "and once out of sight it has left")
	check(get_tree().get_nodes_in_group("animals").filter(func(a): return not a.is_queued_for_deletion()).is_empty(), "no new deer right after a scare")
	wl.auto_spawn = false
	wl._quiet_until = -INF
	# Deer keep clear of camp.
	var cf := world.spawn({"kind": "campfire", "x": x + 1500.0}) as Campfire
	dd = await _deer(x + 2600.0, 33)
	dd.home_x = x + 200.0
	dd.bed_x = x
	dd.feed_x = x
	dd.state = Animal.State.WALK
	dd.facing = -1
	await frames(60 * 12)
	check(absf(dd.position.x - cf.global_position.x) >= Animal.CAMP_BERTH - 10.0, "a deer walking toward camp turns away (%.0f px from the fire)" % absf(dd.position.x - cf.global_position.x))
	dd.queue_free()
	cf.queue_free()

	# The breeze turns with the day: up the valley by day, down it at night.
	var w := GameClock.weather
	var saved_front := w.front
	w.front = 1
	var c := Clock.new()
	c.hours = 12.0
	w._daytime = -1
	w.step(0.0, c)
	var day_dir := w.wind_dir
	c.hours = 22.0
	w.step(0.0, c)
	check(day_dir == 1 and w.wind_dir == -1, "the breeze blows up-valley by day and down at night")
	w.front = saved_front

	# The sleeping bag: sleep out in the open (it isn't camp).
	var camp_before := player.camp_x
	player.sleep()
	check(player.sleeping and player.camp_x == camp_before, "rolled out the sleeping bag in the open")
	player.wake()
	await frames(2)

	# A storage chest through the real build menu: choose it, place it, bring the makings, build.
	var bm: BuildMode = get_tree().get_first_node_in_group("build_mode")
	bm.book.open("chest")
	var page_text := bm.book.page().find_children("*", "Label", true, false).map(func(l): return l.text)
	check("Stores gear at camp." in page_text, "the build book says what the chest is for")
	check(bm.book.find_children("*", "", true, false).any(func(pc): return pc is Book.Pic and pc.picture != null), "with a picture of it built")
	bm.book.close()
	bm.choose("chest")
	await teleport(x + 800.0)
	player.aim_override = Vector2(x + 900.0, world.terrain.height_at(x + 900.0))
	await frames(3)
	var ev2 := InputEventAction.new()
	ev2.action = "use"
	ev2.pressed = true
	bm._unhandled_input(ev2)
	player.aim_override = Vector2.INF
	var cbp: Blueprint = null
	for b in get_tree().get_nodes_in_group("structure"):
		if b is Blueprint and b.build_id == "chest":
			cbp = b
	check(cbp != null, "chest blueprint placed")
	if cbp:
		await teleport(cbp.global_position.x)
		player.backpack.add(ItemStack.make("sticks", GameClock.clock.hours, 3))
		cbp.interact(player)
		var med := world.spawn({"kind": "log", "size": "medium", "x": cbp.global_position.x, "y": world.terrain.height_at(cbp.global_position.x) - 40.0}) as WorldLog
		await frames(5)
		player.carrying = med
		med.pick_up(player)
		cbp.interact(player)
		check(cbp.complete(), "chest materials in")
		cbp.interact(player)
		await frames(int(Builds.STRUCTURES.chest.seconds * 60.0) + 10)
		var built_chest := get_tree().get_nodes_in_group("structure").filter(func(n): return n is StorageChest)
		check(built_chest.size() >= 1, "the storage chest is built")
		if built_chest:
			built_chest[0].interact(player)
			check(ui.visible and ui.storage == built_chest[0].store, "E opens it beside the pack")
			var jk := player.backpack.find(func(st): return st.def.id == "jerky")
			ui.selected = jk
			ui._refresh()
			for b in ui._actions.get_children():
				if b is Button and b.text == "Move to the chest":
					b.pressed.emit()
			check(built_chest[0].store.count_of("jerky") > 0, "stored jerky in the chest")
			ui.toggle()

	# Being bitten looks and feels like it: knocked back, a flinch, a red flash, blood.
	var hp0 := player.cond.health
	var x0 := player.global_position.x
	player.take_hit(11.0, "legs", 0.35, x0 + 60.0, 260.0)
	await frames(4)
	var hud: Hud = get_tree().get_root().find_children("*", "Hud", true, false)[0]
	check(player.cond.health < hp0 and player.hurt_t > 0.0 and player.global_position.x < x0 and hud._flash > 0.0, "a bite knocks you back and flashes red (%.0f px)" % (x0 - player.global_position.x))
	player.cond.injuries.clear()
	player.cond.health = 100.0

	# --- Clothes survive death and the save.
	var d := player.to_dict()
	var p2 := Backpack.new()
	p2.from_dict(d.pack)
	check(p2.worn.body and p2.worn.body.def.id == "bear_coat" and p2.worn.head.def.id == "wolf_hat", "what you wear is saved")
	var old := d.duplicate(true)
	old.pack.erase("worn")
	old.pack.entries.append({"s": ItemStack.make("hide_coat").to_dict(), "x": 5, "y": 6, "r": false})
	player.cond.health = 0.0
	await frames(5)
	await get_tree().create_timer(4.5).timeout
	check(player.backpack.worn.body == bearc and not player.dead, "you come to still wearing your clothes")
	player.from_dict(old)
	check(player.backpack.worn.body != null and player.backpack.worn.body.def.id == "hide_coat", "an old save's coat in the pack gets worn")

	print("scenario failures: ", failures)
	get_tree().quit(failures)


# --- Mode "frontier" ----------------------------------------------------------------

func _site(kind: String) -> Site:
	for n in get_tree().get_nodes_in_group("landmark"):
		if n is Site and n.kind == kind:
			return n
	return null

func _frontier() -> void:
	await frames(10)
	GameClock.clock.hours = 10.0
	GameClock.force_weather(Weather.Kind.CLEAR)
	var t := world.terrain
	check(Terrain.WORLD_MIN < -20000.0 and Terrain.WORLD_MAX > 70000.0, "the world runs both ways from the trailhead")
	check(t.water_index(Terrain.CREEK_X) == 0 and t.height_at(Terrain.CREEK_X) > t.surface_of(0), "Rattlesnake Creek is where it always was")
	var river := 1
	check(Terrain.WATERS[river].kind == "river" and t.height_at(Terrain.WATERS[river].x) - t.surface_of(river) > 120.0, "the Sweetwater runs chest-deep")
	for b in ["sage", "meadow", "marsh", "river", "valley", "foothills", "ridge", "burn", "alpine"]:
		pass
	var seen_biomes := {}
	var x := Terrain.WORLD_MIN + 1000.0
	while x < Terrain.WORLD_MAX - 1000.0:
		seen_biomes[Terrain.biome(x)] = true
		x += 500.0
	check(seen_biomes.size() == 14, "fourteen kinds of country west to east: %s" % ", ".join(seen_biomes.keys()))

	# The river: drink and fill like the creek; wading it soaks you.
	var rx: float = Terrain.WATERS[river].x
	await teleport(rx - Terrain.WATERS[river].half + 120.0)
	await frames(10)
	var water := Creek.reachable(player)
	check(water != null and water.kind() == "river", "at the river's edge")
	player.hold(player.backpack.find(func(st): return st.def.id == "water_bottle"))
	player.held.water = 0.0
	water.interact(player)
	check(player.held.water > 0.5 and not player.held.water_clean, "filled the bottle from the river (dirty)")
	player.stow()
	await teleport(rx)
	await frames(20)
	check(player.wade_depth > 100.0, "mid-river the water's chest-deep (%.0f px)" % player.wade_depth)

	# A log bridge over it, through the build menu.
	await teleport(rx - Terrain.WATERS[river].half - 200.0)
	var bm: BuildMode = get_tree().get_first_node_in_group("build_mode")
	bm.choose("bridge")
	player.aim_override = Vector2(rx - 100.0, t.height_at(rx - 100.0))
	await frames(3)
	var use := InputEventAction.new()
	use.action = "use"
	use.pressed = true
	bm._unhandled_input(use)
	player.aim_override = Vector2.INF
	var bbp: Blueprint = null
	for n in get_tree().get_nodes_in_group("structure"):
		if n is Blueprint and n.build_id == "bridge":
			bbp = n
	check(bbp != null and absf(bbp.global_position.x - rx) < 1.0, "the bridge blueprint snaps over the river")
	if bbp:
		for size in ["long", "long", "long", "long", "medium", "medium"]:
			var lg := world.spawn({"kind": "log", "size": size, "x": player.global_position.x, "y": t.height_at(player.global_position.x) - 60.0}) as WorldLog
			await frames(3)
			player.carrying = lg
			lg.pick_up(player)
			bbp.interact(player)
		check(bbp.complete(), "logs delivered from the bank")
		bbp.interact(player)
		await frames(int(Builds.STRUCTURES.bridge.seconds * 60.0) + 20)
		var bridge := get_tree().get_nodes_in_group("structure").filter(func(n): return n is LogBridge)
		check(bridge.size() == 1, "the log bridge is built")
		player.auto_dir = 1.0
		var crossed := await _wait_until(func(): return player.global_position.x > rx + Terrain.WATERS[river].half + 100.0, 60 * 15)
		player.auto_dir = 0.0
		check(player.global_position.x > rx + Terrain.WATERS[river].half and player.cond.wetness < 0.05, "walked across dry (%d s)" % (crossed / 60))

	# The trapper's camp, just east of the river.
	await teleport(Terrain.TRAPPER_X)
	await frames(5)
	var tr := _site("trapper")
	check(tr != null and Player.choices_of(tr, player).size() == 2, "the trapper's camp: a cache and a carving")
	var snares := player.backpack.count_of("snare")
	tr.interact(player)
	await frames(60 * 4)
	check(player.backpack.count_of("snare") == snares + 3 and Journal.has("trapper_note"), "the cache: snares and the trapper's notebook")
	Player.choices_of(tr, player)[0][1].call()
	check(Journal.has("carving"), "\"Don't follow the lights.\"")

	# The homestead: the root cellar and the grave.
	await teleport(Terrain.HOMESTEAD_X + 100.0)
	await frames(5)
	var hs := _site("homestead")
	check(hs != null and Journal.has("homestead"), "found the old homestead")
	_run_option(_pick(_under_place("cellar"), "shelves"), "Search") # (the cellar has its own check in "under")
	await frames(60 * 4)
	check(Journal.has("diary_1") and Journal.has("diary_2") and player.backpack.count_of("tinned_beans") >= 2, "the root cellar: tins and a diary")
	Player.choices_of(hs, player)[0][1].call()
	check(Journal.has("grave"), "the grave: went up the ridge")

	# The plane wreck past the lookout.
	await teleport(Terrain.CRASH_X)
	await frames(5)
	var cr := _site("crash")
	check(cr != null and Journal.has("crash") and world.sheltered_at(Terrain.CRASH_X - 40.0), "the plane wreck in the burn: shelter inside the fuselage")
	check(Player.choices_of(cr, player).size() == 3, "cockpit, cargo, footprints")
	Player.choices_of(cr, player)[0][1].call()
	await frames(60 * 4)
	check(player.backpack.count_of("flare") == 2 and Journal.has("pilot_log"), "the cockpit: flares and the pilot's log")
	Player.choices_of(cr, player)[0][1].call()
	await frames(60 * 4)
	check((player.backpack.count_of("sealed_case") == 1 or (player.held and player.held.def.id == "sealed_case") or get_tree().get_nodes_in_group("interactable").any(func(n): return n is WorldItem and n.stack.def.id == "sealed_case")) and Journal.has("survivor_note"), "the cargo: a sealed case, and M's note")
	check(world.seen(73000.0), "the survey map fills in the basin")

	# A flare scatters wolves.
	var wolf := _wl().spawn_predator(Wildlife.WOLF, player.global_position.x + 900.0, 9)
	player.hold(player.backpack.find(func(st): return st.def.id == "flare"))
	player.use_held()
	await frames(10)
	check(wolf.state == Predator.State.FLEE and player.held != null and player.held.count == 1, "a flare goes up and the wolf runs")
	wolf.queue_free()

	# The far lights, at night, from the east.
	var bd: Backdrop = get_tree().get_root().find_children("*", "Backdrop", true, false)[0]
	var night := floorf(GameClock.clock.hours / 24.0) * 24.0
	for d in 3: # two nights in three: find one of them
		GameClock.clock.hours = night + d * 24.0 + 23.5
		if hash([GameClock.clock.day(), "lights"]) % 3 != 0:
			break
	await frames(90)
	check(bd._far_lights.visible and bd._far_lights.modulate.a > 0.1, "lights over the far range at night")

	# An old save's map (the valley only) grows to the whole world.
	var old := PackedByteArray()
	old.resize(240)
	old.fill(0)
	old[int(Terrain.CREEK_X / World.MAP_CELL)] = 1
	world.set_explored(old)
	check(world.explored.size() == World.MAP_CELLS and world.seen(Terrain.CREEK_X) and not world.seen(Terrain.CREEK_X - 2000.0), "an old save's map lines up in the bigger world")

	print("scenario failures: ", failures)
	get_tree().quit(failures)


# --- Mode "health" ------------------------------------------------------------------

func _cond_env(extra := {}) -> Dictionary:
	return {"air_c": 15.0, "exertion": 0.0}.merged(extra, true)

func _health() -> void:
	await frames(10)
	GameClock.clock.hours = 12.0
	GameClock.force_weather(Weather.Kind.CLEAR)
	var t := GameClock.tuning

	# Sickness comes on hours after bad water, and wears off; mint helps.
	var c := Condition.new(t)
	c.incubating = 0.6
	c.tick(0.5, _cond_env())
	check(c.sickness > 0.0 and c.sickness < 0.2, "sickness comes on slowly (%.2f after half an hour)" % c.sickness)
	for i in 6:
		c.tick(1.0, _cond_env())
	check(c.sickness > 0.5, "a few hours later it's bad (%.2f)" % c.sickness)
	var sick_hunger := c.hunger
	var well := Condition.new(t)
	well.tick(0.5, _cond_env())
	for i in 6:
		well.tick(1.0, _cond_env())
	check(sick_hunger < well.hunger - 3.0, "being sick drains you faster (hunger %d vs %d)" % [sick_hunger, well.hunger])
	c.use_herb("mint")
	check(c.sickness < 0.5, "wild mint settles it")

	# An open wound festers; a bandage stops it, yarrow cleans it; ignored, fever can kill.
	var w := Condition.new(t)
	w.injure("legs", "cut", 0.6)
	for i in 14:
		w.tick(1.0, _cond_env({"hands_covered": true}))
	check(w.infection > Condition.FEVER_AT, "an unbandaged bite festers into fever by the next day (%.2f)" % w.infection)
	var hp := w.health
	w.tick(4.0, _cond_env())
	check(w.health < hp, "a fever wears you down")
	w.use_herb("yarrow")
	check(w.infection < Condition.FEVER_AT and w.injuries.legs.treated, "yarrow cleans the wound")
	var ignored := Condition.new(t)
	ignored.injure("torso", "cut", 1.0)
	var died_at := -1
	for hr in 120:
		ignored.eat(100.0)
		ignored.drink(100.0)
		ignored.tick(1.0, _cond_env())
		if ignored.is_dead() and died_at < 0:
			died_at = hr
	check(died_at > 36 and died_at < 110, "a bad wound left alone kills in a couple of days (%d h)" % died_at)
	var careful := Condition.new(t)
	careful.injure("torso", "cut", 1.0)
	careful.treat("torso")
	for hr in 120:
		careful.eat(100.0)
		careful.drink(100.0)
		careful.tick(1.0, _cond_env())
	check(not careful.is_dead() and careful.infection < 0.05, "bandaged, it heals clean")

	# Frostbite takes bare hands in hard cold; mittens prevent it; a fire brings it back.
	var f := Condition.new(t)
	f.warmth = 5.0
	f.tick(2.0, _cond_env({"air_c": -25.0}))
	check(f.injuries.has("arms") and f.injuries.arms.kind == "frostbite", "bare hands frostbite in hard cold")
	var m := Condition.new(t)
	m.warmth = 5.0
	m.tick(2.0, _cond_env({"air_c": -25.0, "hands_covered": true}))
	check(not m.injuries.has("arms"), "mittens keep it off")
	var sev: float = f.injuries.arms.severity
	f.warmth = 50.0
	f.tick(1.0, _cond_env({"air_c": 10.0, "heat": 0.8}))
	check(not f.injuries.has("arms") or f.injuries.arms.severity < sev, "warming at a fire brings it back")

	# Wild plants: unknown until picked once, then named; hemlock is poison.
	await teleport(Terrain.CREEK_X - 1500.0)
	await frames(5)
	var plants := get_tree().get_nodes_in_group("plant")
	check(plants.size() > 10, "wild plants grow about the valley (%d nearby)" % plants.size())
	var yarrow: Plant = null
	for pl in plants:
		if pl.species == "yarrow" and pl.available():
			yarrow = pl
	if yarrow:
		check(yarrow.interact_label(player).begins_with("Unknown plant"), "an unknown plant: \"%s\"" % yarrow.interact_label(player))
		yarrow.interact(player)
		check(player.backpack.count_of("yarrow") == 2 and Journal.has("plant_yarrow"), "picked it: yarrow, in the pack and the journal")
		var other: Plant = null
		for pl in plants:
			if pl.species == "yarrow" and pl != yarrow and pl.available():
				other = pl
		if other:
			check(other.interact_label(player) == "Pick yarrow", "the next one's named before you pick it")
	var hem := Plant.new()
	hem.species = "water_hemlock"
	check(not Plant.known(player, "water_hemlock") and hem.interact_label(player).contains("purple-streaked"), "hemlock, unknown, looks a lot like yarrow")
	hem.free()
	player.known_plants["water_hemlock"] = true
	var hem2 := Plant.new()
	hem2.species = "water_hemlock"
	check(hem2.interact_label(player).contains("poisonous"), "known, it's named as poison")
	hem2.free()
	var before := player.cond.health
	player.hold(ItemStack.make("water_hemlock", GameClock.clock.hours))
	player.use_held()
	check(player.cond.health < before - 20.0 and player.cond.incubating > 0.5, "eating it is poison")
	player.cond.health = 100.0
	player.cond.incubating = 0.0

	# Dirty water: some chance of sickness later instead of harm straight away.
	var got := 0
	for i in 40:
		var cc := Condition.new(t)
		if cc.expose(Creek.SICK_AMOUNT, Creek.SICK_CHANCE):
			got += 1
	check(got > 4 and got < 25, "unboiled water makes you sick some of the time (%d of 40)" % got)

	await _health_cooking()
	await _polish()
	print("scenario failures: ", failures)
	get_tree().quit(failures)

## Pot cooking, crafting that fetches from chests, and winter travel.
func _health_cooking() -> void:
	player.stow()
	var x := 9000.0
	await teleport(x)
	await _clear_wild()
	var h := GameClock.clock.hours
	# A camp: fire with a hanging pot of creek water, a chest a few metres off holding meat.
	var fire := world.spawn({"kind": "campfire", "x": x + 60.0, "fuel": 8.0, "lit": true, "tripod": true,
		"pot": ItemStack.make("cook_pot", h).to_dict()}) as Campfire
	fire.pot.add_water(1.5, false)
	var chest := world.spawn({"kind": "chest", "x": x + 500.0}) as StorageChest
	chest.store.add(ItemStack.make("venison_raw", h, 2))
	player.backpack.take("#meat", player.backpack.count_of("#meat")) # (jerky counts as meat too)
	player.backpack.add(ItemStack.make("berries", h, 2))
	await frames(3)
	var stew := Player.choices_of(fire, player).filter(func(o): return o[0].begins_with("Cook stew"))
	check(stew.size() == 1, "the fire offers a stew: meat in the chest, berries in the pack")
	if stew:
		stew[0][1].call()
		await frames(5)
		check(player.errand_label == "" and player.busy(), "off to fetch the meat from the chest")
		var reached := await _wait_until(func(): return player.errand_label != "", 60 * 10)
		check(absf(player.global_position.x - chest.global_position.x) < 40.0, "walked to the chest and rummages in it (%d s)" % (reached / 60))
		await _wait_until(func(): return player.working > 0.0, 60 * 10)
		check(absf(player.global_position.x - fire.global_position.x) < 40.0 and chest.store.count_of("venison_raw") == 0, "back at the fire with the meat, cooking")
		await _wait_until(func(): return player.working <= 0.0, 60 * 10)
		check(player.backpack.count_of("stew") == 3 and fire.pot.water < 1.0, "three bowls of stew from the pot")
		var th := player.cond.thirst
		player.cond.thirst = 50.0
		player.hold(player.backpack.find(func(st): return st.def.id == "stew"))
		player.use_held()
		check(player.cond.thirst > 55.0, "hot stew warms you and wets your throat")
		player.cond.thirst = th
		player.stow()
	# Mint tea.
	player.backpack.add(ItemStack.make("mint", h, 2))
	fire.pot.add_water(1.0, false)
	await frames(2)
	var tea := Player.choices_of(fire, player).filter(func(o): return o[0].begins_with("Cook mint tea"))
	check(tea.size() == 1, "and mint tea")
	if tea:
		tea[0][1].call()
		await _wait_until(func(): return not player.busy(), 60 * 10)
		check(player.backpack.count_of("mint_tea") == 2, "two cups of mint tea")

	# Crafting at the bench takes what it needs from the chest, fetching it.
	var bench := world.spawn({"kind": "workbench", "x": x - 300.0}) as Workbench
	chest.store.add(ItemStack.make("sticks", h, 3))
	player.backpack.take("sticks", player.backpack.count_of("sticks"))
	await teleport(x - 300.0)
	var ui: BackpackUI = get_tree().get_first_node_in_group("backpack_ui")
	check(Supply.have(player, "sticks", bench.global_position.x) == 3, "the bench can see the chest's sticks")
	ui._craft("spear")
	await _wait_until(func(): return not player.busy(), 60 * 20)
	check(player.backpack.count_of("spear") >= 1 or (player.held and player.held.def.id == "spear"), "made a spear from the chest's sticks")
	check(chest.store.count_of("sticks") == 0, "the chest gave them up")
	# A blueprint takes sticks from the chest too.
	chest.store.add(ItemStack.make("sticks", h, 4))
	var wp := world.spawn({"kind": "blueprint", "build": "woodpile", "x": x + 900.0}) as Blueprint
	await teleport(x + 900.0)
	wp.interact(player)
	await _wait_until(func(): return not player.busy(), 60 * 20)
	check(wp.complete(), "a blueprint takes its sticks from the chest nearby")

	# Winter travel: snowshoes on deep snow; a sled; ice fishing; a blizzard's chill.
	GameClock.weather.snow_cm = 60.0
	var shoes := ItemStack.make("snowshoes", h)
	player.backpack.add(shoes)
	var plain := player.snow_mult()
	player.backpack.wear(shoes)
	check(player.snow_mult() > plain + 0.25, "snowshoes on knee-deep snow: %.2f of your pace instead of %.2f" % [player.snow_mult(), plain])
	var sled := world.spawn({"kind": "sled", "x": x + 1300.0}) as Sled
	await teleport(x + 1300.0)
	var lg := world.spawn({"kind": "log", "size": "long", "x": x + 1300.0, "y": world.terrain.height_at(x + 1300.0) - 60.0}) as WorldLog
	await frames(3)
	player.carrying = lg
	lg.pick_up(player)
	Player.choices_of(sled, player).filter(func(o): return o[0].begins_with("Load the"))[0][1].call()
	check(sled.logs == ["long"] and player.carrying == null, "a long log loaded on the sled")
	player.start_pull(sled)
	var start := player.global_position.x
	player.auto_dir = 1.0
	await frames(120)
	player.auto_dir = 0.0
	var went := player.global_position.x - start
	check(player.pulling == sled and went > 150.0 and absf(sled.global_position.x - (player.global_position.x - Sled.OFFSET)) < 5.0, "pulling the loaded sled over snow (%.0f px in 2 s)" % went)
	player.drop_haul()
	GameClock.weather.snow_cm = 0.0
	GameClock.weather.ice = 1.0
	await teleport(Terrain.CREEK_X)
	await frames(10)
	var creek := Creek.reachable(player)
	check(creek != null, "out on the frozen creek")
	if creek:
		creek.interact(player)
		check(creek.hole_open(), "chopped a hole in the ice")
		player.receive(ItemStack.make("fishing_pole", h))
		player.hold(player.backpack.find(func(st): return st.def.has("rod")))
		player.aim_override = Vector2(Terrain.CREEK_X + 300.0, 0)
		player.fishing.press()
		player.aim_override = Vector2.INF
		check(player.fishing.state == Fishing.State.CAST and absf(player.fishing.bobber.x - creek.hole_x) < 1.0, "ice fishing: the line drops through the hole")
		player.fishing.state = Fishing.State.IDLE
		player.stow()
	GameClock.weather.ice = 0.0
	var calm := Condition.new(GameClock.tuning)
	calm.tick(2.0, _cond_env({"air_c": -8.0}))
	GameClock.force_weather(Weather.Kind.RAIN)
	GameClock.weather.snow_frac = 1.0
	GameClock.weather.wind = 0.9
	check(GameClock.weather.blizzard() > 0.8, "cold, snow and a gale: a blizzard")


## Settings (keys, volumes, kept apart from saves), the first-days checklist, music cues.
func _polish() -> void:
	var before := Keys.label("interact")
	Settings.bind("interact", KEY_G)
	check(Keys.label("interact") == "G" and InputMap.action_get_events("interact").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_G), "rebound Interact to G")
	Settings.volume.Music = 0.3
	Settings.save()
	check(Settings.path().begins_with("user://test_saves"), "a test run keeps its settings apart from the player's")
	Settings.volume.Music = 1.0
	Settings.keys.clear()
	Settings.load_and_apply()
	check(absf(Settings.volume.Music - 0.3) < 0.01 and Keys.label("interact") == "G", "settings come back from disk")
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))) - 0.3) < 0.01, "the music bus follows the slider")
	Settings.reset_keys()
	Settings.volume.Music = 0.8
	Settings.save()
	check(Keys.label("interact") == before, "keys back to defaults")
	var hud: Hud = get_tree().get_root().find_children("*", "Hud", true, false)[0]
	var tips: Tips = get_tree().get_root().find_children("*", "Tips", true, false)[0]
	tips._update_goals()
	check(hud.goals.size() == 6 or tips.seen.has("goals_done"), "the first-days checklist is up")
	var amb: Ambience = get_tree().get_root().find_children("*", "Ambience", true, false)[0]
	amb._music_cooldown = 0.0
	amb.music.stop()
	amb._cue("night", -3.0)
	check(amb.music.playing and amb.music.stream == amb._cues.night, "the night music plays")
	amb._cue("dawn", -6.0)
	check(amb.music.stream == amb._cues.night, "and music stays rare: no cue on top of another")
	amb.music.stop()

# --- Mode "hunts": wolves run down deer (or don't), kill sites, coyotes -------------------

func _pack_of(x: float, n: int, seed_value: int) -> Array:
	var pack := []
	for k in n:
		var w := _wl().spawn_predator(Wildlife.WOLF, x + k * 90.0, seed_value + k)
		w.pack = pack
		pack.append(w)
	return pack

func _hunts() -> void:
	await frames(10)
	var year := GameClock.clock.season_hours() * 4.0
	GameClock.clock.hours = floorf((ceilf(GameClock.clock.hours / year) * year + year * 0.4) / 24.0) * 24.0 + 23.0 # a winter night
	GameClock.force_weather(Weather.Kind.CLEAR)
	GameClock.weather.snow_cm = 70.0
	check(Predator.snow_drag(true) < Predator.snow_drag(false), "deep snow bogs a deer down more than a wolf (%.2f vs %.2f)" % [Predator.snow_drag(true), Predator.snow_drag(false)])
	var x := 9000.0
	await teleport(x)
	await _clear_wild()
	var deer: Animal = await _deer(x + 1500.0, 31)
	var pack := _pack_of(x + 3000.0, 3, 40)
	var n := await _wait_until(func(): return pack[0].state == Predator.State.CHASE, 60 * 10)
	check(pack.all(func(w): return w.state == Predator.State.CHASE and w.prey == deer), "a winter night: the pack goes after the deer (%d s)" % (n / 60))
	for w in pack:
		w._doomed = true # (this one's going down)
	var gone: WeakRef = weakref(deer)
	n = await _wait_until(func(): return gone.get_ref() == null or gone.get_ref().is_queued_for_deletion(), 60 * 25)
	await frames(2)
	var kill := _carcasses().filter(func(c): return c.deer() and c.torn)
	check(gone.get_ref() == null and kill.size() == 1, "floundering in the snow, it's pulled down (%d s)" % (n / 60))
	check(world.tracks.prints.any(func(p): return p.s == "blood"), "blood in the snow")
	n = await _wait_until(func(): return pack.any(func(w): return is_instance_valid(w) and w.state == Predator.State.FEED), 60 * 10)
	check(n < 600, "the pack feeds on it")
	if kill:
		var meat0: float = kill[0].meat
		await frames(60 * 5)
		check(kill[0].meat < meat0, "eating into it")
		player.hold(ItemStack.make("torch", GameClock.clock.hours))
		await teleport(kill[0].global_position.x - 300.0)
		await frames(90)
		check(pack.all(func(w): return not is_instance_valid(w) or w.state == Predator.State.FLEE), "a torch drives them off the kill")
		check(kill[0].meat >= 1.0 and kill[0].deer(), "there's meat left to take")
		player.stow()
	await _clear_wild()
	for c in _carcasses():
		c.queue_free()

	# Summer, no snow: the deer outruns them and they give up.
	GameClock.clock.hours = floorf((ceilf(GameClock.clock.hours / year) * year + year * 0.85) / 24.0) * 24.0 + 23.0
	GameClock.weather.snow_cm = 0.0
	await teleport(x)
	deer = await _deer(x + 1500.0, 33)
	pack = _pack_of(x + 3000.0, 2, 50)
	await _wait_until(func(): return pack[0].state == Predator.State.CHASE, 60 * 10)
	for w in pack:
		w._doomed = false
	n = await _wait_until(func(): return pack[0].state != Predator.State.CHASE, 60 * 25)
	check(is_instance_valid(deer) and pack[0].state != Predator.State.CHASE and pack[0]._hunt_cd > 0.0, "summer: the deer gets away and the wolves give up (%d s)" % (n / 60))
	await _clear_wild()

	# Winter: a kill site turns up ahead, torn and tracked.
	GameClock.clock.hours = floorf((ceilf(GameClock.clock.hours / year) * year + year * 0.4) / 24.0) * 24.0 + 12.0
	GameClock.weather.snow_cm = 40.0
	await teleport(x)
	world.tracks.prints.clear()
	var site: Carcass = _wl().kill_site(1100.0)
	check(site != null and site.torn and site.meat >= 1.0, "a wolf kill turns up out ahead")
	if site:
		check(world.tracks.prints.filter(func(p): return p.s == "wolf" and absf(p.x - site.global_position.x) < 300.0).size() >= 5, "wolf tracks trampled round it")
		site.queue_free()

	# Coyotes: a scavenger that runs from you.
	var sx := -18000.0
	check(Terrain.biome(sx) == "sage", "the sage flats")
	await teleport(sx)
	await _clear_wild()
	var gut := world.spawn({"kind": "gut_pile", "x": sx + 1600.0, "hour": GameClock.clock.hours}) as Node2D
	var coy := _wl().spawn_predator(Wildlife.COYOTE, sx + 3200.0, 60)
	n = await _wait_until(func(): return coy.state == Predator.State.FEED, 60 * 20)
	check(coy.state == Predator.State.FEED, "a coyote comes to the gut pile (%d s)" % (n / 60))
	check(coy.get_child(0).scale.y < 0.9, "smaller than a wolf")
	await teleport(coy.position.x - 900.0)
	player.auto_dir = 1.0
	n = await _wait_until(func(): return coy.state == Predator.State.FLEE, 60 * 6)
	player.auto_dir = 0.0
	check(coy.state == Predator.State.FLEE and absf(coy.position.x - player.global_position.x) > 450.0, "walk toward it and it runs")
	await _clear_wild()
	gut.queue_free()
	await teleport(sx)
	coy = _wl().spawn_predator(Wildlife.COYOTE, sx + 800.0, 61)
	coy.set_physics_process(false)
	coy.position.y = world.ground_y(coy.position.x)
	coy.facing = -1
	player.receive(ItemStack.make("arrows", GameClock.clock.hours, 2))
	player.hold(ItemStack.make("bow", GameClock.clock.hours))
	player.facing = 1
	var chest := coy.position + Vector2(-30.0 * 0.78, -58.0 * 0.78)
	check(coy.zone_at(chest) == 2, "a coyote's chest is its vitals")
	player.aim_override = _lead(chest)
	player.bow_draw = 1.0
	player.loose()
	await frames(60)
	player.aim_override = Vector2.INF
	var dead := _carcasses().filter(func(c): return c.species == "coyote")
	check(dead.size() == 1, "an arrow takes the coyote")
	if dead:
		player.stow()
		await teleport(dead[0].global_position.x)
		check(dead[0].interact_label(player) == "Skin the coyote", "skin it")
		dead[0].interact(player)
		await _finish_work()
		check(player.backpack.count_of("coyote_pelt") == 1, "a coyote pelt")
	check(HideFrame.KINDS.has("coyote_pelt"), "it cures on the hide frame")
	player.backpack.add(ItemStack.make("coyote_fur", GameClock.clock.hours))
	check(Supply.can(player, Builds.RECIPES.wolf_hat.needs, player.global_position.x), "coyote fur makes a fur hat")
	var snared := world.spawn({"kind": "snare", "x": sx + 300.0, "caught": true}) as Snare
	check(snared.appeals("coyote"), "a coyote will take a rabbit from a snare")
	snared.queue_free()
	# The spawner: coyotes turn up on the sage at night.
	await _clear_wild()
	GameClock.clock.hours = floorf(GameClock.clock.hours / 24.0) * 24.0 + 23.0
	var seen := false
	for k in 60:
		_wl()._manage_predators()
		if get_tree().get_nodes_in_group("predators").any(func(p): return p.is_coyote() and not p.is_queued_for_deletion()):
			seen = true
			break
	check(seen, "coyotes turn up on the sage at night")
	await _clear_wild()
	print("scenario failures: ", failures)
	get_tree().quit(failures)

# --- Mode "stores": the cellar, raids, the raised cache, the bear bag, the smokehouse -----

func _stores() -> void:
	await frames(10)
	var year := GameClock.clock.season_hours() * 4.0
	GameClock.clock.hours = floorf((ceilf(GameClock.clock.hours / year) * year + year * 0.85) / 24.0) * 24.0 + 12.0 # summer noon
	GameClock.force_weather(Weather.Kind.CLEAR)
	check(StorageChest.keep_rate(world, 9000.0) == 1.0 and StorageChest.keep_rate(world, 9000.0, true) <= 0.35, "summer: food keeps as usual up top, about three times as long in the cellar")

	# The root cellar's shelves: cool storage.
	var cellar := _under_place("cellar")
	if cellar == null:
		await teleport(Terrain.HOMESTEAD_X)
		await frames(10)
		cellar = _under_place("cellar")
	var shelves := _pick(cellar, "shelves")
	await teleport_under(shelves.global_position.x, shelves.global_position.y)
	cellar._mark("shelves") # (searched)
	check(Player.choices_of(shelves, player).any(func(o): return o[0].begins_with("Keep things on the shelves")), "the searched shelves keep things")
	var store: StorageChest = cellar._shelf_store()
	var meat := ItemStack.make("venison_raw", GameClock.clock.hours)
	store.store.add(meat)
	var made := meat.made_hour
	store._on_tick(24.0)
	check(absf(meat.made_hour - made - 24.0 * 0.65) < 0.5, "a day on the cellar shelves ages raw meat about a third as much (%.1f h credit)" % (meat.made_hour - made))
	check(cellar._shelf_store() == store and store.to_state().has("y"), "one store, saved down in the cellar")

	# A chest of food left out in bear country: raided. By a fire: safe.
	var bx := 30000.0
	await teleport(bx + 2600.0)
	var chest := world.spawn({"kind": "chest", "x": bx}) as StorageChest
	chest.store.add(ItemStack.make("venison_raw", GameClock.clock.hours, 2))
	chest.store.add(ItemStack.make("snare"))
	chest._on_tick(200.0)
	check(chest.store.count_of("venison_raw") == 0 and chest.store.count_of("snare") == 1 and chest.raided.begins_with("The lid"), "a chest of food left in bear country: the bear takes the food")
	var fire := world.spawn({"kind": "campfire", "x": bx + 300.0}) as Campfire
	chest.store.add(ItemStack.make("venison_raw", GameClock.clock.hours, 2))
	chest._on_tick(300.0)
	check(chest.store.count_of("venison_raw") == 2, "by a campfire nothing comes for it")
	fire.queue_free()
	chest.queue_free()
	await teleport(9000.0 + 2600.0)
	var chest2 := world.spawn({"kind": "chest", "x": 9000.0}) as StorageChest
	chest2.store.add(ItemStack.make("berries", GameClock.clock.hours, 4))
	seed(7) # (raids are chance: fix the dice)
	for k in 4:
		chest2._on_tick(100.0)
	check(chest2.store.count_of("berries") < 4 and chest2.raided.begins_with("Droppings"), "in the valley, mice get into some of it")
	chest2.queue_free()

	# The raised cache: climb up, stand on the deck, open it, hop off.
	var cx := 9600.0
	await teleport(cx - 400.0)
	var cache := world.spawn({"kind": "cache", "x": cx}) as RaisedCache
	cache.store.add(ItemStack.make("venison_raw", GameClock.clock.hours, 2))
	await teleport(cx + RaisedCache.LADDER_X)
	check(player.focus == cache and Player.first_label(Player.choices_of(cache, player)) == "Climb up to the cache", "at the ladder: climb up")
	cache.interact(player)
	await _finish_work()
	await frames(20)
	check(cache.up_top(player) and absf(player.global_position.y - (cache.global_position.y + RaisedCache.DECK_Y)) < 12.0, "standing on the deck (%.0f px up)" % (cache.global_position.y - player.global_position.y))
	await frames(4)
	check(player.focus == cache and Player.first_label(Player.choices_of(cache, player)).begins_with("Open the cache"), "up top: open the cache")
	player.go_down()
	await frames(60)
	check(not cache.up_top(player) and absf(player.global_position.y - world.ground_y(player.global_position.x)) < 12.0, "S hops off the deck to the ground")
	cache._on_tick(500.0)
	check(cache.store.count_of("venison_raw") == 2, "nothing raids the cache")
	cache.queue_free()

	# The bear bag: hung from a tall tree, it dangles, sways in the wind, comes down and goes up.
	await teleport(12000.0)
	var tree: ChoppableTree = null
	for t in get_tree().get_nodes_in_group("choppable"):
		if t is ChoppableTree and t.height >= 1000.0 and absf(t.global_position.x - 12000.0) < 3000.0:
			tree = t
			break
	check(tree != null, "a tall tree to hang a bag from")
	if tree:
		var bm: BuildMode = get_tree().get_first_node_in_group("build_mode")
		check(Blueprint.host_at(get_tree(), "tree", tree.global_position.x + 50.0, 400.0) == tree, "the bear bag's blueprint snaps to the tree")
		GameClock.weather.wind = 0.05
		var bag := world.spawn({"kind": "bear_bag", "x": tree.global_position.x, "height": tree.height}) as BearBag
		await teleport(tree.global_position.x - 40.0)
		await frames(120)
		var hang := bag.bag_pos()
		check(-hang.y - BearBag.BAG.y >= BearBag.RAISED - 20.0, "hauled up, the bag hangs high (%.0f px off the ground)" % (-hang.y - BearBag.BAG.y))
		check(absf(hang.x - bag.anchor.x) < 12.0, "on a still day it hangs straight down under the branch")
		GameClock.weather.wind = 1.0
		GameClock.weather.wind_dir = 1
		var most := 0.0
		for k in 240:
			await frames(1)
			most = maxf(most, bag.bag_pos().x - bag.anchor.x)
		check(most > 25.0, "in a gale it swings out downwind (%.0f px)" % most)
		GameClock.weather.wind = 0.1
		check(Player.first_label(Player.choices_of(bag, player)).begins_with("Lower the bear bag"), "at the trunk: lower it")
		bag.interact(player)
		await _finish_work()
		await frames(120)
		check(bag.on_ground() and -bag.bag_pos().y - BearBag.BAG.y < 20.0, "let down, it rests on the ground")
		bag.store.add(ItemStack.make("venison_raw", GameClock.clock.hours, 2))
		Player.choices_of(bag, player).filter(func(o): return o[0].begins_with("Haul"))[0][1].call()
		await _finish_work()
		await frames(120)
		check(not bag.on_ground() and -bag.bag_pos().y - BearBag.BAG.y >= BearBag.RAISED - 20.0, "hauled back up and tied off")
		await teleport(tree.global_position.x + 2600.0)
		bag._on_tick(300.0)
		check(bag.store.count_of("venison_raw") == 2, "up high, nothing gets it")
		await teleport(tree.global_position.x - 300.0)
		tree._fell(1.0)
		await frames(120)
		check(bag.fallen and bag.on_ground(), "fell the tree and the bag comes down with it")
		bag.queue_free()

	# The smokehouse: hang meat, feed the smudge, ten hours later it's smoked.
	await teleport(9000.0)
	var sh := world.spawn({"kind": "smokehouse", "x": 9300.0}) as Smokehouse
	await teleport(9300.0)
	player.backpack.add(ItemStack.make("venison_raw", GameClock.clock.hours, 2))
	player.backpack.add(ItemStack.make("trout_raw", GameClock.clock.hours, 1))
	player.backpack.add(ItemStack.make("sticks", GameClock.clock.hours, 4))
	check(Player.first_label(Player.choices_of(sh, player)).begins_with("Hang 2 "), "bring raw meat: hang it in the smoke (%s)" % Player.first_label(Player.choices_of(sh, player)))
	sh.interact(player)
	sh.interact(player)
	check(sh.pieces.size() == 3, "meat and a fish hanging")
	Player.choices_of(sh, player).filter(func(o): return o[0].begins_with("Feed"))[0][1].call()
	check(sh.fuel >= 9.0 and sh.smoking(), "the smudge is going (%.0f h of smoke)" % sh.fuel)
	sh._on_tick(11.0)
	check(sh.smoked() == 3, "ten hours of smoke: done")
	sh.interact(player)
	check(player.backpack.count_of("smoked_meat") == 2 and player.backpack.count_of("smoked_fish") == 1, "two smoked venison and a smoked trout")
	check(Items.get_def("smoked_meat").spoil_hours > Items.get_def("jerky").spoil_hours, "smoked meat keeps longer than jerky")
	check(Builds.BUILD_GROUPS.values().reduce(func(a, g): return a + g.size(), 0) == Builds.STRUCTURES.size(), "every build is in the build book")
	for id in ["smokehouse", "cache", "bear_bag"]:
		check(ResourceLoader.exists("res://assets/builds/%s.png" % id), "the build book has a picture of the %s" % id)
	print("scenario failures: ", failures)
	get_tree().quit(failures)

# --- Mode "sounds": every biome sounds like itself; seasons, blending, echo, calls -----

func _amb() -> Ambience:
	return get_tree().get_root().find_children("*", "Ambience", true, false)[0]

## Lets the beds settle at x and returns their linear gains.
func _listen(x: float, secs := 6.0) -> Dictionary:
	await teleport(x)
	await frames(int(secs * 60.0))
	var out := {}
	var amb := _amb()
	for n in amb.beds:
		out[n] = db_to_linear(amb.beds[n].volume_db)
	return out

func _loudest(g: Dictionary) -> String:
	var best := ""
	for n in g:
		if n not in ["rain", "wind_storm"] and Ambience.KIND.get(n) != "wind" and (best == "" or g[n] > g[best]):
			best = n
	return best

func _sounds() -> void:
	await frames(10)
	var amb := _amb()
	GameClock.force_weather(Weather.Kind.CLEAR)
	var year := GameClock.clock.season_hours() * 4.0
	var summer := ceilf(GameClock.clock.hours / year) * year + year * 0.85 # year_pos 0.35: summer
	GameClock.clock.hours = floorf(summer / 24.0) * 24.0 + 12.0
	check(GameClock.clock.season() == 1, "summer noon (%s)" % GameClock.clock.season_name())
	for b in Ambience.PROFILES:
		check(Ambience.PROFILES[b].day.keys().all(func(n): return amb.beds.has(n)), "%s: its beds are loaded" % b)
	var spots := {"valley": 6000.0, "desert": -30000.0, "marsh": -12500.0, "sage": -18000.0, "oldgrowth": 83000.0, "foothills": 30000.0}
	var heard := {}
	var valley_birds := 0.0
	for b in spots:
		check(Terrain.biome(spots[b]) == b, "%.0f is %s" % [spots[b], b])
		var g := await _listen(spots[b])
		heard[b] = _loudest(g)
		if b == "valley":
			valley_birds = g.forest_day
		print("  %s: loudest %s (%s)" % [b, heard[b], ", ".join(g.keys().filter(func(n): return g[n] > 0.05).map(func(n): return "%s %.2f" % [n, g[n]]))])
	check(heard.valley == "forest_day", "the valley by day: woodland birds")
	check(heard.desert in ["desert_day", "cicadas"], "the desert: heat and cicadas, not woodland birds (%s)" % heard.desert)
	check(heard.marsh == "marsh_day", "the marsh: marsh birds (%s)" % heard.marsh)
	check(heard.sage == "sage_day", "the sage: meadowlarks (%s)" % heard.sage)
	check(heard.foothills == "foothills_day", "the foothills (%s)" % heard.foothills)
	check(heard.values().size() > 3 and heard.values().filter(func(v): return v == "forest_day").size() <= 2, "the country doesn't all sound the same")
	# Walking from the valley into the next country: both are heard, blending.
	var edge := 6000.0
	while Terrain.biome(edge) == "valley" and edge < 30000.0:
		edge += 200.0
	var mix := amb.blend_at(edge - 100.0)
	check(mix.size() >= 2 and mix.get("valley", 0.0) > 0.1, "at the edge of the valley the two blend (%s)" % mix)
	# Night: crickets, frogs in the marsh; the sage has coyotes among its calls.
	GameClock.clock.hours = floorf(GameClock.clock.hours / 24.0) * 24.0 + 24.0 + 1.0
	var gn := await _listen(-12500.0, 8.0)
	check(gn.marsh_night > 0.3 and gn.forest_day < 0.05, "a summer night in the marsh: the frog chorus, no daytime birds")
	# Winter: no insects or frogs, fewer birds.
	GameClock.clock.hours = floorf((ceilf(GameClock.clock.hours / year) * year + year * 0.4) / 24.0) * 24.0 + 12.0 # year_pos 0.9, noon
	check(GameClock.clock.season() == 3, "winter (%s)" % GameClock.clock.season_name())
	var gw := await _listen(-30000.0, 10.0)
	check(gw.cicadas < 0.03 and gw.desert_day < 0.03, "winter in the desert: no cicadas (%.2f)" % gw.cicadas)
	var gv := await _listen(6000.0, 10.0)
	check(gv.forest_day < valley_birds * 0.6, "winter in the valley: fewer birds (%.2f)" % gv.forest_day)
	# Echo: the canyon rings, the valley doesn't.
	GameClock.clock.hours = summer + 24.0 * 2.0
	await _listen(-35000.0, 12.0)
	var canyon_wet: float = amb._reverbs[0].wet
	await _listen(6000.0, 12.0)
	check(canyon_wet > 0.2 and amb._reverbs[0].wet < 0.1, "the canyon echoes (%.2f), the valley barely (%.2f)" % [canyon_wet, amb._reverbs[0].wet])
	# Calls: one plays on the Calls bus through the echo.
	amb.call_out("canyon_wren", 1)
	var players := amb.find_children("*", "AudioStreamPlayer2D", false, false).filter(func(n): return n.bus == &"Calls")
	check(players.size() >= 1 and players.all(func(pl): return pl.playing), "calls play out around you on the Calls bus (%d now)" % players.size())
	check(ResourceLoader.exists("res://assets/audio/sfx/axe_1.wav") and Sfx.chop().streams_count == 12, "chopping: real axe strikes (%d takes)" % Sfx.chop().streams_count)
	for pool in ["woodpecker", "coyotes", "marmot", "pika", "thrush", "elk", "wolves", "grizzly", "raven"]:
		check(ResourceLoader.exists("res://assets/audio/sfx/%s_1.wav" % pool), "has %s" % pool)
	print("scenario failures: ", failures)
	get_tree().quit(failures)

# --- Mode "icons": pictures of every build for the build book (run windowed, not headless) --

func _icons() -> void:
	await frames(10)
	var vp := SubViewport.new()
	vp.size = Vector2i(900, 520)
	vp.transparent_bg = true
	vp.world_2d = World2D.new() # its own canvas: no sky, no night, no scenery behind
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera2D.new()
	vp.add_child(cam)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/builds"))
	GameClock.clock.hours = floorf(GameClock.clock.hours / 24.0) * 24.0 + 12.0
	for id in Builds.STRUCTURES:
		var x := 9000.0
		if id == "bridge":
			x = world.terrain.WATERS[world.terrain.water_index(Terrain.CREEK_X, 2000.0)].x
		await teleport(x)
		var n: Node2D = world.spawn({"kind": "campfire" if id == "tripod" else id, "x": x})
		if id == "tripod":
			n.set("tripod", true)
		await frames(3)
		var ground := n.global_position.y
		n.reparent(vp)
		n.position = Vector2(0, n.global_position.y - ground)
		n.process_mode = Node.PROCESS_MODE_DISABLED # stays as drawn
		var d: Dictionary = Builds.STRUCTURES[id]
		var w: float = maxf(d.width, 120.0) + 80.0
		var h: float = maxf(d.h, 60.0) + 60.0
		cam.position = Vector2(0, -h * 0.5 + 20.0)
		cam.zoom = Vector2.ONE * minf(minf(860.0 / w, 480.0 / h), 1.6)
		n.queue_redraw()
		for c in n.get_children():
			if c is CanvasItem:
				c.queue_redraw()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var used := img.get_used_rect()
		if used.size.x > 4:
			img = img.get_region(used.grow(6).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		img.save_png("res://assets/builds/%s.png" % id)
		print("icon ", id, " ", img.get_size())
		n.queue_free()
		await frames(2)
	get_tree().quit(0)

# --- Mode "under": the cellar, the cave and the mine; regrowth; the newest country -------

func _under_place(kind: String) -> Underground:
	for u in get_tree().get_nodes_in_group("underground"):
		if u.kind == kind:
			return u
	return null

## Walks the player (auto_dir) until cond holds or frames run out.
func _walk(dir: float, cond: Callable, max_frames := 900) -> bool:
	player.auto_dir = dir
	var ok := await _wait_until(cond, max_frames) < max_frames
	player.auto_dir = 0.0
	await frames(4)
	return ok

func _pick(u: Underground, id: String) -> Node:
	for c in u.get_children():
		if c is Underground.Spot and c.id == id:
			return c
	return null

func _run_option(n: Node, label_has: String) -> bool:
	for o in Player.choices_of(n, player):
		if label_has in o[0]:
			o[1].call()
			return true
	return false

func _finish_work() -> void:
	await _wait_until(func(): return player.working <= 0.0 and not player.climbing and player._errand.is_empty(), 1200)
	await frames(4)

func _under() -> void:
	await frames(10)
	GameClock.clock.hours = 12.0
	GameClock.force_weather(Weather.Kind.CLEAR)
	var t := world.terrain

	# The newest country, both ends, and every hollow carved cleanly with ground over it.
	var seen_biomes := {}
	var x := Terrain.WORLD_MIN + 1000.0
	while x < Terrain.WORLD_MAX - 1000.0:
		seen_biomes[Terrain.biome(x)] = true
		x += 500.0
	for b in ["desert", "canyon", "boulders", "oldgrowth", "grove"]:
		check(seen_biomes.has(b), "the %s is out there" % b)
	check(t.height_at(-35000.0) - t.height_at(-29000.0) > 500.0, "the canyon floor lies well below the desert")
	check(t.height_at(84000.0) - t.height_at(70000.0) > 1200.0, "the forest lies far below the basin")
	for ux in Underground.PLACES:
		var kind: String = Underground.PLACES[ux]
		var o := Underground.origin_of(ux, t)
		var h: Array = Underground.HATCH[kind]
		var worst := INF
		for v in Underground.CAVITY[kind]:
			if v[0] >= minf(h[0], h[1]) - 5.0 and v[0] <= maxf(h[0], h[1]) + 5.0:
				continue
			worst = minf(worst, o.y + v[1] - t.height_at(ux + v[0] * Underground.DIR[kind]))
		check(worst > 50.0, "%s: ground over the whole hollow (thinnest %.0f px)" % [kind, worst])
		var i := t.chunk_of(ux)
		var ground := PackedVector2Array()
		var gx := i * Terrain.CHUNK_W - 40.0
		while gx <= (i + 1) * Terrain.CHUNK_W + 40.0:
			ground.append(Vector2(gx, t.height_at(gx)))
			gx += 40.0
		ground.append(Vector2(gx, Chunk.DEPTH))
		ground.append(Vector2(i * Terrain.CHUNK_W - 40.0, Chunk.DEPTH))
		check(Geometry2D.clip_polygons(ground, Underground.cavity_world(kind, ux, t)).size() == 1, "%s: the ground stays one piece" % kind)

	# The root cellar: walk right over its door; S takes you down the steps.
	var door_x := Terrain.HOMESTEAD_X + 180.0
	await teleport(door_x + 400.0)
	await frames(20)
	var cellar := _under_place("cellar")
	check(cellar != null, "the homestead has a root cellar")
	check(await _walk(-1.0, func(): return player.global_position.x < door_x - 200.0), "walked across the cellar door")
	check(player.underground == null and absf(player.global_position.y - t.height_at(player.global_position.x)) < 20.0, "and stayed on top of it")
	await teleport(door_x)
	await frames(10)
	player.go_down()
	await frames(40)
	check(player.global_position.y > t.height_at(player.global_position.x) + 5.0, "S drops you through the door onto the steps")
	player.held = ItemStack.make("torch", GameClock.clock.hours)
	check(await _walk(-1.0, func(): return player.under > 0.9, 600), "down the steps into the cellar")
	check(player.underground == cellar and world.sheltered_at(player.global_position.x), "it's shelter")
	var atm: Atmosphere = get_tree().get_root().find_children("*", "Atmosphere", true, false)[0]
	await frames(4)
	check(atm.canvas_mod.color.get_luminance() < 0.2, "and dark at midday (%.2f)" % atm.canvas_mod.color.get_luminance())
	check(player._torch_light.visible and player._torch_light.energy > 0.7, "the torch lights it up")
	check(player.noise() == 0.0 and player.visibility() == 0.0, "nothing up top can hear or see you")
	player.cond.warmth = 50.0
	var shelves := _pick(cellar, "shelves")
	var before_beans := player.backpack.count_of("tinned_beans")
	await teleport_under(shelves.global_position.x, shelves.global_position.y)
	check(player.focus == shelves, "at the shelves")
	check(_run_option(shelves, "Search"), "search the shelves")
	await _finish_work()
	check(player.backpack.count_of("preserves") == 2 and player.backpack.count_of("tinned_beans") == before_beans + 2 and Journal.has("diary_1"), "preserves, beans and the diary")
	player.drop_stack(player.backpack.find(func(st): return st.def.id == "preserves"))
	await frames(4)
	var dropped: WorldItem = null
	for n in get_tree().get_nodes_in_group("persist"):
		if n is WorldItem and n.stack.def.id == "preserves":
			dropped = n
	check(dropped != null and dropped.global_position.y > t.height_at(dropped.global_position.x) + 100.0, "a dropped jar lands on the cellar floor, not up top")
	var saved := dropped.to_state() if dropped else {}
	check(saved.has("y"), "and it keeps its place down there when saved")
	if dropped:
		player.receive(dropped.stack)
		dropped.queue_free()
	check(await _walk(1.0, func(): return player.underground == null and player.global_position.x > door_x + 80.0, 900), "walked back up the steps and out")
	player.held = null

	# The cave: a fallen log over a sinkhole, a scree slope, a gallery, a rope down a shaft.
	var cave_x := Terrain.ECHO_CAVE_X
	await teleport(cave_x - 400.0)
	await frames(20)
	var cave := _under_place("cave")
	check(cave != null, "the foothills have a cave")
	check(await _walk(1.0, func(): return player.global_position.x > cave_x + 400.0), "walked over the log across the sinkhole")
	check(player.underground == null, "and didn't fall in")
	await teleport(cave_x + 100.0)
	player.held = ItemStack.make("torch", GameClock.clock.hours)
	player.go_down()
	await frames(30)
	check(await _walk(1.0, func(): return player.global_position.x > cave_x + 1375.0, 1200), "down the scree into the gallery")
	check(player.under > 0.9, "deep underground (%.2f)" % player.under)
	await frames(10)
	check(absf(player.global_position.y - (cave.global_position.y + 400.0)) < 20.0, "standing on the ledge over the shaft")
	player.go_down()
	check(player.climbing, "S at the ledge: down the rope")
	await _finish_work()
	check(player.global_position.y > cave.global_position.y + 800.0, "at the bottom of the shaft")
	var pool := _pick(cave, "pool")
	await teleport_under(pool.global_position.x, pool.global_position.y)
	player.hold(player.backpack.find(func(st): return st.def.id == "water_bottle"))
	player.held.water = 0.0
	check(_run_option(pool, "Fill"), "fill the bottle at the pool")
	check(player.held.water > 0.5 and player.held.water_clean, "cave water is clean")
	player.stow()
	var tin := _pick(cave, "tin")
	await teleport_under(tin.global_position.x, tin.global_position.y)
	_run_option(tin, "Open")
	await _finish_work()
	check(player.backpack.count_of("matches") >= 1, "an old tin of matches")
	var glyphs := _pick(cave, "glyphs")
	await teleport_under(glyphs.global_position.x, glyphs.global_position.y)
	_run_option(glyphs, "marks")
	check(Journal.has("glyphs"), "the paintings go in the journal")
	var flint: Node = null
	for c in cave.get_children():
		if c is Underground.Deposit:
			flint = c
			break
	await teleport_under(flint.global_position.x - 60.0, flint.global_position.y)
	player.facing = 1
	player.draw_slot(0) # the axe
	await frames(4)
	check(player.chop_target == flint, "the axe finds the flint")
	for k in 20:
		if not is_instance_valid(flint):
			break
		await swing()
	check(player.backpack.count_of("flint") >= 2, "broke out flint (%d)" % player.backpack.count_of("flint"))
	player.stow()
	var up := _pick(cave, "up_0")
	await teleport_under(up.global_position.x, up.global_position.y)
	check(_run_option(up, "Climb"), "climb the rope")
	await _finish_work()
	check(player.global_position.y < cave.global_position.y + 420.0, "back up in the gallery")
	check(await _walk(-1.0, func(): return player.underground == null and player.global_position.x < cave_x - 90.0, 1500), "up the scree and out into daylight")
	player.held = null

	# The mine: planks over a shaft under a headframe; the ladder down; a collapse to clear.
	await teleport(Terrain.MINE_X + 400.0)
	await frames(20)
	var mine := _under_place("mine")
	check(mine != null, "the Lucky Boy mine is in the canyon")
	check(await _walk(-1.0, func(): return player.global_position.x < Terrain.MINE_X - 200.0), "walked across the planks over the shaft")
	await teleport(Terrain.MINE_X + 20.0)
	await frames(6)
	var hatch := _pick(mine, "hatch")
	check(player.focus == hatch, "the shaft has a prompt (%s)" % (player.focus.interact_label(player) if player.focus else "none"))
	player.go_down()
	check(player.climbing, "down the ladder")
	await _finish_work()
	check(player.global_position.y > mine.global_position.y + 650.0, "at the bottom of the shaft")
	var block: Node = null
	for c in mine.get_children():
		if c is Underground.Block:
			block = c
	check(block != null, "the drift is blocked by a collapse")
	check(await _walk(1.0, func(): return player.global_position.x > Terrain.MINE_X + 900.0, 400) == false, "can't get past it")
	player.facing = 1
	player.draw_slot(0)
	await frames(4)
	for k in 20:
		if not is_instance_valid(block):
			break
		await swing()
	check(not is_instance_valid(block), "cleared the fallen timbers with the axe")
	player.stow()
	var cache := _pick(mine, "cache")
	check(await _walk(1.0, func(): return player.focus == cache, 900), "through to the miners' cache")
	_run_option(cache, "Search")
	await _finish_work()
	check(player.backpack.count_of("lantern") == 1 and player.backpack.count_of("lamp_oil") == 2 and Journal.has("mine_log"), "a lantern, lamp oil and the shift book")
	player.hold(player.backpack.find(func(st): return st.def.id == "lantern"))
	await frames(4)
	check(player._torch_light.visible, "the lantern lights the drift")
	var oil := player.held.condition
	GameClock.force_weather(Weather.Kind.RAIN)
	player._on_tick(3.0)
	check(player.held != null and player.held.def.id == "lantern" and absf(player.held.condition - (oil - 0.25)) < 0.01, "it burns its oil steadily, rain or not")
	GameClock.force_weather(Weather.Kind.CLEAR)
	player.stow()
	var ladder := _pick(mine, "up_0")
	await teleport_under(ladder.global_position.x, ladder.global_position.y)
	_run_option(ladder, "Climb")
	await _finish_work()
	check(player.underground == null and absf(player.global_position.y - t.height_at(player.global_position.x)) < 30.0, "up the ladder into daylight")

	# Flint lights a fire when the lighter's gone (it needs the knife); matches too.
	for s in player.backpack.all_stacks():
		if s.def.id in ["lighter", "matches"]:
			s.uses_left = 0
	var fire: Campfire = world.spawn({"kind": "campfire", "x": player.global_position.x + 60.0, "fuel": 2.0, "lit": false})
	await frames(4)
	var lit_opt := Player.choices_of(fire, player).filter(func(o): return "flint" in o[0])
	check(lit_opt.size() == 1, "the fire offers the flint")
	if lit_opt:
		lit_opt[0][1].call()
		await _finish_work()
	check(fire.lit, "sparks from the flint catch")
	fire.queue_free()

	# Juniper Spring: clean water in the dry country.
	var si := -1
	for k in Terrain.WATERS.size():
		if Terrain.WATERS[k].get("clean", false):
			si = k
	await teleport(Terrain.WATERS[si].x - 60.0)
	await frames(10)
	var spring := Creek.reachable(player)
	player.hold(player.backpack.find(func(st): return st.def.id == "water_bottle"))
	player.held.water = 0.0
	spring.interact(player)
	check(player.held.water > 0.5 and player.held.water_clean, "spring water is clean")
	player.stow()

	# New plants where they belong; things to come across everywhere.
	var kinds := {}
	for cx in [-40000.0, -34000.0, -28000.0, 80000.0, 86000.0, 92000.0]:
		await teleport(cx)
		await frames(10)
		for p in get_tree().get_nodes_in_group("plant"):
			kinds[p.species] = true
	for sp in ["prickly_pear", "yucca", "chanterelle", "fly_agaric"]:
		check(kinds.has(sp), "%s grows out there" % sp)
	var finds := get_tree().get_root().find_children("*", "Find", true, false)
	check(finds.size() > 0, "things to come across (%d here)" % finds.size())
	var fly := ItemStack.make("fly_agaric", GameClock.clock.hours)
	player.held = fly
	var hp := player.cond.health
	player.use_held()
	check(player.cond.health < hp - 10.0, "fly agaric is poison")
	player.held = null
	player.cond.health = 100.0
	player.cond.incubating = 0.0
	var searched := 0
	for k in 12:
		await teleport(Terrain.WORLD_MIN + 3000.0 + k * 11000.0)
		await frames(6)
		for f in get_tree().get_root().find_children("*", "Find", true, false):
			if f.interact_label(player) != "" and f.kind in ["bottle", "wagon", "fire_ring", "hollow_log"] and not f.found():
				f.interact(player)
				check(f.found() and f.interact_label(player) == "", "searched %s once" % f.kind)
				searched += 1
				break
		if searched >= 2:
			break
	check(searched >= 1, "found something to search")

	# The falls.
	await teleport(Terrain.FALLS_X - 500.0)
	await frames(10)
	check(get_tree().get_root().find_children("*", "Waterfall", true, false).size() == 1, "the falls pour into their pool")

	# Regrowth: a tree comes back from its stump in about three seasons; berries in a season
	# of growing weather (winter doesn't count).
	var season := GameClock.clock.season_hours()
	GameClock.clock.hours = 24.0 * 3.0 # early autumn
	await teleport(3000.0)
	await frames(10)
	var tree: ChoppableTree = null
	for n in get_tree().get_nodes_in_group("choppable"):
		if n is ChoppableTree and absf(n.global_position.x - player.global_position.x) < 1500.0:
			tree = n
			break
	await teleport(tree.global_position.x - 70.0)
	player.facing = 1
	player.draw_slot(0)
	await frames(4)
	for k in 40:
		if tree.felled:
			break
		await swing()
	await frames(140)
	check(tree.felled and tree.felled_at >= 0.0 and not tree.art.visible, "felled: just a stump")
	GameClock.clock.hours += season * 1.5
	tree._grow_check = 0.0
	await frames(3)
	check(tree.art.visible and tree.art.scale.x < 0.9 and tree.felled, "a season and a half on: a sapling (%.2f)" % tree.art.scale.x)
	GameClock.clock.hours += season * 1.6
	tree._grow_check = 0.0
	await frames(3)
	check(not tree.felled and tree.is_in_group("choppable") and not world.chunk_state(tree.chunk.index).felled.has(str(tree.n)), "three seasons on: a full tree again")
	player.stow()
	var clock := GameClock.clock
	clock.hours = 24.0 * 3.0 # early autumn
	var picked := clock.hours
	clock.hours += season * 0.8
	check(clock.growing_hours(picked) < season, "not a season yet")
	clock.hours = picked + season * 2.2 # through autumn and winter to spring
	check(clock.growing_hours(picked) < season * 1.3 and clock.growing_hours(picked) > season * 1.1, "winter doesn't count toward growing (%.2f seasons)" % (clock.growing_hours(picked) / season))
	check(clock.growing_hours(-INF) == INF, "never picked is always ready")

	# Maps from the last world (one size smaller) pad out to this one.
	var old := PackedByteArray()
	old.resize(int((Terrain.OLD_MAX - Terrain.OLD_MIN) / World.MAP_CELL))
	old.fill(0)
	old[world._cell(Terrain.CREEK_X) - world._cell(Terrain.OLD_MIN)] = 1
	var keep := world.explored
	world.set_explored(old)
	check(world.explored.size() == World.MAP_CELLS and world.seen(Terrain.CREEK_X), "an older map lines up with the bigger world")
	world.explored = keep

	print("scenario failures: ", failures)
	get_tree().quit(failures)

## Puts the player on the floor down in a hollow at x (teleport only knows the ground up top).
func teleport_under(x: float, near_y := NAN) -> void:
	var y := world.floor_y(x, (player.global_position.y if is_nan(near_y) else near_y) - 60.0)
	player.global_position = Vector2(x, y - 4.0)
	player.velocity = Vector2.ZERO
	await frames(8)
