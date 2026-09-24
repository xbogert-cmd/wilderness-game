class_name Hud extends Control
## Four permanent circular meters; warmth, wetness and injuries appear only when they matter.

const R := 22.0
const GAP := 62.0
const COLORS := {
	"health": Color("c8574a"), "stamina": Color("d8c060"),
	"hunger": Color("c98a4a"), "thirst": Color("5aa0c0"),
}
const INJURY_TEXT := {"sprain": "Sprained", "cut": "Cut"}

var cond: Condition
var _font: Font

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var base := Vector2(46, size.y - 46)
	var values := {"health": cond.health, "stamina": cond.stamina, "hunger": cond.hunger, "thirst": cond.thirst}
	var i := 0
	for key in values:
		var c := base + Vector2(GAP * i, 0)
		var v: float = values[key] / 100.0
		var col: Color = COLORS[key]
		var low := v < 0.2
		if low:
			col = col.lerp(Color.WHITE, 0.35 + 0.35 * sin(Time.get_ticks_msec() * 0.008))
		draw_circle(c, R + 5.0, Color(0, 0, 0, 0.35))
		draw_arc(c, R, 0, TAU, 40, Color(1, 1, 1, 0.12), 5.0, true)
		draw_arc(c, R, -PI / 2.0, -PI / 2.0 + TAU * v, 40, col, 5.0, true)
		_icon(key, c, col)
		i += 1
	# Contextual line: only shown when relevant.
	var notes: PackedStringArray = []
	if cond.warmth < 35.0: notes.append("Cold" if cond.warmth > 15.0 else "Freezing")
	elif cond.warmth > 80.0: notes.append("Overheated")
	if cond.wetness > 0.15: notes.append("Soaked" if cond.wetness > 0.6 else "Damp")
	for region in cond.injuries:
		notes.append("%s %s" % [INJURY_TEXT.get(cond.injuries[region].kind, "Hurt"), region])
	if notes.size() > 0:
		draw_string(_font, base + Vector2(-20, -R - 18), "  ·  ".join(notes), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.92, 0.85, 0.9))

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
