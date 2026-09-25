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
var fade := 0.0 ## full-screen black, for death and waking
var _tip := ""
var _tip_t := 0.0
const TIP_SECONDS := 7.0

func tip(text: String) -> void:
	_tip = text
	_tip_t = TIP_SECONDS

func fade_to(target: float, seconds: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(self, "fade", target, seconds)
	return tw

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	player.message.connect(func(t: String): _msgs.append([t, MSG_SECONDS]))

func _process(delta: float) -> void:
	for m in _msgs:
		m[1] -= delta
	_msgs = _msgs.filter(func(m): return m[1] > 0.0).slice(-4)
	_tip_t = maxf(_tip_t - delta, 0.0)
	_highlight()
	queue_redraw()

## Which way the wind blows and how hard: scent travels with it, so hunt into the wind.
func _wind(at: Vector2) -> void:
	var w := GameClock.weather
	var dir := float(w.wind_dir)
	var word := "calm" if w.wind < 0.2 else ("breeze" if w.wind < 0.45 else ("windy" if w.wind < 0.7 else "gale"))
	var c := Color(TEXT, 0.8)
	var mid := at + Vector2(22, -5)
	var len := 12.0 + 14.0 * clampf(w.wind, 0.0, 1.0)
	draw_line(mid - Vector2(dir * len, 0), mid + Vector2(dir * len, 0), c, 2.0)
	draw_colored_polygon(PackedVector2Array([mid + Vector2(dir * (len + 7.0), 0), mid + Vector2(dir * len, -5), mid + Vector2(dir * len, 5)]), c)
	_text(at + Vector2(54, 0), "Wind: " + word, 15, c)

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
	if cond.fatigue > 60.0: notes.append("Exhausted" if cond.fatigue > 85.0 else "Tired")
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
		if player.held.def.has("axe") or player.held.def.has("knife"):
			hand += "  · edge %d%%" % int(player.held.sharpness * 100.0)
		elif player.held.def.has("bow"):
			hand += "  · %d arrows" % player.backpack.count_of("arrows")
	_text(Vector2(GAP * 4 + 30, size.y - 40), hand, 15, Color(TEXT, 0.85))
	_wind(Vector2(size.x - 190, size.y - 44))

	# Interaction popups: a key-cap plus action, floating over the thing you'd act on.
	var placed: Array[Vector2] = []
	for pr in _prompts():
		var at: Vector2 = get_viewport().get_canvas_transform() * pr[0]
		for q in placed: # keep stacked prompts from overlapping
			if at.distance_to(q) < 30.0:
				at.y = q.y - 34.0
		placed.append(at)
		if pr[1] == "menu":
			_menu(at, pr[2])
		else:
			_popup(at, Keys.label(pr[1]) if pr[1] != "" else "", pr[2])

	if player.sleeping: # letterbox + clock while time runs fast
		var bar := size.y * 0.09
		draw_rect(Rect2(0, 0, size.x, bar), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(0, size.y - bar, size.x, bar), Color(0, 0, 0, 0.85))
		var c := GameClock.clock
		_text(Vector2(size.x * 0.5, size.y - bar * 0.4), "Sleeping  ·  %02d:%02d  ·  rested %d%%  ·  any key to wake" % [int(c.hour_of_day()), int(fmod(c.hour_of_day(), 1.0) * 60.0), int(100.0 - cond.fatigue)], 18, TEXT, true)

	var y := size.y - 110.0
	for k in _msgs.size():
		var m: Array = _msgs[_msgs.size() - 1 - k]
		_text(Vector2(size.x * 0.5, y - k * 22.0), m[0], 16, Color(TEXT, clampf(m[1], 0.0, 1.0)), true)
	if _tip_t > 0.0: # one-time hint, top centre, calm styling
		var a := clampf(_tip_t, 0.0, 1.0) * clampf((TIP_SECONDS - _tip_t) * 3.0, 0.0, 1.0)
		var w := minf(_font.get_string_size(_tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 36.0, size.x - 40.0)
		var r := Rect2(Vector2(size.x * 0.5 - w * 0.5, 26.0), Vector2(w, 38.0))
		var box := _panel.duplicate()
		box.bg_color.a *= a
		box.border_color = Color(0.93, 0.85, 0.6, 0.5 * a)
		draw_style_box(box, r)
		draw_string(_font, r.position + Vector2(18, 25), _tip, HORIZONTAL_ALIGNMENT_LEFT, w - 36.0, 16, Color(TEXT, a))
	_draw_fade()

func _draw_fade() -> void:
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, fade))

