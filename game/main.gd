extends Node2D
## Composes the slice. Command-line hooks (after `--`) for automated checks:
##   --hour=H  --day=D  --weather=clear|overcast|drizzle|rain  --snow=CM  --ice=0..1  --x=WORLD_X
##   --shot=path.png   capture after settling, then quit
##   --tour            teleport across every chunk, verify streaming, then quit
##   --load=SLOT       start from a save slot (1, 2, 3, auto)
##   --scenario[=life] scripted end-to-end checks (see game/debug/scenario.gd)
##   previews: --wolves[=torch] --bear[=0|1|2] --wear[=buckskin] (and many more below)

const START_X := 2600.0
const AUTOSAVE_SECONDS := 300.0

var hud: Hud
var tips: Tips
var _autosave_t := 0.0
var _season := -1
const SEASON_NOTES := [
	"Spring. Meltwater in the creek, and the aspens are budding.",
	"Summer. Long days in the valley.",
	"Autumn. The aspens are turning, and the nights are getting cold.",
	"Winter has come to the valley. Keep the fire fed and your water from freezing.",
]

var world: World
var player: Player
var camera: FollowCamera
var backdrop: Backdrop

func _ready() -> void:
	var args := _args()
	if args.has("load"):
		SaveGame.pending = SaveGame.read(args.load)
	var save := SaveGame.pending
	SaveGame.pending = {}
	if save:
		GameClock.clock.from_dict(save.clock)
		GameClock.weather.from_dict(save.weather)
		GameClock.time_scale = 1.0

	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	var sky := ColorRect.new()
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE # a full-screen Control would eat every click
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://game/world/sky.gdshader")
	sky.material = sky_mat
	sky_layer.add_child(sky)
	add_child(sky_layer)

	world = World.new()
	add_child(world)
	if save:
		world.restore(save.world)
	player = Player.new()
	player.world = world
	player.z_index = 5
	player.start_x = START_X
	var x := float(args.get("x", START_X))
	player.position = Vector2(x, world.terrain.height_at(x) - 4.0)
	add_child(player)
	if save:
		player.from_dict(save.player)
		x = player.global_position.x
	var sign := TrailSign.new()
	sign.position = Vector2(START_X - 180.0, world.terrain.height_at(START_X - 180.0))
	world.add_child(sign)
	world.update_focus(x)
	player.died.connect(_on_player_died)
	player.made_camp.connect(func():
		Journal.note("camp", "Made camp. A roof to sleep under and somewhere to come back to.")
		save_to("auto"))

	camera = FollowCamera.new()
	camera.target = player
	camera.position = player.position + Vector2(0, -FollowCamera.HEIGHT)
	add_child(camera)
	var rain := Rain.new()
	camera.add_child(rain)

	backdrop = Backdrop.new()
	add_child(backdrop)
	backdrop.build(world.terrain, camera, player)

	var canvas_mod := CanvasModulate.new()
	add_child(canvas_mod)
	var atmo := Atmosphere.new()
	atmo.sky = sky_mat
	atmo.canvas_mod = canvas_mod
	atmo.backdrop = backdrop
	atmo.rain = rain
	add_child(atmo)

	var fishing := Fishing.new()
	fishing.player = player
	fishing.world = world
	add_child(fishing)
	player.fishing = fishing

	var wildlife := Wildlife.new()
	wildlife.world = world
	wildlife.player = player
	wildlife.tracks = world.tracks
	add_child(wildlife)
	if save and save.has("tracks"):
		world.tracks.from_array(save.tracks)

	var ambience := Ambience.new()
	ambience.player = player
	ambience.terrain = world.terrain
	add_child(ambience)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	hud = Hud.new()
	hud.player = player
	ui.add_child(hud)
	Journal.current = Journal.new()
	if save and save.has("journal"):
		Journal.current.from_dict(save.journal)
	if save and save.has("explored"):
		world.set_explored(PackedByteArray(save.explored))
	Journal.current.written.connect(func(t: String): player.message.emit("Journal: \"%s…\"  (%s)" % [t.left(48).strip_edges(), Keys.label("map")]))
	Journal.note("start", "Day one. Came in on the Rattlesnake Creek trail with a pack, a hatchet and a knife. The valley's quiet. The old fire lookout stands on the east ridge; the sign says a mile to the creek.")
	tips = Tips.new()
	tips.player = player
	tips.hud = hud
	if save and save.has("tips"):
		for k in save.tips:
			tips.seen[k] = true
	add_child(tips)
	var fish_ui := FishingUI.new()
	fish_ui.fishing = fishing
	ui.add_child(fish_ui)
	var pause := PauseMenu.new()
	pause.player = player
	pause.main = self
	ui.add_child(pause) # before the pack UI so the pack gets Esc first while open
	var build_menu := VBoxContainer.new()
	build_menu.position = Vector2(60, 120)
	ui.add_child(build_menu)
	var build := BuildMode.new()
	build.player = player
	build.world = world
	build.menu = build_menu
	add_child(build)
	var pack_ui := BackpackUI.new()
	pack_ui.player = player
	ui.add_child(pack_ui)
	var map_ui := MapUI.new()
	map_ui.player = player
	map_ui.world = world
	ui.add_child(map_ui) # after the pause menu so Esc closes the map first
	var dbg := DebugOverlay.new()
	dbg.player = player
	dbg.world = world
	ui.add_child(dbg)

	if args.has("hour") and not save:
		GameClock.clock.hours = float(args.hour)
	if args.has("day") and not save:
		GameClock.clock.hours += 24.0 * float(args.day)
	if args.has("weather"):
		GameClock.force_weather(Weather.NAMES.find(args.weather))
	if args.has("snow"):
		GameClock.weather.snow_cm = float(args.snow)
	if args.has("ice"):
		GameClock.weather.ice = float(args.ice)
	if args.has("walk"):
		player.auto_dir = float(args.walk)
	if args.has("run"):
		player.auto_run = true
	if args.has("zoom"):
		camera.zoom_override = float(args.zoom)
	if args.has("camp"): # preview a finished camp next to the player
		world.spawn({"kind": "lean_to", "x": x + 260.0})
		world.spawn({"kind": "campfire", "x": x + 520.0, "fuel": 6.0, "lit": true})
		world.spawn({"kind": "log", "size": "medium", "x": x - 160.0, "y": world.terrain.height_at(x - 160.0) - 30.0})
		world.spawn({"kind": "log", "size": "short", "x": x + 620.0, "y": world.terrain.height_at(x + 620.0) - 30.0})
		player.draw_slot(0)
	if args.has("builds"): # preview: a built-up camp
		world.spawn({"kind": "cabin", "x": x - 520.0})
		world.spawn({"kind": "campfire", "x": x + 150.0, "fuel": 6.0, "lit": true, "tripod": true,
			"pot": ItemStack.make("cook_pot", GameClock.clock.hours).to_dict()})
		world.spawn({"kind": "woodpile", "x": x + 360.0, "logs": 9})
		world.spawn({"kind": "hide_frame", "x": x + 560.0, "curing": true, "cured": 7.0})
		world.spawn({"kind": "drying_rack", "x": x + 780.0, "pieces": [0.0, 2.0, 5.0, 7.0, 9.0, 12.0]})
		world.spawn({"kind": "workbench", "x": x - 170.0})
		world.spawn({"kind": "chest", "x": x - 20.0})
	if args.has("carry"): # preview: carrying a short or medium log
		var lg := world.spawn({"kind": "log", "size": args.carry, "x": x, "y": world.terrain.height_at(x) - 30.0}) as WorldLog
		player.carrying = lg
		lg.pick_up(player)
	if args.has("notch"): # preview: a tree half chopped through, hatchet in hand
		player.draw_slot(0)
		_preview_notch.call_deferred()
	if args.has("blind"): # preview: crouched in a hunting blind, bow ready, a deer passing
		world.spawn({"kind": "blind", "x": x})
		player.auto_crouch = true
		player.hold(ItemStack.make("bow", GameClock.clock.hours))
		var d := wildlife.spawn(Wildlife.SPECIES[0], x + 420.0, 4)
		d.state = Animal.State.WALK
		d.facing = -1
	if args.has("chest"): # preview: a chest open beside the pack
		var chest := world.spawn({"kind": "chest", "x": x + 60.0}) as StorageChest
		for id in ["jerky", "venison_cooked", "hide", "whetstone", "arrows"]:
			chest.store.add(ItemStack.make(id, GameClock.clock.hours, 4 if id in ["jerky", "arrows"] else 1))
		chest.interact.call_deferred(player)
	if args.has("bait"): # preview: a bait pile on a game trail, a deer coming to it
		var t := Wildlife.trail(world.terrain.chunk_of(x))
		var bx := lerpf(t.x, t.y, 0.5)
		player.global_position.x = bx - 260.0
		world.spawn({"kind": "bait", "x": bx, "laid": GameClock.clock.hours})
		world.spawn({"kind": "blind", "x": bx - 260.0})
		player.auto_crouch = true
		GameClock.weather.wind_dir = -1 # into the wind, or it would smell us
		var d := wildlife.spawn(Wildlife.SPECIES[0], bx + 380.0, 6)
		d.state = Animal.State.WALK
		d.facing = -1
	if args.has("piles"): # preview: woodpiles with 1, 3, 6, 7, 10 and 15 logs
		for k in 6:
			world.spawn({"kind": "woodpile", "x": x - 700.0 + k * 250.0, "logs": [1, 3, 6, 7, 10, 15][k]})
	if args.has("deer"): # preview: a small group ahead of the player
		for k in 3:
			var a := wildlife.spawn(Wildlife.SPECIES[0], x + 420.0 + k * 170.0, k)
			a.state = [Animal.State.GRAZE, Animal.State.ALERT, Animal.State.WALK][k]
			a.facing = -1 if k == 1 else 1
			a.def = a.def.duplicate()
			a.def.hearing = 0.0 # hold the pose for the screenshot
			a.def.sight = 0.0
	if args.has("hunt"): # preview: bow at full draw on a grazing deer, a carcass behind, blood drops
		var a := wildlife.spawn(Wildlife.SPECIES[0], x + 800.0, 1)
		a.def = a.def.duplicate()
		a.def.hearing = 0.0
		a.def.sight = 0.0
		world.spawn({"kind": "carcass", "x": x - 380.0, "facing": -1, "species": "mule_deer", "hour": GameClock.clock.hours, "arrows": 1})
		for k in 6:
			world.tracks.add(x - 300.0 + k * 45.0, "blood", 1)
		player.receive(ItemStack.make("arrows", GameClock.clock.hours, 6))
		player.hold(ItemStack.make("bow", GameClock.clock.hours))
		player.aim_override = Vector2(x + 830.0, world.terrain.height_at(x + 800.0) - 150.0)
		player.bow_draw = 0.0
	if args.has("wolves"): # preview: a pack at a carcass, ravens overhead, you with a torch
		world.spawn({"kind": "carcass", "x": x + 520.0, "facing": -1, "species": "mule_deer", "hour": GameClock.clock.hours - 2.0})
		for k in 3:
			var w := wildlife.spawn_predator(Wildlife.WOLF, x + 420.0 + k * 130.0, k)
			w.state = [Predator.State.FEED, Predator.State.STALK, Predator.State.ROAM][k]
			w.facing = -1 if k != 0 else 1
			w.set_physics_process(false)
			w.position.y = world.ground_y(w.position.x)
		if args.wolves == "torch":
			player.hold(ItemStack.make("torch", GameClock.clock.hours))
	if args.has("bear"): # preview: the bear, and what it leaves behind
		var b := wildlife.spawn_predator(Wildlife.BEAR, x + 520.0, 1)
		b.state = [Predator.State.ROAM, Predator.State.BLUFF, Predator.State.FEED][int(args.bear) if args.bear != "" else 0]
		b.facing = -1
		b.speed = 0.0
		b.set_physics_process(false)
		b.position.y = world.ground_y(b.position.x)
		world.spawn({"kind": "carcass", "x": x - 420.0, "facing": 1, "species": "wolf", "hour": GameClock.clock.hours})
		world.spawn({"kind": "gut_pile", "x": x - 700.0, "hour": GameClock.clock.hours - 1.0})
		world.spawn({"kind": "snare", "x": x + 180.0, "caught": true})
		player.hold(ItemStack.make("spear", GameClock.clock.hours))
	if args.has("attack"): # preview: a wolf (or the bear, --attack=bear) mid-strike, you flinching
		var bear: bool = args.attack == "bear"
		var a := wildlife.spawn_predator(Wildlife.BEAR if bear else Wildlife.WOLF, x + (125.0 if bear else 80.0), 2)
		a.state = Predator.State.LUNGE
		a.strike_t = 0.2 if bear else 0.3
		a.facing = -1
		a.set_physics_process(false)
		a.position.y = world.ground_y(a.position.x)
		player.facing = 1
		player.hurt_t = 10.0
	if args.has("climb"): # preview: partway up the lookout ladder
		var lk_x := Terrain.LOOKOUT_X + Lookout.LADDER_X
		player.global_position = Vector2(lk_x, world.terrain.summit_y - 4.0)
		_climb_lookout.call_deferred()
	if args.has("choices"): # preview: E pressed at a lit fire, its list of choices open
		world.spawn({"kind": "campfire", "x": x + 50.0, "fuel": 6.0, "lit": true, "tripod": true})
		player.backpack.add(ItemStack.make("sticks", GameClock.clock.hours, 3))
		_open_choices.call_deferred()
	if args.has("wear"): # preview: dressed in winter furs (or buckskin)
		for id in (["hide_coat", "buckskin_leggings"] if args.wear == "buckskin" else ["bear_coat", "wolf_hat", "wolf_mittens", "wolf_leggings"]):
			var st := ItemStack.make(id, GameClock.clock.hours)
			player.backpack.add(st)
			player.backpack.wear(st)
		for id in ["wolf_fur", "bear_hide", "hide_coat", "rabbit_raw", "snare"]:
			player.backpack.add(ItemStack.make(id, GameClock.clock.hours))
	if args.has("fish"): # preview: mid-fight with a trout at the creek bank
		_preview_fish.call_deferred(fishing)
	if args.has("flee"): # preview: a deer bounding away
		var d := wildlife.spawn(Wildlife.SPECIES[0], x + 700.0, 3)
		d.bolt()
	if args.has("trunk"): # preview: a freshly felled tree beside the player, hatchet out
		world.spawn({"kind": "trunk", "x": x + 60.0, "dir": 1.0, "length": 1100.0, "girth": 38.0, "branches": 4, "conifer": true})
		player.draw_slot(0)
	if args.has("sleep"): # preview: asleep under a lean-to
		world.spawn({"kind": "lean_to", "x": x})
		player.sleep.call_deferred()
	if args.has("buildmenu"): # preview: the build menu open
		build._refresh_menu.call_deferred()
		build_menu.visible = true
	if args.has("menu"):
		pause.toggle.call_deferred()
	if args.has("top"): # preview: up on the lookout catwalk
		player.global_position = Vector2(Terrain.LOOKOUT_X - 40.0, world.terrain.summit_y + Lookout.FLOOR - 6.0)
	if args.has("reveal"): # preview: the whole map explored
		world.reveal_all()
	if args.has("map"): # preview: the map and journal
		map_ui.toggle.call_deferred()
	if args.has("pack"):
		if args.pack == "all": # preview: one of every item, to check the icons
			for id in ["trout_raw", "whitefish_cooked", "berries", "splint", "fishing_pole", "fishing_kit", "sticks", "trout_cooked", "bandage"]:
				var st := ItemStack.make(id, GameClock.clock.hours, 3 if id in ["sticks", "berries"] else 1)
				player.backpack.add(st)
		pack_ui.toggle.call_deferred()
	if args.has("debug"):
		dbg.visible = true
	if args.has("scenario"):
		var sc := Scenario.new()
		sc.player = player
		sc.world = world
		sc.shot = args.get("shot", "")
		sc.mode = args.scenario if args.scenario != "" else "camp"
		add_child(sc)
	elif args.has("tour"):
		_tour()
	elif args.has("shot"):
		_shot(args.shot)

