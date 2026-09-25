extends Node2D
## Composes the slice. Command-line hooks (after `--`) for automated checks:
##   --hour=H  --weather=clear|overcast|drizzle|rain  --x=WORLD_X
##   --shot=path.png   capture after settling, then quit
##   --tour            teleport across every chunk, verify streaming, then quit

const START_X := 2600.0

var world: World
var player: Player
var camera: FollowCamera
var backdrop: Backdrop

func _ready() -> void:
	var args := _args()

	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	var sky := ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://game/world/sky.gdshader")
	sky.material = sky_mat
	sky_layer.add_child(sky)
	add_child(sky_layer)

	world = World.new()
	add_child(world)
	player = Player.new()
	player.world = world
	player.z_index = 5
	var x := float(args.get("x", START_X))
	player.position = Vector2(x, world.terrain.height_at(x) - 4.0)
	add_child(player)
	world.update_focus(x)

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

	var ambience := Ambience.new()
	ambience.player = player
	ambience.terrain = world.terrain
	add_child(ambience)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var hud := Hud.new()
	hud.player = player
	ui.add_child(hud)
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

	if args.has("hour"):
		GameClock.clock.hours = float(args.hour)
	if args.has("weather"):
		GameClock.force_weather(Weather.NAMES.find(args.weather))
	if args.has("walk"):
		player.auto_dir = float(args.walk)
	if args.has("run"):
		player.auto_run = true
	if args.has("zoom"):
		camera.zoom_override = float(args.zoom)
	if args.has("pack"):
		pack_ui.toggle.call_deferred()
	if args.has("debug"):
		dbg.visible = true
	if args.has("scenario"):
		var sc := Scenario.new()
		sc.player = player
		sc.world = world
		sc.shot = args.get("shot", "")
		add_child(sc)
	elif args.has("tour"):
		_tour()
	elif args.has("shot"):
		_shot(args.shot)

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
