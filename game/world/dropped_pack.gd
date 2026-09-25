class_name DroppedPack extends Node2D
## The pack left where the player died. It never despawns; recovering it is the expedition.

var world: World
var pack_data := {}

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	z_index = 4

func load_state(d: Dictionary, _elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))
	pack_data = d.pack

func to_state() -> Dictionary:
	return {"kind": "pack", "x": global_position.x, "pack": pack_data}

func can_unload() -> bool:
	return true

func interact_pos() -> Vector2:
	return global_position

func interact_label(_p: Player) -> String:
	return "Recover your pack"

func interact(p: Player) -> void:
	var recovered := Backpack.new()
	recovered.from_dict(pack_data)
	var extra := p.backpack.all_stacks() # whatever was gathered since
	p.backpack = recovered
	for s in extra:
		var strapped := false
		if s.def.has("attachable"):
			for i in Backpack.ATTACH_SLOTS:
				if not strapped and recovered.attachments[i] == null:
					strapped = recovered.attach(s, i)
		if not strapped and not recovered.add(s):
			world.spawn({"kind": "item", "x": global_position.x + 40.0, "stack": s.to_dict()})
	p.message.emit("You shoulder your pack again.")
	queue_free()

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-22, 0), Vector2(24, 0), Vector2(20, -30), Vector2(-18, -34)]), Palette.PACK)
	draw_line(Vector2(-18, -34), Vector2(20, -30), Palette.PACK.darkened(0.3), 3.0)
	draw_circle(Vector2(0, -40), 10.0, Palette.BEDROLL)
	draw_line(Vector2(-10, -12), Vector2(12, -10), Palette.BOOTS, 3.0)