func _climb_lookout() -> void:
	for i in 60: # partway up by the time the shot is taken
		await get_tree().physics_frame
	for n in get_tree().get_nodes_in_group("landmark"):
		if n is Lookout:
			n.interact(player)

func _open_choices() -> void:
	for i in 10:
		await get_tree().physics_frame
	player.open_or_interact()

func _preview_notch() -> void:
	var best: ChoppableTree = null
	for t in get_tree().get_nodes_in_group("choppable"):
		if t is ChoppableTree and (best == null or absf(t.global_position.x - player.global_position.x) < absf(best.global_position.x - player.global_position.x)):
			best = t
	player.global_position.x = best.global_position.x - 70.0
	player.facing = 1
	for i in 6:
		best.hit(player, 0.9, Vector2.ZERO)

func _process(delta: float) -> void:
	if GameClock.weather.snow_cm > 2.0:
		Journal.note("first_snow", "First snow lying in the valley. Every track shows now, mine included, and the creek will freeze if the cold holds.")
	var season := GameClock.clock.season()
	if season != _season:
		if _season != -1:
			player.message.emit(SEASON_NOTES[season])
			Journal.note("season_%d_%d" % [season, GameClock.clock.day()], SEASON_NOTES[season])
		_season = season
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_SECONDS and player.unsafe_reason() == "":
		_autosave_t = 0.0
		save_to("auto")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quicksave"):
		var why := player.unsafe_reason()
		if why != "":
			player.message.emit("Can't save: " + why)
		elif save_to("1") == OK:
			player.message.emit("Saved to slot 1.")

