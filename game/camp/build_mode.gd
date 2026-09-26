class_name BuildMode extends Node2D
## B opens the build book; pick something and a ghost follows the mouse along the ground near
## the player. Left click places a blueprint where it fits; right click cancels.

const RANGE := 380.0
const WATER_KINDS := {"span": ["creek", "river"], "creek": ["creek"], "fish": ["creek", "river", "pond", "lake", "pool"], "still": ["river", "pond", "lake", "pool"]}
const WATER_WHERE := {"span": "A bridge goes over a creek or the river: stand by the bank.", "creek": "A weir goes across a creek.",
	"fish": "A fish trap goes in water with fish in it (not while it's frozen).", "still": "A gill net goes across the river, a lake, a pond or a pool (not while it's frozen)."}
const MAX_STEP := 40.0 ## allowed height difference across the footprint

var player: Player
var world: World
var book: BuildBook
var build_id := ""
var _ok := false

func _ready() -> void:
	add_to_group("build_mode")
	z_index = 9

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build"):
		if build_id != "":
			_cancel()
		else:
			book.open()
		get_viewport().set_input_as_handled()
	elif build_id != "":
		if event.is_action_pressed("use"):
			if _ok:
				world.spawn({"kind": "blueprint", "build": build_id, "x": global_position.x})
				player.message.emit("Blueprint placed. Bring the materials and press E.")
				_cancel()
			else:
				var bd: Dictionary = Builds.STRUCTURES[build_id]
				player.message.emit(("A bear bag hangs from a tall standing tree (one without a bag)." if bd.on == "tree" else "A pot tripod goes over a campfire that doesn't have one.") if bd.has("on") \
					else (WATER_WHERE[bd.water] if bd.has("water") else "Can't build there: needs level, dry ground with space."))
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("aim") or event.is_action_pressed("menu"):
			_cancel()
			get_viewport().set_input_as_handled()

func choose(id: String) -> void:
	build_id = id
	player.placing = true

func _cancel() -> void:
	build_id = ""
	player.placing = false
	queue_redraw()

func _process(_delta: float) -> void:
	if build_id == "":
		return
	var x := clampf(player.aim_point().x, player.global_position.x - RANGE, player.global_position.x + RANGE)
	var d: Dictionary = Builds.STRUCTURES[build_id]
	if d.has("water"): # a bridge (or weir) across the nearest creek; a trap or net in the water
		var i := world.terrain.water_index(x, 900.0 if d.water in ["span", "creek"] else 40.0) # traps and nets: aim at the water itself
		var wd: Dictionary = Terrain.WATERS[i] if i >= 0 else {}
		var fits_here: bool = i >= 0 and wd.kind in WATER_KINDS[d.water] and (d.water == "span" or wd.fish)
		if fits_here:
			x = wd.x if d.water in ["span", "creek"] else clampf(x, wd.x - wd.half + d.width * 0.5 + 20.0, wd.x + wd.half - d.width * 0.5 - 20.0)
		var crowded := get_tree().get_nodes_in_group("structure").any(func(s): return absf(s.global_position.x - x) < (10.0 if d.water == "span" else (s.width() + d.width) * 0.4) \
			and (d.water == "span" or s is FishTrap or s is Weir or (s is Blueprint and s.def().has("water"))))
		_ok = fits_here and not crowded and (d.water == "span" or not Creek.frozen())
	elif d.has("on"): # snaps onto the nearest host, e.g. a tripod over a campfire
		var host := Blueprint.host_at(get_tree(), d.on, x, RANGE)
		if host:
			x = host.global_position.x
		_ok = host != null and (d.on == "tree" or not host.get(build_id)) and not _blueprint_at(x)
	else:
		_ok = fits(x, d.width)
	global_position = Vector2(x, world.terrain.height_at(x))
	queue_redraw()

func _blueprint_at(x: float) -> bool:
	return get_tree().get_nodes_in_group("structure").any(func(s): return s is Blueprint and absf(s.global_position.x - x) < 10.0)

func fits(x: float, w: float) -> bool:
	var t := world.terrain
	var lo := INF
	var hi := -INF
	for k in 5:
		var sx := x - w * 0.5 + w * k / 4.0
		if t.water_surface_at(sx) != INF:
			return false
		lo = minf(lo, t.height_at(sx))
		hi = maxf(hi, t.height_at(sx))
	if hi - lo > MAX_STEP:
		return false
	for s in get_tree().get_nodes_in_group("structure"):
		if absf(s.global_position.x - x) < (s.width() + w) * 0.5:
			return false
	return true

func _draw() -> void:
	if build_id == "":
		return
	var w: float = Builds.STRUCTURES[build_id].width
	var c := Color(0.6, 1.0, 0.6, 0.6) if _ok else Color(1.0, 0.45, 0.4, 0.6)
	var h: float = Builds.STRUCTURES[build_id].h
	draw_rect(Rect2(-w * 0.5, -h, w, h), c, false, 3.0)
	draw_rect(Rect2(-w * 0.5, -h, w, h), Color(c, 0.12))
