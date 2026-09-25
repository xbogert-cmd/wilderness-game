extends Node2D
## Composes the slice. Command-line hooks (after `--`) for automated checks:
##   --hour=H  --weather=clear|overcast|drizzle|rain  --x=WORLD_X
##   --shot=path.png   capture after settling, then quit
##   --tour            teleport across every chunk, verify streaming, then quit
##   --load=SLOT       start from a save slot (1, 2, 3, auto)
##   --scenario[=life] scripted end-to-end checks (see game/debug/scenario.gd)

const START_X := 2600.0
const AUTOSAVE_SECONDS := 300.0

var hud: Hud
var _autosave_t := 0.0

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
	world.update_focus(x)
	player.died.connect(_on_player_died)
	player.made_camp.connect(func(): save_to("auto"))

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
	var dbg := DebugOverlay.new()
	dbg.player = player
	dbg.world = world
	ui.add_child(dbg)

	if args.has("hour") and not save:
		GameClock.clock.hours = float(args.hour)
	if args.has("weather"):
		GameClock.force_weather(Weather.NAMES.find(args.weather))
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
	if args.has("deer"): # preview: a small group ahead of the player
		for k in 3:
			var a := wildlife.spawn(Wildlife.SPECIES[0], x + 420.0 + k * 170.0, k)
			a.state = [Animal.State.GRAZE, Animal.State.ALERT, Animal.State.WALK][k]
			a.facing = -1 if k == 1 else 1
			a.def = a.def.duplicate()
			a.def.hearing = 0.0 # hold the pose for the screenshot
			a.def.sight = 0.0
	if args.has("fish"): # preview: mid-fight with a trout at the creek bank
		_preview_fish.call_deferred(fishing)
	if args.has("flee"): # preview: a deer bounding away
		var d := wildlife.spawn(Wildlife.SPECIES[0], x + 700.0, 3)
		d.bolt()
	if args.has("sleep"): # preview: asleep under a lean-to
		world.spawn({"kind": "lean_to", "x": x})
		player.sleep.call_deferred()
	if args.has("menu"):
		pause.toggle.call_deferred()
	if args.has("pack"):
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

func _process(delta: float) -> void:
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
		"player": player.to_dict(), "world": world.snapshot(), "tracks": world.tracks.to_array()}

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
	print("saved ", path, "  fps ", frames / 2.0)
	get_tree().quit()

## Walks the chunk streamer across the whole world and back; exit code 1 on any mismatch.
func _tour() -> void:
	var failures := 0
	var xs := []
	for i in Terrain.CHUNKS:
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
			if i >= 0 and i < Terrain.CHUNKS:
				want.append(i)
		var have: Array = world.chunks.keys()
		have.sort()
		var fell: bool = player.global_position.y > world.terrain.height_at(player.global_position.x) + 20.0
		print("x=%d chunk=%d loaded=%s fell=%s" % [x, c, have, fell])
		if have != want or fell:
			failures += 1
	print("tour failures: ", failures)
	get_tree().quit(failures)
