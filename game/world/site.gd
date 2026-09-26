class_name Site extends Node2D
## Places people left behind, each with things to search and pages for the journal:
## the old homestead in the western meadow (a grave, and its root cellar: see Underground),
## the trapper's camp on the Sweetwater (a cache, a carving), and the bush plane down in the
## burn past the lookout (cockpit, cargo, and footprints walking away east). The wreck is shelter to sleep in.
## Everything found is kept in the chunk's state, so each spot is searched once.

const PLACES := {Terrain.HOMESTEAD_X: "homestead", Terrain.TRAPPER_X: "trapper", Terrain.CRASH_X: "crash"}
const HALF := {"homestead": 520.0, "trapper": 320.0, "crash": 560.0}

var world: World
var chunk_index := 0
var kind := "homestead"
var _front: Node2D

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("camp") # key popup with the choices
	add_to_group("landmark")
	if kind == "crash":
		add_to_group("shelter")
	z_as_relative = false
	z_index = -5
	_front = Node2D.new()
	_front.z_as_relative = false
	_front.z_index = 8
	_front.draw.connect(_draw_front)
	add_child(_front)

func _process(_delta: float) -> void:
	if kind == "crash":
		_front.queue_redraw()
	var p: Player = get_tree().get_first_node_in_group("player")
	if p and absf(p.global_position.x - global_position.x) < HALF[kind]:
		match kind:
			"homestead": Journal.note("homestead", "An old homestead in the west meadow: a stone chimney still standing, the cabin fallen in around it, a split-rail fence gone grey. Someone tried to make a life out here.")
			"trapper": Journal.note("trapper", "A trapper's camp on the Sweetwater, long abandoned: a fallen lean-to, stretching hoops, a fire ring grown over.")
			"crash": Journal.note("crash", "A bush plane, down in the burn east of the lookout. Wing torn off, the fuselage on its side. It hasn't been here long.")

func _found(spot: String) -> bool:
	return world.chunk_state(chunk_index).get("site_%s_%s" % [kind, spot], false)

func _mark(spot: String) -> void:
	world.chunk_state(chunk_index)["site_%s_%s" % [kind, spot]] = true
	queue_redraw()
	_front.queue_redraw()

func covers(x: float) -> bool: # the wreck's fuselage keeps the weather off
	return kind == "crash" and absf(x - (global_position.x - 40.0)) < 150.0

func interact_pos() -> Vector2:
	if kind == "homestead": # only the grave is left to read here (the cellar door has its own prompt)
		return global_position + Vector2(-400, 0)
	var p: Player = get_tree().get_first_node_in_group("player")
	var h: float = HALF[kind] - 60.0
	return Vector2(clampf(p.global_position.x, global_position.x - h, global_position.x + h), global_position.y)

func interact_title(_p: Player) -> String:
	return {"homestead": "The old homestead", "trapper": "The trapper's camp", "crash": "The plane wreck"}[kind]

func interact_options(p: Player) -> Array:
	var out := []
	match kind:
		"homestead": # (the root cellar is under the cabin: go down through its door)
			out.append(["Read the grave marker", _read.bind(p, "grave")])
		"trapper":
			if not _found("cache"):
				out.append(["Open the trapper's cache", _search.bind(p, "cache")])
			if not _found("auger"):
				out.append(["Take the ice auger leaning on the post", _take_auger.bind(p)])
			out.append(["Look at the carving on the post", _read.bind(p, "carving")])
		"crash":
			if not _found("cockpit"):
				out.append(["Search the cockpit", _search.bind(p, "cockpit")])
			if not _found("cargo"):
				out.append(["Search the cargo", _search.bind(p, "cargo")])
			out.append(["Look at the footprints", _read.bind(p, "prints")])
	return out

func interact_label(p: Player) -> String:
	return Player.first_label(interact_options(p))

func interact(p: Player) -> void:
	Player.run_first(interact_options(p))

func _take_auger(p: Player) -> void:
	_mark("auger")
	_give(p, [["ice_auger", 1]])
	p.message.emit("A hand ice auger, rusty but sound. The trapper fished through the ice all winter.")
	Journal.note("auger", "Found the trapper's ice auger. It bores a hole through the ice in a moment, and the hole stays open for most of a day.")

func _give(p: Player, items: Array) -> void:
	var h := GameClock.clock.hours
	for it in items:
		var s := ItemStack.make(it[0], h, it[1])
		if not p.receive(s, false):
			world.spawn({"kind": "item", "x": p.global_position.x + 40.0, "stack": s.to_dict()})