## [world anchor, action (or ""), text]. Key popups are kept for camp things and cutting a
## felled trunk; everyday actions (chopping, picking up, lifting) only glow, so the world
## isn't covered in labels.
func _prompts() -> Array:
	if player.working > 0.0:
		return [[player.global_position + Vector2(0, -210), "", player.work_label + "…"]]
	if player.sleeping or player.dead:
		return []
	var out := []
	if player.chop_target is FelledTrunk:
		out.append([_anchor(player.chop_target), "use", player.chop_target.chop_label(player)])
	var f := player.focus
	if f and f.is_in_group("camp"):
		if player.menu == f:
			out.append([_anchor(f), "menu", f])
		else:
			var n := Player.choices_of(f, player).size()
			var text: String = f.interact_title(player) if n > 1 and f.has_method("interact_title") else f.interact_label(player)
			if n > 1:
				text += "  ·  %d choices" % n
			out.append([_anchor(f), "interact", text])
	return out

## The open list of choices: the thing's name on top, then one numbered line per choice
## (notes about what can't be done yet are dimmed and have no key).
func _menu(at: Vector2, f: Node) -> void:
	var opts := Player.options_of(f, player)
	var title: String = f.interact_title(player) if f.has_method("interact_title") else "Choose"
	var lines := opts.size() + 1
	var y := at.y - 100.0 - 34.0 * lines # the whole list floats clear above the player's head
	_popup(Vector2(at.x, y), "", title)
	var k := 0
	for o in opts:
		y += 34.0
		if o[1].is_valid():
			k += 1
			_popup(Vector2(at.x, y), str(k), o[0])
		else:
			_popup(Vector2(at.x, y), "", o[0], 0.55)
	_popup(Vector2(at.x, y + 34.0), Keys.label("interact"), "close", 0.55)

func _anchor(n: Node) -> Vector2:
	if n.has_method("prompt_point"):
		return n.prompt_point(player)
	if n.has_method("interact_pos"):
		return n.interact_pos() + Vector2(0, -80)
	return n.global_position + Vector2(0, -80)

var _cap := _box(Color(0.93, 0.9, 0.82), Color(0.1, 0.1, 0.1, 0.9), 5)
var _panel := _box(Color(0.06, 0.07, 0.06, 0.72), Color(1, 1, 1, 0.12), 6)

static func _box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(radius)
	return b

func _popup(at: Vector2, key: String, text: String, alpha := 1.0) -> void:
	var fs := 15
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var kw := maxf(26.0, _font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 12.0) if key != "" else 0.0
	var w := kw + (8.0 if key != "" else 0.0) + tw + 20.0
	var r := Rect2(at - Vector2(w * 0.5, 16.0), Vector2(w, 32.0))
	draw_style_box(_panel, r)
	var x := r.position.x + 8.0
	if key != "":
		var bob := sin(Time.get_ticks_msec() * 0.006) * 1.2
		var cap := Rect2(Vector2(x, r.position.y + 4.0 + bob), Vector2(kw, 24.0))
		draw_style_box(_cap, cap)
		draw_string(_font, cap.position + Vector2(0, 17), key, HORIZONTAL_ALIGNMENT_CENTER, kw, 13, Color(0.1, 0.1, 0.1))
		x += kw + 8.0
	draw_string(_font, Vector2(x, r.position.y + 21.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(TEXT, alpha))

## The thing you'd act on glows softly, so you know what the popup refers to.
var _lit: Array = []
func _highlight() -> void:
	var want := []
	if not (player.sleeping or player.dead or player.working > 0.0):
		for n in [player.focus, player.chop_target, player.nearest_log() if player.carrying == null else null]:
			if n != null and n is CanvasItem and not (n is ChoppableTree or n is Tracks) and n not in want:
				want.append(n)
	for n in _lit:
		if is_instance_valid(n) and n not in want:
			n.modulate = Color.WHITE
	var k := 1.18 + 0.12 * sin(Time.get_ticks_msec() * 0.005)
	for n in want:
		n.modulate = Color(k, k, k * 0.92)
	_lit = want

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
