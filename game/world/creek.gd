class_name Creek extends Node2D
## A creek, river, pond or lake as something to use: fill a held container, or drink straight
## from it. Wild water is always dirty; boiling makes it safe. In a hard cold it freezes over:
## the ice bears your weight, and you chop a hole to reach the water (it skins over again).
## Chopping a hole takes a while with the hatchet; an ice auger bores one in a moment and it
## stays open longer. Hold a spear or fish spear at the water's edge and you can see fish as
## shadows in the shallows: strike where one is. In autumn salmon leap in the river and the
## Falls Pool.
## Just frozen, or thawing, the ice is thin: it creaks, cracks and gives way under you, and
## you're in the freezing water. Rain and meltwater raise the creeks; in flood they run brown
## and too deep and fast to wade. In spring the ice goes out in broken floes.
## One node per body of water (index into Terrain.WATERS), built with its chunk.

const DIRTY_HEALTH_COST := 1.0
const SICK_CHANCE := 0.3 ## per drink of unboiled water: a gut sickness a few hours later
const SICK_AMOUNT := 0.3
const FROZEN := 0.6 ## weather.ice at which the surface bears weight
const SOLID := 0.8 ## below this the ice is thin: it holds you for a moment, then goes
const HOLE_HOURS := 8.0
const FLOWING := ["creek", "river", "pool"]

var terrain: Terrain
var index := 0 ## which of Terrain.WATERS
var hole_until := -INF
var hole_x := 0.0 ## where the hole in the ice was chopped (ice fishing drops the line there)
var _ice: CollisionShape2D
var shadows: Array = [] ## fish you can see in the shallows, holding a spear: {x, y (below the surface), v}
var _jumps: Array = [] ## salmon in the air: {x, t, d}
var _jump_t := 3.0
var _rng := RandomNumberGenerator.new()
var _fish_shape: PackedVector2Array
var water_mat: ShaderMaterial ## the water polygon's, to set its level and colour
var _level := INF
var _strain := 0.0 ## real seconds you've stood on thin ice; it goes at _limit
var _limit := 3.0
var _creaked := 0
var _crack_x := 0.0
var _broken := 0.0 ## real seconds the ice is open under you (you went through)
var _floes: Array = [] ## broken ice going out in the breakup: {x, w, ph}
var _floe_t := 0.0

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

## Frozen, but not hard enough to trust.
static func thin() -> bool:
	return frozen() and GameClock.weather.ice < SOLID

func flowing() -> bool:
	return kind() in FLOWING

## Running too high and fast to wade.
func in_flood() -> bool:
	return flowing() and GameClock.weather.flood >= Weather.WADE_FLOOD and not frozen()

func hole_open() -> bool:
	return GameClock.clock.hours < hole_until

func _draw() -> void:
	var s := terrain.surface_of(index) - global_position.y
	if frozen() and hole_open(): # the hole, a dark oval in the ice
		draw_colored_polygon(Transform2D(0.0, Vector2(1.0, 0.28), 0.0, Vector2(hole_x - global_position.x, s)) * SceneryArt.blob(Vector2.ZERO, 36.0, RandomNumberGenerator.new(), 12, 0.1), Color(0.05, 0.08, 0.1))
	if _strain > 0.0 and frozen(): # cracks spreading out from under your boots
		var r := RandomNumberGenerator.new()
		r.seed = int(_crack_x)
		var k := clampf(_strain / _limit, 0.0, 1.0)
		for i in 7:
			var a := Vector2(_crack_x - global_position.x, s + 2.0)
			var dir := -1.0 if i % 2 == 0 else 1.0
			for j in 4:
				var b := a + Vector2(dir * r.randf_range(14.0, 34.0) * k * 2.0, r.randf_range(-1.5, 3.0))
				draw_line(a, b, Color(0.95, 0.98, 1.0, 0.85), 1.5)
				a = b
	for f in _floes: # plates of broken ice going out, tilting in the current
		var at := Vector2(f.x - global_position.x, s + sin(Time.get_ticks_msec() * 0.002 + f.ph) * 3.0)
		var tilt := sin(Time.get_ticks_msec() * 0.0013 + f.ph) * 0.12
		draw_set_transform(at, tilt, Vector2.ONE)
		var fw: float = f.w
		draw_colored_polygon(PackedVector2Array([Vector2(-fw, -6), Vector2(fw * 0.8, -8), Vector2(fw, 4), Vector2(-fw * 0.9, 7)]), Color(0.86, 0.92, 0.96, 0.95))
		draw_line(Vector2(-fw, -6), Vector2(fw * 0.8, -8), Color(1, 1, 1), 2.0)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	for f in shadows: # a dark shape under the surface, tail working
		var at := Vector2(f.x - global_position.x, s + f.y)
		var dir := signf(f.v) if f.v != 0.0 else 1.0
		if _fish_shape.is_empty():
			var r := RandomNumberGenerator.new()
			r.seed = 5
			_fish_shape = SceneryArt.blob(Vector2.ZERO, 22.0, r, 8, 0.05)
		draw_colored_polygon(Transform2D(0.0, Vector2(1.0, 0.32), 0.0, at) * _fish_shape, Color(0.06, 0.08, 0.08, 0.42))
		draw_line(at - Vector2(dir * 20.0, 0), at - Vector2(dir * 32.0, sin(Time.get_ticks_msec() * 0.012 + f.x) * 5.0), Color(0.06, 0.08, 0.08, 0.42), 4.0)
	for j in _jumps: # a salmon arcing out of the water
		var k: float = j.t / 0.9
		var at := Vector2(j.x - global_position.x + j.d * k * 110.0, s - sin(k * PI) * 95.0)
		var ang := atan2(-cos(k * PI) * 95.0 * PI, j.d * 110.0)
		draw_set_transform(at, ang if j.d > 0 else PI + ang, Vector2(1, 1))
		draw_colored_polygon(PackedVector2Array([Vector2(-26, 0), Vector2(-10, -9), Vector2(18, -7), Vector2(28, 0), Vector2(18, 7), Vector2(-10, 8)]), Color("a0524a"))
		draw_colored_polygon(PackedVector2Array([Vector2(-26, 0), Vector2(-36, -9), Vector2(-36, 9)]), Color("7a3a34"))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		if k < 0.12 or k > 0.88:
			draw_arc(Vector2(at.x, s), 16.0 + k * 10.0, PI, TAU, 10, Color(1, 1, 1, 0.5), 2.0)

