class_name BuildMode extends Node2D
## B opens a list of known structures; pick one and a ghost follows the mouse along the
## ground near the player. Left click places a blueprint where it fits; right click cancels.

const RANGE := 380.0
const MAX_STEP := 40.0 ## allowed height difference across the footprint

var player: Player
var world: World
var menu: VBoxContainer
var build_id := ""
var _ok := false

func _ready() -> void:
	add_to_group("build_mode")
	z_index = 9
	menu.visible = false
	for id in Builds.STRUCTURES:
		var b := Button.new()
		var d: Dictionary = Builds.STRUCTURES[id]
		b.text = "%s — %s" % [d.name, Builds.needs_text(d.needs, {})]
		b.pressed.connect(_choose.bind(id))
		menu.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build"):
		if build_id != "":
			_cancel()
		else:
			menu.visible = not menu.visible
	elif build_id != "":
		if event.is_action_pressed("use"):
			if _ok:
				world.spawn({"kind": "blueprint", "build": build_id, "x": global_position.x})
				player.message.emit("Blueprint placed. Bring the materials and press E.")
				_cancel()
			else:
				player.message.emit("A pot tripod goes over a campfire that doesn't have one." if Builds.STRUCTURES[build_id].has("on") \
					else "Can't build there: needs level, dry ground with space.")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("aim") or event.is_action_pressed("menu"):
			_cancel()
			get_viewport().set_input_as_handled()

func _choose(id: String) -> void:
	build_id = id
	menu.visible = false
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
	if d.has("on"): # snaps onto the nearest host, e.g. a tripod over a campfire
		var host := Blueprint.host_at(get_tree(), d.on, x, RANGE)
		if host:
			x = host.global_position.x
		_ok = host != null and not host.get(build_id) and not _blueprint_at(x)
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
