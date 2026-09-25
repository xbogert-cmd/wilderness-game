class_name Creek extends Node2D
## The creek as something to use: fill a held container, or drink straight from it.
## Creek water is always dirty; boiling makes it safe.

const DIRTY_HEALTH_COST := 3.0

var terrain: Terrain

func _ready() -> void:
	add_to_group("interactable")

func _at_water(p: Player) -> bool:
	return absf(p.global_position.x - Terrain.CREEK_X) < Terrain.CREEK_HALF - 40.0

func interact_pos() -> Vector2:
	var p: Player = get_tree().get_first_node_in_group("player")
	var x := clampf(p.global_position.x, Terrain.CREEK_X - Terrain.CREEK_HALF, Terrain.CREEK_X + Terrain.CREEK_HALF)
	return Vector2(x, p.global_position.y)

func interact_label(p: Player) -> String:
	if not _at_water(p):
		return ""
	if p.held and p.held.def.capacity > 0.0:
		return "Fill %s (creek water is dirty)" % p.held.def.name.to_lower()
	return "Drink from the creek (dirty)"

func interact(p: Player) -> void:
	if p.held and p.held.def.capacity > 0.0:
		var took := p.held.add_water(p.held.def.capacity, false)
		if took > 0.0:
			p.message.emit("Filled with %.2f L of creek water. Boil it before drinking." % took)
		elif p.held.water_clean and p.held.water > 0.001:
			p.message.emit("It holds clean water. Empty or drink it first so they don't mix.")
		else:
			p.message.emit("It's already full.")
		return
	p.cond.drink(ItemStack.THIRST_PER_SIP)
	p.cond.health -= DIRTY_HEALTH_COST
	p.message.emit("Cold and silty. Boiled water would be safer.")