func _process(delta: float) -> void:
	var p: Player = get_tree().get_first_node_in_group("player")
	var near: bool = p != null and absf(p.global_position.x - w().x) < w().half + 2500.0
	var redraw := frozen() and hole_open() # it skins over again in time
	var level := terrain.surface_of(index)
	if water_mat and absf(level - _level) > 0.5: # rising and falling with a flood
		_level = level
		water_mat.set_shader_parameter("surface_y", level)
		water_mat.set_shader_parameter("mud", clampf((GameClock.weather.flood - 0.15) / 0.6, 0.0, 1.0) * (1.0 if flowing() else 0.3))
		redraw = true
	if near:
		redraw = _thin_ice(p, delta) or redraw
		redraw = _breakup(p, delta) or redraw
	# Salmon jumping during the run.
	if near and not frozen() and FishLife.salmon_run() and kind() in FishLife.RUN_WATERS:
		_jump_t -= delta
		if _jump_t <= 0.0:
			_jump_t = _rng.randf_range(1.5, 5.0)
			_jumps.append({"x": w().x + _rng.randf_range(-0.7, 0.7) * w().half, "t": 0.0, "d": 1.0 if _rng.randf() < 0.5 else -1.0})
			if absf(p.global_position.x - w().x) < w().half + 900.0:
				Journal.note("salmon_run", "The salmon are running up the Sweetwater, big red fish come up from the sea to spawn. They jump at the falls. The river's full of them till the late autumn.")
	for j in _jumps:
		j.t += delta
	_jumps = _jumps.filter(func(j): return j.t < 0.9)
	redraw = redraw or not _jumps.is_empty()
	# Fish in the shallows, seen when you're at the edge with a spear.
	var looking: bool = near and w().fish and not frozen() and p.held != null and (p.held.def.has("leister") or p.held.def.has("spear")) \
		and absf(p.global_position.x - w().x) < w().half + 300.0
	if looking:
		while shadows.size() < 4:
			shadows.append({"x": w().x + _rng.randf_range(-0.8, 0.8) * w().half, "y": 0.0, "v": _rng.randf_range(-60.0, 60.0)})
		for f in shadows:
			if _rng.randf() < delta * 0.5:
				f.v = _rng.randf_range(-70.0, 70.0) # dart off another way
			f.x = clampf(f.x + f.v * delta, w().x - w().half + 30.0, w().x + w().half - 30.0)
			var depth := terrain.height_at(f.x) - terrain.surface_of(index)
			f.y = clampf(depth * 0.55, 10.0, 46.0)
			if depth < 14.0 or absf(f.x - (w().x - w().half + 30.0)) < 1.0 or absf(f.x - (w().x + w().half - 30.0)) < 1.0:
				f.v = -f.v if f.v != 0.0 else 40.0
		redraw = true
	elif not shadows.is_empty():
		shadows.clear()
		redraw = true
	if redraw:
		queue_redraw()

## A spear driven into the water at pos (world): the fish there, if one's close enough; "" if missed.
func spear(pos: Vector2, radius: float) -> String:
	var s := terrain.surface_of(index)
	for f in shadows:
		if absf(f.x - pos.x) < radius and absf(s + f.y - pos.y) < 70.0:
			shadows.erase(f)
			queue_redraw()
			return FishLife.pick(kind(), _rng, true)
	return ""

