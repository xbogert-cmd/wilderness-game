class_name Creek extends Node2D
## The creek as something to use: fill a held container, or drink straight from it.
## Creek water is always dirty; boiling makes it safe. In a hard cold it freezes over: the
## ice bears your weight, and you chop a hole to reach the water (it skins over again).

const DIRTY_HEALTH_COST := 3.0
const FROZEN := 0.6 ## weather.ice at which the surface bears weight
const HOLE_HOURS := 8.0

var terrain: Terrain
var hole_until := -INF
var _ice: CollisionShape2D

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("creek")
	var body := StaticBody2D.new()
	_ice = CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	var s := terrain.water_surface_at(Terrain.CREEK_X)
	seg.a = Vector2(Terrain.CREEK_X - Terrain.CREEK_HALF, s)
	seg.b = Vector2(Terrain.CREEK_X + Terrain.CREEK_HALF, s)
	_ice.shape = seg
	_ice.disabled = true
	body.add_child(_ice)
	add_child(body)

static func frozen() -> bool:
	return GameClock.weather.ice >= FROZEN

func hole_open() -> bool:
	return GameClock.clock.hours < hole_until

func _physics_process(_delta: float) -> void:
	var solid := frozen()
	if solid == _ice.disabled: # freezing or thawing this frame
		if solid:
			var p: Player = get_tree().get_first_node_in_group("player")
			var s := terrain.water_surface_at(p.global_position.x)
			if s != INF and p.global_position.y > s - 4.0: # caught wading: step up onto the ice
				p.global_position.y = s - 4.0
				p.velocity.y = 0.0
		_ice.disabled = not solid

## The creek, if the player is standing at the water; else null.
static func reachable(p: Player) -> Creek:
	var c: Creek = p.get_tree().get_first_node_in_group("creek")
	return c if c and c._at_water(p) else null

func _at_water(p: Player) -> bool:
	return absf(p.global_position.x - Terrain.CREEK_X) < Terrain.CREEK_HALF - 40.0

func interact_pos() -> Vector2:
	var p: Player = get_tree().get_first_node_in_group("player")
	var x := clampf(p.global_position.x, Terrain.CREEK_X - Terrain.CREEK_HALF, Terrain.CREEK_X + Terrain.CREEK_HALF)
	return Vector2(x, p.global_position.y)

func interact_label(p: Player) -> String:
	if not _at_water(p):
		return ""
	if frozen() and not hole_open():
		return "Chop a hole in the ice"
	if p.held and p.held.def.capacity > 0.0:
		return "Fill %s (creek water is dirty)" % p.held.def.name.to_lower()
	return "Drink from the creek (dirty)"

func interact(p: Player) -> void:
	if frozen() and not hole_open():
		p.swing = 0.0
		hole_until = GameClock.clock.hours + HOLE_HOURS
		p.message.emit("You chop through the ice. Black water wells up.")
		return
	if p.held and p.held.def.capacity > 0.0:
		fill(p, p.held)
		return
	p.cond.drink(ItemStack.THIRST_PER_SIP)
	p.cond.health -= DIRTY_HEALTH_COST
	p.message.emit("Cold and silty. Boiled water would be safer.")

func fill(p: Player, s: ItemStack) -> void:
	var took := s.add_water(s.def.capacity, false)
	if took > 0.0:
		p.message.emit("Filled with %.2f L of creek water. Boil it before drinking." % took)
	elif s.water_clean and s.water > 0.001:
		p.message.emit("It holds clean water. Empty or drink it first so they don't mix.")
	else:
		p.message.emit("It's already full.")
