class_name MapUI extends Control
## M: the map and field journal, fully paused. The map is the valley's profile as you've seen
## it (unexplored stretches stay blank), with landmarks, your camp and structures, game trails
## and where you are. The journal lists every entry, newest first.

const PANEL := Color(0.09, 0.1, 0.09, 0.95)
const PAPER := Color(0.83, 0.78, 0.66)
const INK := Color(0.22, 0.18, 0.13)
const TEXT := Color(0.93, 0.9, 0.83)
const MAP := Rect2(70, 130, 1780, 400)
const H_TOP := -3000.0 ## terrain y at the top of the map strip
const H_BOTTOM := 400.0

var player: Player
var world: World
var _font: Font
var _scroll: ScrollContainer
var _list: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = get_theme_default_font()
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(MAP.position.x, MAP.end.y + 70.0)
	_scroll.size = Vector2(MAP.size.x, 430)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(MAP.size.x - 30.0, 0)
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") or (visible and event.is_action_pressed("menu")):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if not visible and (player.working > 0.0 or player.placing or get_tree().paused):
		return
	visible = not visible
	get_tree().paused = visible
	if visible:
		_fill_journal()
		queue_redraw()

func _fill_journal() -> void:
	for c in _list.get_children():
		c.queue_free()
	var entries: Array = Journal.current.entries if Journal.current else []
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		var h := float(e.hours)
		var l := Label.new()
		l.text = "Day %d, %02d:%02d  —  %s" % [int(h / 24.0) + 1, int(fposmod(h, 24.0)), int(fmod(fposmod(h, 24.0), 1.0) * 60.0), e.text]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(MAP.size.x - 40.0, 0)
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", TEXT)
		_list.add_child(l)

func _mx(x: float) -> float:
	return MAP.position.x + x / Terrain.WORLD_W * MAP.size.x

func _my(y: float) -> float:
	return MAP.position.y + (y - H_TOP) / (H_BOTTOM - H_TOP) * MAP.size.y

func _ground(x: float) -> Vector2:
	return Vector2(_mx(x), maxf(_my(world.terrain.height_at(x)), MAP.position.y + 4.0)) # the edge walls run off the top

## Everything built: live nodes plus what's stored in chunks that aren't loaded.
func _structures() -> Array:
	var out := []
	for n in get_tree().get_nodes_in_group("persist"):
		if n.is_queued_for_deletion() or n is WorldItem or n is WorldLog:
			continue
		out.append(n.to_state())
	for key in world.state:
		for d in world.state[key].objects:
			out.append(d)
	return out