func _search(p: Player, spot: String) -> void:
	p.work(3.0, 0.3, "Searching", func():
		_mark(spot)
		match spot:
			"cache":
				_give(p, [["snare", 3], ["arrows", 4], ["jerky", 2]])
				p.message.emit("A tin trunk wired shut against the animals: snares, arrows, jerky, and a notebook.")
				Journal.note("trapper_note", "Trapper's notebook: \"Third winter on the Sweetwater. Wolves thick this year. The compass won't settle anywhere past the burn, swings like it's drunk. Saw the lights again from the river, low over the east basin. Not going up there. Not for any money.\"")
			"cockpit":
				_give(p, [["flare", 2], ["bandage", 3]])
				p.message.emit("The pilot's seat is empty and dark with old blood. A flare kit, a first-aid box, and the flight log.")
				Journal.note("pilot_log", "The pilot's log: \"Oct 18. N4471K, cargo for the survey camp. Weather closing on the ridge. 23:40, every instrument dead at once, radio too. Lights off the nose, pacing us. Not aircraft. Going down in the burn.\" The same night the lookout keeper saw the lights.")
			"cargo":
				_give(p, [["sealed_case", 1], ["tinned_beans", 3]])
				world.explore_range(Terrain.LOOKOUT_X, 74000.0)
				p.message.emit("Crates of tins, a survey map of the basin, and one steel case, sealed. There's a gap where a second case was lashed.")
				Journal.note("survivor_note", "A note tucked under the cargo straps: \"If anyone finds this: Dale didn't make it. I'm taking the other case east to the survey camp like we were paid to. The lights came down to the treeline after we crashed and just... waited. Don't open the case. — M.\"")
				Journal.note("case", "The sealed case is stencilled U.S. GEOLOGICAL SURVEY. Locked tight, and oddly warm to the touch, even in the cold.")
		)

func _read(p: Player, spot: String) -> void:
	match spot:
		"grave":
			p.message.emit("A weathered board: ELIAS MORROW, 1868 - 1921. Underneath, carved deeper: WENT UP THE RIDGE.")
			Journal.note("grave", "A grave by the homestead: Elias Morrow, 1868 to 1921. \"Went up the ridge.\" The diary's Pa.")
		"carving":
			p.message.emit("Knife-cut into the post: J.T. 1974. And below it: DON'T FOLLOW THE LIGHTS.")
			Journal.note("carving", "Carved on the trapper's post: \"J.T. 1974. Don't follow the lights.\"")
		"prints":
			p.message.emit("Boot prints, weeks old, heading east away from the wreck. One foot drags. Whoever walked out of here was hurt.")
			Journal.note("prints", "Someone walked away from the wreck, east, limping. The survivor's note is signed M. Where is the survey camp?")

# --- Drawing -----------------------------------------------------------------------

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	match kind:
		"homestead": _homestead(rng)
		"trapper": _trapper(rng)
		"crash": _crash(rng)

func _homestead(rng: RandomNumberGenerator) -> void:
	var log_c := Color("6a5a48")
	for i in 4: # the fallen-in cabin: low wall courses, grey with age
		var y := -12.0 - i * 22.0
		var w := 300.0 - i * 60.0
		draw_rect(Rect2(-260 + i * 18.0, y - 11.0, w, 22.0), log_c.darkened(0.08 * (i % 2)))
		draw_circle(Vector2(-262 + i * 18.0, y), 11.0, log_c.darkened(0.2))
	for k in 3: # roof timbers collapsed across it
		draw_line(Vector2(-240 + k * 70.0, -4), Vector2(-120 + k * 80.0, -150 + k * 20.0), log_c.darkened(0.25), 12.0)
	for row in 13: # the stone chimney, still standing
		for c in 2:
			var cc := Vector2(-40 + c * 30.0 + (row % 2) * 12.0, -10.0 - row * 22.0)
			draw_colored_polygon(SceneryArt.blob(cc, 15.0, rng, 7, 0.2), Palette.ROCK.darkened(0.1 + 0.12 * rng.randf()))
	for k in 5: # split-rail fence, gone grey (east of the cellar door)
		var x := 340.0 + k * 60.0
		draw_line(Vector2(x, 4), Vector2(x, -70), log_c, 6.0)
		if k < 4:
			draw_line(Vector2(x, -55), Vector2(x + 60.0, -52 + (12.0 if k == 2 else 0.0)), log_c.lightened(0.1), 5.0)
			draw_line(Vector2(x, -28), Vector2(x + 60.0, -30), log_c.lightened(0.1), 5.0)
	draw_line(Vector2(-400, 4), Vector2(-400, -74), log_c.darkened(0.1), 7.0) # the grave marker
	draw_line(Vector2(-424, -54), Vector2(-376, -54), log_c.darkened(0.1), 7.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-440, 4), Vector2(-360, 4), Vector2(-372, -6), Vector2(-428, -6)]), Palette.SOIL_TOP.lightened(0.1))

