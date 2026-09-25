class_name TrailSign extends Node2D
## The trailhead sign: a little orientation and a nudge toward the lookout on the far ridge.

const TEXT := "RATTLESNAKE CREEK TRAIL · Creek crossing 1 mi east · Lookout on the east ridge, no services · Pack it in, pack it out"

func _ready() -> void:
	add_to_group("interactable")
	z_as_relative = false
	z_index = 2

func interact_pos() -> Vector2:
	return global_position

func interact_label(_p: Player) -> String:
	return "Read the sign"

func interact(p: Player) -> void:
	p.message.emit(TEXT)

func _draw() -> void:
	var wood := Palette.BARK.lightened(0.15)
	draw_line(Vector2(-26, 4), Vector2(-26, -120), Palette.BARK_DARK, 8.0)
	draw_line(Vector2(26, 4), Vector2(26, -120), Palette.BARK_DARK, 8.0)
	draw_rect(Rect2(-52, -142, 104, 48), wood)
	draw_rect(Rect2(-52, -142, 104, 48), Palette.BARK_DARK, false, 3.0)
	for i in 3:
		draw_line(Vector2(-40, -128 + i * 12), Vector2(40 - i * 14, -128 + i * 12), Palette.BARK_DARK, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(30, -110), Vector2(44, -104), Vector2(30, -98)]), Palette.BARK_DARK) # arrow east