## Standing on thin ice: it creaks, cracks, and gives. True while there's something to draw.
func _thin_ice(p: Player, delta: float) -> bool:
	var on: bool = thin() and _broken <= 0.0 and p.is_on_floor() and p.under <= 0.0 \
		and absf(p.global_position.x - w().x) < w().half - 30.0 and absf(p.global_position.y - (_ice.shape as SegmentShape2D).a.y) < 14.0
	if not on:
		if _strain > 0.0:
			_strain = maxf(_strain - delta * 0.6, 0.0)
			if _strain == 0.0:
				_creaked = 0
			return true
		return false
	if _strain == 0.0:
		_crack_x = p.global_position.x
		_limit = lerpf(1.6, 7.0, (GameClock.weather.ice - FROZEN) / (SOLID - FROZEN)) * _rng.randf_range(0.7, 1.3)
	_strain += delta * (1.8 if p.running else 1.0) * (1.4 if p.carrying or p.hauling else 1.0)
	if _creaked == 0:
		_creaked = 1
		Sfx.play_at(self, p.global_position, Sfx.ice(), -4.0)
		p.message.emit("The ice is thin here. It creaks and sags under you: get off it, carefully!")
	elif _creaked == 1 and _strain > _limit * 0.6:
		_creaked = 2
		Sfx.play_at(self, p.global_position, Sfx.ice(), 0.0, 0.9)
		p.message.emit("It's cracking!")
	if _strain >= _limit:
		_plunge(p)
	return true

## Through the ice.
func _plunge(p: Player) -> void:
	_broken = 1.6
	_strain = 0.0
	_creaked = 0
	hole_until = GameClock.clock.hours + HOLE_HOURS
	hole_x = p.global_position.x
	Sfx.play_at(self, p.global_position, Sfx.ice(), 2.0, 0.8)
	Sfx.play_at(self, p.global_position, Sfx.splash(), 0.0, 0.8)
	p.plunge()

## The breakup: in a thaw the ice goes out, floes grinding and cracking down the creek.
func _breakup(p: Player, delta: float) -> bool:
	var going := GameClock.weather.breakup > 0.0 and not frozen() and kind() != "spring"
	if not going:
		if _floes.is_empty():
			return false
		_floes.clear()
		return true
	var left := GameClock.weather.breakup / 8.0 # fewer and smaller as it goes
	while _floes.size() < int(3.0 + 8.0 * left * w().half / 400.0):
		_floes.append({"x": w().x + _rng.randf_range(-0.85, 0.85) * w().half, "w": _rng.randf_range(18.0, 55.0) * (0.5 + left), "ph": _rng.randf() * TAU})
	var drift := 12.0 if flowing() else 2.0
	for f in _floes:
		f.x += sin(f.ph + Time.get_ticks_msec() * 0.0004) * drift * delta
		f.x = clampf(f.x, w().x - w().half * 0.9, w().x + w().half * 0.9)
	var close: bool = absf(p.global_position.x - w().x) < w().half + 1200.0
	if close:
		Journal.note("breakup", "The ice went out on the %s today with a noise like gunfire: plates of it grinding and heaving down the current, the water up and brown behind it. Spring." % w().name)
		_floe_t -= delta
		if _floe_t <= 0.0:
			_floe_t = _rng.randf_range(1.5, 5.0)
			Sfx.play_at(self, Vector2(w().x + _rng.randf_range(-1.0, 1.0) * w().half, terrain.surface_of(index)), Sfx.ice(), -6.0, _rng.randf_range(0.8, 1.1))
	return true

func _physics_process(delta: float) -> void:
	_broken = maxf(_broken - delta, 0.0)
	var solid := frozen() and _broken <= 0.0
	if solid == _ice.disabled: # freezing or thawing this frame (or you've gone through)
		if solid:
			var seg := _ice.shape as SegmentShape2D
			seg.a.y = terrain.surface_of(index)
			seg.b.y = seg.a.y
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
		return "Bore a hole in the ice with the auger" if _auger(p) else "Chop a hole in the ice"
	if clean():
		return ("Fill %s (spring water, clean)" % p.held.def.name.to_lower()) if p.held and p.held.def.capacity > 0.0 else "Drink from the spring (clean)"
	if p.held and p.held.def.capacity > 0.0:
		return "Fill %s (%s water is dirty)" % [p.held.def.name.to_lower(), kind()]
	return "Drink from the %s (dirty)" % kind()

static func _auger(p: Player) -> bool:
	return p.backpack.count_of("ice_auger") > 0 or (p.held != null and p.held.def.id == "ice_auger")

## A spring: water straight out of the ground, safe to drink.
func clean() -> bool:
	return w().get("clean", false)

func interact(p: Player) -> void:
	if frozen() and not hole_open():
		var auger := _auger(p)
		var x := clampf(p.global_position.x + p.facing * 60.0, w().x - w().half + 40.0, w().x + w().half - 40.0)
		p.work(1.2 if auger else 3.0, 0.1 if auger else 0.3, "Boring through the ice" if auger else "Chopping through the ice", func():
			hole_until = GameClock.clock.hours + HOLE_HOURS * (2.5 if auger else 1.0)
			hole_x = x
			queue_redraw()
			p.message.emit(("The auger bites through in a few turns. A clean round hole." if auger else "You chop through the ice. Black water wells up.") + ("  You could fish through it." if w().fish else "")))
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