func _trapper(rng: RandomNumberGenerator) -> void:
	var pole := Color("5a4a38")
	for k in 4: # the lean-to, fallen flat
		draw_line(Vector2(-220 + k * 14.0, -2), Vector2(-60 + k * 10.0, -40 + k * 6.0), pole, 9.0)
	draw_line(Vector2(-40, 4), Vector2(-50, -110), pole.darkened(0.15), 9.0) # the post
	if not _found("auger"): # an ice auger leaning on it
		draw_line(Vector2(-22, 2), Vector2(-40, -92), Color("8a9096"), 4.0)
		draw_line(Vector2(-48, -90), Vector2(-32, -94), Color("5a4a38"), 5.0)
	for i in 7: # fire ring
		draw_circle(Vector2(60 + i * 20.0, -5), 9.0, Palette.ROCK.darkened(0.2))
	for k in 2: # willow stretching hoops
		var c := Vector2(230 + k * 60.0, -70)
		draw_arc(c, 36.0, 0, TAU, 20, Color("7a6a4a"), 4.0)
		draw_line(c + Vector2(0, 36), c + Vector2(0, 74), pole, 4.0)
	draw_rect(Rect2(-150, -26, 56, 26), Color("5c5a52")) # the tin trunk on a stump
	draw_rect(Rect2(-150, -26, 56, 26), Color("3a3834"), false, 2.0)
	if not _found("cache"):
		draw_line(Vector2(-150, -14), Vector2(-94, -14), Color("9aa0a6"), 1.5) # wire still round it

func _crash(rng: RandomNumberGenerator) -> void:
	var white := Color("d8d6ce")
	var red := Color("9a3a2e")
	draw_colored_polygon(Transform2D(0.0, Vector2(1, 0.12), 0.0, Vector2.ZERO) * SceneryArt.blob(Vector2.ZERO, 380.0, rng, 16, 0.25), Color("262220")) # scorched ground
	# The fuselage on its side, nose down toward the east, tail up to the west.
	var body := PackedVector2Array([Vector2(-260, -40), Vector2(-120, -120), Vector2(120, -130), Vector2(190, -90), Vector2(200, -20), Vector2(160, 4), Vector2(-150, 4), Vector2(-250, -18)])
	draw_colored_polygon(body, white)
	draw_line(Vector2(-240, -44), Vector2(185, -70), red, 10.0) # the stripe
	draw_colored_polygon(PackedVector2Array([Vector2(-260, -40), Vector2(-330, -210), Vector2(-280, -215), Vector2(-200, -80)]), white.darkened(0.08)) # tail fin
	draw_colored_polygon(PackedVector2Array([Vector2(-300, -170), Vector2(-270, -200), Vector2(-240, -150), Vector2(-270, -140)]), red)
	for k in 3: # cockpit windows, cracked
		draw_rect(Rect2(110 + k * 22.0, -118 + k * 6.0, 18, 22), Color("3a4550"))
	draw_line(Vector2(114, -112), Vector2(150, -96), Color(0.8, 0.85, 0.9, 0.6), 1.2)
	draw_colored_polygon(PackedVector2Array([Vector2(200, -60), Vector2(232, -40), Vector2(226, -12), Vector2(200, -18)]), Color("3a3a3a")) # engine cowling
	draw_line(Vector2(230, -38), Vector2(262, -80), Color("5a5a5a"), 5.0) # bent prop
	draw_line(Vector2(230, -34), Vector2(250, 2), Color("5a5a5a"), 5.0)
	# The torn-off wing, lying apart, and scattered cargo.
	draw_colored_polygon(PackedVector2Array([Vector2(290, -8), Vector2(530, -30), Vector2(540, -12), Vector2(300, 6)]), white.darkened(0.12))
	draw_line(Vector2(380, -22), Vector2(420, -26), red, 6.0)
	for k in 4:
		var c := Vector2(-460 + k * 70.0 + rng.randf_range(-10, 10), -14)
		draw_rect(Rect2(c - Vector2(22, 16), Vector2(44, 32)), Color("7a6a4a").darkened(0.1 * (k % 2)))
		draw_rect(Rect2(c - Vector2(22, 16), Vector2(44, 32)), Color("4a3a2a"), false, 2.0)
	if not _found("cargo"):
		draw_rect(Rect2(-100, -44, 40, 28), Color("8a9096")) # the steel case among the crates
		draw_rect(Rect2(-100, -44, 40, 28), Color("3a3e44"), false, 2.0)
	# A line of old boot prints, walking off east (one foot dragging).
	for k in 9:
		var x := 300.0 + k * 34.0
		draw_rect(Rect2(x, -2 + (k % 2) * 2.0, 10.0 if k % 2 == 0 else 14.0, 3.0), Color(0.12, 0.1, 0.08, 0.45))

## Nothing hides the player here except the wreck's near side, drawn over them inside.
func _draw_front() -> void:
	if kind != "crash":
		return
	var p: Player = get_tree().get_first_node_in_group("player")
	var inside := p != null and covers(p.global_position.x)
	var a := 0.35 if inside else 1.0
	_front.draw_colored_polygon(PackedVector2Array([Vector2(-150, 4), Vector2(160, 4), Vector2(170, -30), Vector2(-160, -28)]), Color("c8c6be", a)) # near lower panel
	_front.draw_line(Vector2(-150, -14), Vector2(160, -18), Color("9a3a2e", a), 4.0)