func _draw() -> void:
	var clock := GameClock.clock
	draw_rect(Rect2(40, 40, 1840, 1000), PANEL)
	_text(Vector2(MAP.position.x, 100), "Map  ·  Day %d, %s" % [clock.day() + 1, clock.season_name()], 26, TEXT)
	_text(Vector2(MAP.end.x - 330, 100), "%s or Esc to close" % Keys.label("map"), 16, Color(TEXT, 0.6))
	draw_rect(MAP, PAPER)
	# Ground profile, one explored cell at a time; unknown ground stays as blank paper.
	var cell := World.MAP_CELL
	var snowy := GameClock.weather.snow_cm > 2.0
	var x := 0.0
	while x < Terrain.WORLD_W:
		if world.seen(x):
			var a := _ground(x)
			var b := _ground(x + cell)
			draw_colored_polygon(PackedVector2Array([a, b, Vector2(b.x, MAP.end.y), Vector2(a.x, MAP.end.y)]), Color(0.55, 0.47, 0.35))
			draw_line(a, b, Color(0.93, 0.95, 0.99) if snowy else Color(0.36, 0.45, 0.25), 3.0)
		else:
			draw_line(Vector2(_mx(x), MAP.end.y - 6), Vector2(_mx(x + cell), MAP.end.y - 6), Color(INK, 0.25), 1.0)
		x += cell
	# The creek.
	if world.seen(Terrain.CREEK_X):
		var cx := _mx(Terrain.CREEK_X)
		var cw := maxf(Terrain.CREEK_HALF * 2.0 / Terrain.WORLD_W * MAP.size.x, 4.0)
		draw_rect(Rect2(cx - cw * 0.5, _my(world.terrain.bank_y) - 2, cw, 10), Color(0.72, 0.84, 0.9) if Creek.frozen() else Color(0.3, 0.5, 0.62))
		_label(Vector2(cx, _my(world.terrain.bank_y) + 34), "Rattlesnake Creek")
	# Game trails, where you've seen them.
	for i in Terrain.CHUNKS:
		var t := Wildlife.trail(i)
		var tx := minf(t.x, t.y)
		while tx < maxf(t.x, t.y):
			if world.seen(tx):
				var p := _ground(tx) + Vector2(0, -7)
				draw_line(p, p + Vector2(6, 0), Color(0.45, 0.3, 0.16), 2.0)
			tx += 260.0
	# Landmarks.
	if world.seen(player.start_x):
		var s := _ground(player.start_x - 180.0)
		draw_line(s, s + Vector2(0, -16), INK, 2.0)
		draw_rect(Rect2(s + Vector2(-7, -22), Vector2(14, 8)), INK)
		_label(s + Vector2(0, -30), "Trailhead")
	if world.seen(Terrain.CAVE_X):
		var c := _ground(Terrain.CAVE_X)
		draw_arc(c, 14.0, PI, TAU, 10, INK, 4.0)
		_label(c + Vector2(0, -26), "Rock shelter")
	if world.seen(Terrain.LOOKOUT_X):
		var l := _ground(Terrain.LOOKOUT_X)
		draw_line(l + Vector2(-6, 0), l + Vector2(-3, -30), INK, 2.0)
		draw_line(l + Vector2(6, 0), l + Vector2(3, -30), INK, 2.0)
		draw_rect(Rect2(l + Vector2(-8, -40), Vector2(16, 10)), INK)
		_label(l + Vector2(0, -50), "Fire lookout")
	# What you've built.
	for d in _structures():
		var sx := float(d.get("x", 0.0))
		var g := _ground(sx)
		match str(d.get("kind", "")):
			"lean_to", "cabin":
				draw_colored_polygon(PackedVector2Array([g + Vector2(-9, 0), g + Vector2(9, 0), g + Vector2(9, -10), g + Vector2(0, -18), g + Vector2(-9, -10)]), Color(0.5, 0.2, 0.12))
				_label(g + Vector2(0, -26), "Camp" if absf(sx - player.camp_x) < 50.0 else ("Cabin" if d.kind == "cabin" else "Lean-to"))
			"campfire":
				draw_circle(g + Vector2(0, -5), 4.0, Color(0.9, 0.45, 0.1) if d.get("lit", false) else Color(0.3, 0.25, 0.2))
			"pack":
				draw_rect(Rect2(g + Vector2(-5, -12), Vector2(10, 12)), Color(0.8, 0.15, 0.1))
				_label(g + Vector2(0, -18), "Your pack")
			"carcass":
				draw_circle(g + Vector2(0, -4), 4.0, Color(0.55, 0.12, 0.1))
			"item", "log", "trunk":
				pass
			_:
				draw_rect(Rect2(g + Vector2(-3, -7), Vector2(6, 6)), Color(0.35, 0.28, 0.2))
	# You are here.
	var me := _ground(player.global_position.x)
	draw_colored_polygon(PackedVector2Array([me + Vector2(0, -6), me + Vector2(-8, -22), me + Vector2(8, -22)]), Color(0.85, 0.1, 0.08))
	draw_rect(MAP, INK, false, 2.0)
	_text(Vector2(MAP.position.x, MAP.end.y + 50), "Field journal", 22, TEXT)
	_text(Vector2(MAP.position.x + 190, MAP.end.y + 50), "west ←   ·   → east        brown dashes: game trails    red: you", 15, Color(TEXT, 0.5))

func _label(center: Vector2, t: String) -> void:
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(_font, center + Vector2(-w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)

func _text(pos: Vector2, t: String, size: int, c: Color) -> void:
	draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
