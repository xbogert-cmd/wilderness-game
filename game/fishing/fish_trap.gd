class_name FishTrap extends Node2D
## Passive fishing. A *fish trap* is a woven willow basket staked in the current with its mouth
## upstream: fish swim in and can't find the way out, and they're still alive when you come to
## check it. A fish weir (stakes across a creek) funnels far more of them into a trap below
## it. A *gill net* strung across a river, lake, pond or pool catches more, but what's in it is
## dead: check it often or it spoils. Nothing's caught while the water's frozen over.
## Catches up on hours spent away. A flood on a creek or the river may tear it loose and take it.

const RATE := {"fish_trap": 0.05, "net": 0.1} ## fish per hour, on average
const HOLDS := {"fish_trap": 3, "net": 5}
const WEIR_R := 420.0
const WASH := {"fish_trap": 0.5, "net": 0.6, "weir": 0.3} ## odds a flood takes it

var world: World
var variety := "fish_trap" ## "fish_trap" or "net"
var fish: Array = [] ## [species, hour caught]
var floods_seen := 0 ## Weather.floods when it was last checked
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup
	add_to_group("structure")
	z_as_relative = false
	z_index = 9 # in the water, over the creek bed
	_rng.randomize()
	GameClock.ticked.connect(_on_tick)

func load_state(d: Dictionary, elapsed: float) -> void:
	variety = d.kind
	var i := world.terrain.water_index(float(d.x))
	global_position = Vector2(float(d.x), world.terrain.surface_of(i, false) if i >= 0 else world.terrain.height_at(float(d.x)))
	fish = d.get("fish", []).map(func(f): return [str(f[0]), float(f[1])])
	floods_seen = int(d.get("floods", GameClock.weather.floods))
	if elapsed > 0.0:
		_on_tick.call_deferred(elapsed)

func to_state() -> Dictionary:
	return {"kind": variety, "x": global_position.x, "fish": fish, "floods": floods_seen}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES[variety].width

func water() -> Dictionary:
	var i := world.terrain.water_index(global_position.x)
	return Terrain.WATERS[i] if i >= 0 else {"kind": "creek", "x": global_position.x, "half": 100.0}

func weir_near() -> bool:
	return get_tree().get_nodes_in_group("weir").any(func(w): return absf(w.global_position.x - global_position.x) < WEIR_R)

## Fish per hour here right now.
func rate() -> float:
	if Creek.frozen():
		return 0.0
	var r: float = RATE[variety]
	if variety == "fish_trap" and weir_near():
		r *= 2.5
	if FishLife.salmon_run() and water().kind in FishLife.RUN_WATERS:
		r *= 1.8
	return r

func _on_tick(dh: float) -> void:
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	if flood_took(self, _name()):
		return
	var n := 0
	var t := 0.0 # hours in, over dh
	while fish.size() < HOLDS[variety]:
		var r := rate()
		if r <= 0.0:
			break
		t += -log(1.0 - _rng.randf() * 0.999) / r # the wait for the next one
		if t > dh:
			break
		fish.append([FishLife.pick(water().kind, _rng), GameClock.clock.hours - dh + t])
		n += 1
	if n > 0:
		queue_redraw()

## Each flood since it was last looked at may have torn it loose (only in running water).
## True if it's gone.
static func flood_took(n: Node2D, what: String) -> bool:
	if n.floods_seen >= GameClock.weather.floods:
		return false
	var chance: float = WASH[n.variety] if "variety" in n else WASH.weir
	var i: int = n.world.terrain.water_index(n.global_position.x)
	var running: bool = i >= 0 and Terrain.WATERS[i].kind in Creek.FLOWING
	while n.floods_seen < GameClock.weather.floods:
		n.floods_seen += 1
		if running and randf() < chance:
			var p: Player = n.get_tree().get_first_node_in_group("player")
			if p:
				p.message.emit("The flood has torn your %s loose and taken it off down the %s." % [what, Terrain.WATERS[i].name])
			n.queue_free()
			return true
	return false

func interact_pos() -> Vector2:
	return global_position

func prompt_point(_p: Player) -> Vector2:
	return global_position + Vector2(0, -90)

func _name() -> String:
	return "fish trap" if variety == "fish_trap" else "gill net"

