class_name Hud extends Control
## Four permanent circular meters; warmth, wetness and injuries appear only when they matter.
## Also: the context prompt above the player, what's in hand, and short messages.

const R := 22.0
const GAP := 62.0
const COLORS := {
	"health": Color("c8574a"), "stamina": Color("d8c060"),
	"hunger": Color("c98a4a"), "thirst": Color("5aa0c0"),
}
const INJURY_TEXT := {"sprain": "Sprained", "cut": "Cut"}
const MSG_SECONDS := 4.5
const TEXT := Color(0.95, 0.92, 0.85)

var player: Player
var _font: Font
var _msgs: Array = [] ## [text, time_left]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	player.message.connect(func(t: String): _msgs.append([t, MSG_SECONDS]))

func _process(delta: float) -> void:
	for m in _msgs:
		m[1] -= delta
	_msgs = _msgs.filter(func(m): return m[1] > 0.0).slice(-4)
	queue_redraw()

func _text(pos: Vector2, s: String, size := 16, col := TEXT, center := false) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos - Vector2(w * 0.5 if center else 0.0, 0)
	draw_string(_font, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, col.a * 0.7))
	draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _draw() -> void:
	var cond := player.cond
	var base := Vector2(46, size.y - 46)
	var values := {"health": cond.health, "stamina": cond.stamina, "hunger": cond.hunger, "thirst": cond.thirst}
	var i := 0
	for key in values:
		var c := base + Vector2(GAP * i, 0)
		var v: float = values[key] / 100.0
		var col: Color = COLORS[key]
		if v < 0.2:
			col = col.lerp(Color.WHITE, 0.35 + 0.35 * sin(Time.get_ticks_msec() * 0.008))
		draw_circle(c, R + 5.0, Color(0, 0, 0, 0.35))
		draw_arc(c, R, 0, TAU, 40, Color(1, 1, 1, 0.12), 5.0, true)
		draw_arc(c, R, -PI / 2.0, -PI / 2.0 + TAU * v, 40, col, 5.0, true)
		_icon(key, c, col)
		i += 1

	var notes: PackedStringArray = []
	if cond.warmth < 35.0: notes.append("Cold" if cond.warmth > 15.0 else "Freezing")
	elif cond.warmth > 80.0: notes.append("Overheated")
	if player.world.heat_at(player.global_position + Vector2(0, -60)) > 0.1: notes.append("By the fire")
	if cond.wetness > 0.15: notes.append("Soaked" if cond.wetness > 0.6 else "Damp")
	if player.world.sheltered_at(player.global_position.x): notes.append("Sheltered")
	for region in cond.injuries:
		notes.append("%s %s%s" % [INJURY_TEXT.get(cond.injuries[region].kind, "Hurt"), region, " (treated)" if cond.injuries[region].treated else ""])
	if player.backpack.encumbrance_mult() < 1.0: notes.append("Heavy pack")
	if notes.size() > 0:
		_text(base + Vector2(-20, -R - 18), "  ·  ".join(notes))

	var hand := "Hands: empty"
	if player.carrying:
		hand = "Hands: %s log (F to set down)" % player.carrying.size
	elif player.held:
		hand = "Hands: " + player.held.label(GameClock.clock.hours)
		if player.held.def.has("tool"):
			hand += "  · edge %d%%" % int(player.held.sharpness * 100.0)
	_text(Vector2(GAP * 4 + 30, size.y - 40), hand, 15, Color(TEXT, 0.85))

	# Context prompt above the player's head.
	var lines: PackedStringArray = []
	if player.working > 0.0:
		lines.append(player.work_label + "…")
	else:
		if player.chop_target:
			lines.append("[Click] " + player.chop_target.chop_label(player))
		if player.focus:
			lines.append("[E] " + player.focus.interact_label(player))
		if player.carrying == null and _log_nearby():
			lines.append("[F] Lift log")
	var head := player.get_global_transform_with_canvas().origin + Vector2(0, -215.0 * player.get_viewport().get_camera_2d().zoom.y)
	for k in lines.size():
		_text(head + Vector2(0, (k - lines.size() + 1) * 20.0), lines[k], 15, TEXT, true)

	var y := size.y - 110.0
	for k in _msgs.size():
		var m: Array = _msgs[_msgs.size() - 1 - k]
		_text(Vector2(size.x * 0.5, y - k * 22.0), m[0], 16, Color(TEXT, clampf(m[1], 0.0, 1.0)), true)

func _log_nearby() -> bool:
	for l in get_tree().get_nodes_in_group("log"):
		if l.holder == null and absf(l.global_position.x - player.global_position.x) < l.length() * 0.5 + 60.0:
			return true
	return false

func _icon(key: String, c: Vector2, col: Color) -> void:
	match key:
		"health":
			draw_rect(Rect2(c - Vector2(2.5, 8), Vector2(5, 16)), col)
			draw_rect(Rect2(c - Vector2(8, 2.5), Vector2(16, 5)), col)
		"stamina":
			draw_colored_polygon(PackedVector2Array([c + Vector2(2, -10), c + Vector2(-6, 2), c + Vector2(0, 2), c + Vector2(-2, 10), c + Vector2(6, -2), c + Vector2(0, -2)]), col)
		"hunger":
			draw_arc(c + Vector2(0, -1), 8.0, 0.0, PI, 16, col, 3.0)
			draw_line(c + Vector2(-10, -1), c + Vector2(10, -1), col, 2.5)
		"thirst":
			draw_circle(c + Vector2(0, 3), 6.0, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5.5, 1), c + Vector2(0, -10), c + Vector2(5.5, 1)]), col)
