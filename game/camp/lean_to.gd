class_name LeanTo extends Node2D
## A quick log shelter: keeps rain off whoever is under it, and becomes a camp
## (respawn, rest and save point once sleep and saving land).

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

func interact_label(_p: Player) -> String:
	return "Lean-to (dry here; rest and camp saves arrive next milestone)"

func interact(p: Player) -> void:
	p.message.emit("It's dry under here. Rain won't soak you while you stay close.")

## Side profile: a tall front post and ridge, roof poles sloping to the ground behind,
## bough thatch on the roof, bedding underneath.
func _draw() -> void:
	var bark := Palette.BARK
	var dark := Palette.BARK_DARK
	var top := Vector2(95, -175)
	var back := Vector2(-125, 4)
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
		draw_colored_polygon(SceneryArt.blob(p, 30.0, rng, 8, 0.3), Palette.FIR_DARK.lightened(0.06 * (i % 2)))
	draw_rect(Rect2(-80, -9, 170, 9), Palette.FIR_LIGHT.darkened(0.25)) # bedding