func interact_options(p: Player) -> Array:
	if Creek.frozen():
		return [["The %s is frozen into the ice%s" % [_name(), "  (%d fish in it)" % fish.size() if fish else ""], Callable()]]
	if fish.is_empty():
		return [["Check the %s  (nothing yet%s)" % [_name(), ": a weir upstream would help" if variety == "fish_trap" and not weir_near() else ""], Callable()]]
	return [["Take the fish from the %s  (%d)" % [_name(), fish.size()], _take.bind(p)]]

func interact_title(_p: Player) -> String:
	return _name().capitalize()

func interact_label(p: Player) -> String:
	return Player.first_label(interact_options(p))

func interact(p: Player) -> void:
	Player.run_first(interact_options(p))

func _take(p: Player) -> void:
	var kept := []
	var names := {}
	for f in fish:
		var sp: Dictionary = FishFight.SPECIES[f[0]]
		# alive in a trap until you take them; dead in a net since they were caught
		var st := ItemStack.make(sp.item, GameClock.clock.hours if variety == "fish_trap" else f[1])
		if p.receive(st, false):
			names[sp.name] = names.get(sp.name, 0) + 1
		else:
			kept.append(f)
	fish = kept
	if names:
		p.message.emit("Out of the %s: %s." % [_name(), ", ".join(names.keys().map(func(k): return "%d %s" % [names[k], k]))])
		Journal.note("fish_trap", "Passive fishing: a basket trap staked in the creek (a weir above it funnels the fish in) or a gill net strung across still water. Check them every day or so. What's in a net is dead and spoils; a trap keeps them alive.")
	if kept:
		p.message.emit("No room in the pack for the rest.")
	queue_redraw()

func _draw() -> void:
	var stake := Palette.BARK_DARK
	var water_c := Color(0.7, 0.8, 0.85, 0.5)
	if variety == "fish_trap": # a woven cone basket, half under, staked
		var c := Color("8a7248")
		draw_colored_polygon(PackedVector2Array([Vector2(-34, -16), Vector2(30, -8), Vector2(34, 10), Vector2(-34, 22)]), c)
		for k in 6:
			draw_line(Vector2(-30 + k * 12, -15 + k * 1.2), Vector2(-30 + k * 12, 21 - k * 2.0), c.darkened(0.25), 1.5)
		draw_circle(Vector2(-34, 3), 14.0, c.darkened(0.35)) # the mouth
		draw_circle(Vector2(-34, 3), 8.0, Color(0.1, 0.1, 0.08))
		for sx in [-18.0, 22.0]:
			draw_line(Vector2(sx, 30), Vector2(sx, -40), stake, 4.0)
		for f in mini(fish.size(), 3): # tails flicking inside
			draw_line(Vector2(-10 + f * 12, 4), Vector2(-4 + f * 12, -2 + sin(Time.get_ticks_msec() * 0.01 + f) * 3.0), Color(0.75, 0.78, 0.7), 2.0)
	else: # floats on a line between two stakes, the mesh hanging below
		var half := width() * 0.5
		for sx in [-half, half]:
			draw_line(Vector2(sx, 34), Vector2(sx, -30), stake, 4.0)
		draw_line(Vector2(-half, -4), Vector2(half, -4), Color(0.85, 0.82, 0.72), 1.5)
		for k in 7:
			var fx := -half + 12.0 + k * (half * 2.0 - 24.0) / 6.0
			draw_circle(Vector2(fx, -4), 4.0, Color("c0392b") if k % 2 == 0 else Color("e8e2d0"))
			draw_line(Vector2(fx, -4), Vector2(fx, 30), Color(0.8, 0.8, 0.75, 0.35), 1.0)
		for f in mini(fish.size(), 5):
			var fx := -half + 22.0 + f * 24.0
			draw_colored_polygon(PackedVector2Array([Vector2(fx - 9, 12), Vector2(fx + 9, 10), Vector2(fx + 12, 14), Vector2(fx - 9, 16)]), Color(0.72, 0.74, 0.7, 0.7))
	draw_line(Vector2(-60, 0), Vector2(60, 0), water_c, 2.0) # the waterline over it

func _process(_delta: float) -> void:
	if variety == "fish_trap" and fish:
		queue_redraw() # the tails flick
