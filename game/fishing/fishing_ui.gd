class_name FishingUI extends Control
## The reel meter, bottom centre, while a fish is on: needle, green strike zone, line gained,
## and slack used up (three misses and it's gone).

const W := 460.0
var fishing: Fishing

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	var f := fishing.fight
	if fishing.state == Fishing.State.BITE:
		var s := "Bite! %s to hook" % Keys.label("use")
		draw_string(font, Vector2(size.x * 0.5 - 70, size.y - 250), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.92, 0.6))
	if f == null:
		return
	var o := Vector2(size.x * 0.5 - W * 0.5, size.y - 250.0)
	draw_rect(Rect2(o - Vector2(16, 44), Vector2(W + 32, 96)), Color(0.05, 0.06, 0.05, 0.75))
	draw_string(font, o + Vector2(0, -22), "%s — %s when the needle is in the green" % [f.spec.name.capitalize(), Keys.label("use")], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.93, 0.9, 0.83))
	draw_rect(Rect2(o, Vector2(W, 16)), Color(1, 1, 1, 0.12))
	var zl := (f.zone - f.zone_half()) * W
	draw_rect(Rect2(o + Vector2(zl, 0), Vector2(f.zone_half() * 2.0 * W, 16)), Color(0.45, 0.8, 0.45, 0.85 if f.in_zone() else 0.6))
	var nx := o.x + f.needle * W
	draw_line(Vector2(nx, o.y - 6), Vector2(nx, o.y + 22), Color.WHITE, 3.0)
	draw_rect(Rect2(o + Vector2(0, 28), Vector2(W, 6)), Color(1, 1, 1, 0.1))
	draw_rect(Rect2(o + Vector2(0, 28), Vector2(W * f.progress, 6)), Color("7fc3e0"))
	for i in FishFight.MAX_STRAIN:
		draw_circle(o + Vector2(W - 10.0 - i * 18.0, -28), 6.0, Color("c0392b") if i < f.strain else Color(1, 1, 1, 0.25))
