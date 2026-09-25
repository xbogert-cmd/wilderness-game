class_name Workbench extends Node2D
## A split-log bench with a peg vise. The bigger crafting (bow, arrows, hide coat, deer call)
## and handle repairs need one close by; E opens the pack to work at it.

const REACH := 260.0

var world: World

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup
	add_to_group("structure")
	add_to_group("workbench")
	z_as_relative = false
	z_index = 2

func load_state(d: Dictionary, _elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))

func to_state() -> Dictionary:
	return {"kind": "workbench", "x": global_position.x}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.workbench.width

static func near(p: Player) -> bool:
	for b: Workbench in p.get_tree().get_nodes_in_group("workbench"):
		if absf(b.global_position.x - p.global_position.x) < REACH:
			return true
	return false

func interact_pos() -> Vector2:
	return global_position

func interact_label(_p: Player) -> String:
	return "Work at the bench"

func interact(p: Player) -> void:
	var ui: BackpackUI = get_tree().get_first_node_in_group("backpack_ui")
	if ui and not ui.visible:
		ui.toggle()

func _draw() -> void:
	var top := Palette.BARK.lightened(0.18)
	for sx in [-62.0, -48.0, 48.0, 62.0]: # splayed legs
		draw_line(Vector2(sx, 4), Vector2(sx * 0.85, -70), Palette.BARK_DARK, 7.0)
	draw_rect(Rect2(-78, -86, 156, 18), top)
	draw_rect(Rect2(-78, -86, 156, 18), Palette.BARK_DARK, false, 2.0)
	draw_line(Vector2(-70, -79), Vector2(66, -80), top.darkened(0.2), 1.5) # split face grain
	draw_rect(Rect2(46, -104, 10, 20), Palette.BARK_DARK) # vise peg
	draw_rect(Rect2(60, -100, 8, 16), Palette.BARK_DARK)
	draw_line(Vector2(-52, -88), Vector2(-20, -96), Color("9aa0a6"), 3.0) # a drawknife left on it
	draw_line(Vector2(-58, -86), Vector2(-50, -90), Palette.BARK_DARK, 4.0)
