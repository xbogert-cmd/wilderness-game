class_name Creek extends Node2D
## A creek, river, pond or lake as something to use: fill a held container, or drink straight
## from it. Wild water is always dirty; boiling makes it safe. In a hard cold it freezes over:
## the ice bears your weight, and you chop a hole to reach the water (it skins over again).
## One node per body of water (index into Terrain.WATERS), built with its chunk.

const DIRTY_HEALTH_COST := 1.0
const SICK_CHANCE := 0.3 ## per drink of unboiled water: a gut sickness a few hours later
const SICK_AMOUNT := 0.3
const FROZEN := 0.6 ## weather.ice at which the surface bears weight
const HOLE_HOURS := 8.0

var terrain: Terrain
var index := 0 ## which of Terrain.WATERS
var hole_until := -INF
var hole_x := 0.0 ## where the hole in the ice was chopped (ice fishing drops the line there)
var _ice: CollisionShape2D

func w() -> Dictionary:
	return Terrain.WATERS[index]

func kind() -> String:
	return w().kind

## The body of water whose span contains x, if its chunk is loaded.
static func at(tree: SceneTree, x: float) -> Creek:
	for c: Creek in tree.get_nodes_in_group("creek"):
		if absf(x - c.w().x) < c.w().half:
			return c
	return null

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("creek")
	z_as_relative = false
	z_index = 8 # the hole shows over the ice
	var body := StaticBody2D.new()
	_ice = CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	var s := terrain.surface_of(index)
	seg.a = Vector2(w().x - w().half, s)
	seg.b = Vector2(w().x + w().half, s)
	_ice.shape = seg
	_ice.disabled = true
	body.add_child(_ice)
	add_child(body)

static func frozen() -> bool:
	return GameClock.weather.ice >= FROZEN

func hole_open() -> bool:
	return GameClock.clock.hours < hole_until

func _draw() -> void: # the hole, a dark oval in the ice
	if frozen() and hole_open():
		var s := terrain.surface_of(index) - global_position.y
		draw_colored_polygon(Transform2D(0.0, Vector2(1.0, 0.28), 0.0, Vector2(hole_x - global_position.x, s)) * SceneryArt.blob(Vector2.ZERO, 36.0, RandomNumberGenerator.new(), 12, 0.1), Color(0.05, 0.08, 0.1))

func _process(_delta: float) -> void:
	if frozen() and hole_open():
		queue_redraw() # it skins over again in time

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

## The water the player is standing at; else null.
static func reachable(p: Player) -> Creek:
	for c: Creek in p.get_tree().get_nodes_in_group("creek"):
		if c._at_water(p):
			return c
	return null

func _at_water(p: Player) -> bool:
	return absf(p.global_position.x - w().x) < w().half - 40.0

func interact_pos() -> Vector2:
	var p: Player = get_tree().get_first_node_in_group("player")
	var x := clampf(p.global_position.x, w().x - w().half, w().x + w().half)
	return Vector2(x, p.global_position.y)

func interact_label(p: Player) -> String:
	if not _at_water(p):
		return ""
	if frozen() and not hole_open():
		return "Chop a hole in the ice"
	if clean():
		return ("Fill %s (spring water, clean)" % p.held.def.name.to_lower()) if p.held and p.held.def.capacity > 0.0 else "Drink from the spring (clean)"
	if p.held and p.held.def.capacity > 0.0:
		return "Fill %s (%s water is dirty)" % [p.held.def.name.to_lower(), kind()]
	return "Drink from the %s (dirty)" % kind()

## A spring: water straight out of the ground, safe to drink.
func clean() -> bool:
	return w().get("clean", false)

func interact(p: Player) -> void:
	if frozen() and not hole_open():
		p.swing = 0.0
		hole_until = GameClock.clock.hours + HOLE_HOURS
		hole_x = clampf(p.global_position.x + p.facing * 60.0, w().x - w().half + 40.0, w().x + w().half - 40.0)
		queue_redraw()
		p.message.emit("You chop through the ice. Black water wells up." + ("  You could fish through it." if w().fish else ""))
		return
	if p.held and p.held.def.capacity > 0.0:
		fill(p, p.held)
		return
	p.cond.drink(ItemStack.THIRST_PER_SIP)
	if clean():
		p.message.emit("Cold and sweet, straight out of the rock.")
		return
	p.cond.health -= DIRTY_HEALTH_COST
	p.cond.expose(SICK_AMOUNT, SICK_CHANCE)
	p.message.emit("Cold and silty. Unboiled water can make you sick.")

func fill(p: Player, s: ItemStack) -> void:
	var took := s.add_water(s.def.capacity, clean())
	if took > 0.0:
		p.message.emit(("Filled with %.2f L of clean spring water." % took) if clean() else ("Filled with %.2f L of %s water. Boil it before drinking." % [took, kind()]))
	elif s.water > 0.001 and s.water_clean != clean():
		p.message.emit("It holds %s water. Empty or drink it first so they don't mix." % ("dirty" if clean() else "clean"))
	else:
		p.message.emit("It's already full.")
