class_name LeanTo extends Node2D
## A quick log shelter: keeps rain off whoever is under it. Sleeping here (or building it)
## makes it your camp: the respawn point and an autosave.

const COVER := 110.0

var world: World

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("structure")
	add_to_group("shelter")
	z_index = -3

func load_state(d: Dictionary, _elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))
	if d.get("fresh", false):
		var p: Player = get_tree().get_first_node_in_group("player")
		p.camp_x = global_position.x
		p.message.emit("The lean-to is up. This is your camp now.")
		p.made_camp.emit()

func to_state() -> Dictionary:
	return {"kind": "lean_to", "x": global_position.x}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.lean_to.width

func covers(x: float) -> bool:
	return absf(x - global_position.x) < COVER

func interact_pos() -> Vector2:
	return global_position

func interact_label(p: Player) -> String:
	var q := p.sleep_quality()
	return "Sleep  (%s rest%s)" % ["good" if q > 0.75 else ("fair" if q > 0.5 else "poor"), "" if p.backpack.count_of("sleeping_bag") > 0 else ", no sleeping bag"]

func interact(p: Player) -> void:
	p.sleep()

## Side profile: a tall front post and ridge, roof poles sloping to the ground behind,
## bough thatch on the roof, bedding underneath.
func _draw() -> void:
	var bark := Palette.BARK
	var dark := Palette.BARK_DARK
	var top := Vector2(95, -175)
	var back := Vector2(-125, 4)
	draw_colored_polygon(PackedVector2Array([top, Vector2(100, 4), back]), Color(0.08, 0.07, 0.06, 0.75)) # shade inside
	draw_line(Vector2(100, 4), top, dark, 11.0) # front post
	draw_line(top + Vector2(-6, -8), top + Vector2(14, 8), dark, 8.0) # fork
	var along := (back - top).normalized()
	var across := along.orthogonal()
	for i in 5: # roof poles
		var o := across * (i - 2) * 3.0
		draw_line(top + o, back + o, bark.darkened(0.06 * (i % 3)), 12.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 10: # bough thatch laid along the roof
		var p := top.lerp(back, (i + 0.5) / 10.0) + across * rng.randf_range(-14, -4)
		var bough := Palette.FIR_LIGHT.lerp(Palette.GRASS_DRY, 0.25 * (i % 3))
		draw_colored_polygon(SceneryArt.blob(p, 28.0, rng, 8, 0.3), bough)
	draw_line(top, back, bark.lightened(0.15), 5.0) # top pole over the thatch
	draw_rect(Rect2(-80, -9, 170, 9), Palette.FIR_LIGHT.darkened(0.25)) # bedding