func snapshot() -> Dictionary:
	return {"clock": GameClock.clock.to_dict(), "weather": GameClock.weather.to_dict(),
		"player": player.to_dict(), "world": world.snapshot(), "tracks": world.tracks.to_array(),
		"tips": tips.seen.keys(), "journal": Journal.current.to_dict(), "explored": Array(world.explored)}

func save_to(slot: String) -> Error:
	var err := SaveGame.write(slot, snapshot())
	if err != OK:
		push_error("save to slot %s failed: %s" % [slot, error_string(err)])
	return err

func load_from(slot: String) -> void:
	var d := SaveGame.read(slot)
	if d.is_empty():
		player.message.emit("That save can't be loaded.")
		return
	SaveGame.pending = d
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_player_died() -> void:
	await hud.fade_to(1.0, 1.6).finished
	await get_tree().create_timer(1.0).timeout
	player.respawn()
	camera.reset_smoothing()
	hud.fade_to(0.0, 2.2)

func _preview_fish(fishing: Fishing) -> void:
	player.receive(ItemStack.make("fishing_pole"))
	player.hold(player.backpack.find(func(s): return s.def.has("rod")))
	player.facing = 1
	player.global_position = Vector2(Terrain.CREEK_X - Terrain.CREEK_HALF - 30.0, world.terrain.height_at(Terrain.CREEK_X - Terrain.CREEK_HALF - 30.0) - 4.0)
	world.update_focus(player.global_position.x)
	player.aim_override = Vector2(Terrain.CREEK_X, 0)
	fishing.press()
	await get_tree().create_timer(0.8).timeout
	fishing.force_bite("trout")
	await get_tree().create_timer(0.1).timeout
	fishing.press()
	fishing.fight.progress = 0.5

func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		out[kv[0]] = kv[1] if kv.size() > 1 else ""
	return out

func _shot(path: String) -> void:
	camera.reset_smoothing()
	for i in 90:
		await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while Time.get_ticks_msec() - t0 < 2000:
		await get_tree().process_frame
		frames += 1
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path, "  fps ", frames / 2.0, "  frame cpu %.2f ms  draw calls %d  nodes %d  objects %d" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT)])
	get_tree().quit()

## Walks the chunk streamer across the whole world and back; exit code 1 on any mismatch.
func _tour() -> void:
	var failures := 0
	var xs := []
	for i in range(Terrain.FIRST, Terrain.LAST + 1):
		xs.append((i + 0.5) * Terrain.CHUNK_W)
	var back := xs.duplicate()
	back.reverse()
	xs.append_array(back)
	for x in xs:
		player.global_position = Vector2(x, world.terrain.height_at(x) - 4.0)
		for f in 20:
			await get_tree().physics_frame
		var c := world.terrain.chunk_of(player.global_position.x)
		var want := []
		for i in range(c - 1, c + 2):
			if i >= Terrain.FIRST and i <= Terrain.LAST:
				want.append(i)
		var have: Array = world.chunks.keys()
		have.sort()
		var fell: bool = player.global_position.y > world.terrain.height_at(player.global_position.x) + 20.0
		print("x=%d chunk=%d loaded=%s fell=%s" % [x, c, have, fell])
		if have != want or fell:
			failures += 1
	print("tour failures: ", failures)
	get_tree().quit(failures)
