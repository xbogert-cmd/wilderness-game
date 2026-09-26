class_name Campfire extends Node2D
## Burns fuel for heat, light and cooking. With a pot tripod over it, a pot of water hung
## on a lit fire boils clean.
## Runs on game time, including catch-up for hours spent away.

const MAX_FUEL := 12.0
const START_FUEL := 1.0 ## the kindling it was built from: enough to light it and boil one pot
const BOIL_HOURS := 0.35
const HEAT_RADIUS := 320.0

var world: World
var fuel := START_FUEL
var lit := false
var pot: ItemStack
var tripod := false ## built over it from the build menu; the pot hangs from it
var boil := 0.0
var _light: PointLight2D
var _embers: GPUParticles2D
var _smoke: GPUParticles2D
var _sound: AudioStreamPlayer2D
var _t := 0.0
var _smoke_mat: ParticleProcessMaterial

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup
	add_to_group("structure")
	add_to_group("heat")
	add_to_group("camp_safe") # nothing wild comes near a fire
	z_as_relative = false
	z_index = 2
	_light = PointLight2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	_light.texture = tex
	_light.texture_scale = 4.5
	_light.color = Color(1.0, 0.62, 0.3)
	_light.position = Vector2(0, -30)
	add_child(_light)
	_embers = _particles(Color(1, 0.6, 0.2), 30, 1.6, Vector2(0, -90), 3.0)
	_smoke = _particles(Color(0.55, 0.55, 0.55, 0.25), 24, 4.0, Vector2(12, -60), 14.0)
	_smoke_mat = _smoke.process_material
	_sound = AudioStreamPlayer2D.new()
	_sound.stream = load("res://assets/audio/campfire.wav")
	_sound.bus = &"SFX"
	_sound.max_distance = 1800.0
	add_child(_sound)
	GameClock.ticked.connect(_on_tick)

func _particles(c: Color, amount: int, life: float, vel: Vector2, size: float) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.position = Vector2(0, -20)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(18, 4, 0)
	m.direction = Vector3(vel.x, vel.y, 0).normalized()
	m.initial_velocity_min = vel.length() * 0.6
	m.initial_velocity_max = vel.length()
	m.spread = 20.0
	m.gravity = Vector3(8, 0, 0)
	m.scale_min = size * 0.5
	m.scale_max = size
	m.color = c
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	p.process_material = m
	add_child(p)
	return p

func load_state(d: Dictionary, elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))
	fuel = float(d.get("fuel", START_FUEL))
	lit = bool(d.get("lit", false))
	boil = float(d.get("boil", 0.0))
	pot = ItemStack.from_dict(d.pot) if d.get("pot") else null
	tripod = bool(d.get("tripod", pot != null)) # older saves had pots sitting on the fire
	_on_tick(elapsed) # catch up on the hours nobody was watching

func to_state() -> Dictionary:
	return {"kind": "campfire", "x": global_position.x, "fuel": fuel, "lit": lit, "boil": boil,
		"pot": pot.to_dict() if pot else null, "tripod": tripod}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.campfire.width

func _on_tick(dh: float) -> void:
	if not lit:
		return
	var burn := minf(dh, fuel)
	fuel -= burn
	if pot and pot.water > 0.001 and not pot.water_clean:
		boil += burn / BOIL_HOURS
		if boil >= 1.0:
			pot.water_clean = true
			boil = 0.0
	if fuel <= 0.0:
		lit = false

func _process(delta: float) -> void:
	_t += delta
	var strength := clampf(fuel / 2.0, 0.25, 1.0) if lit else 0.0
	_light.visible = lit
	var dark := 1.0 - GameClock.clock.daylight() * (1.0 - GameClock.weather.cloud * 0.5)
	_light.energy = strength * lerpf(0.12, 1.1, dark) * (1.0 + 0.14 * sin(_t * 11.0) + 0.09 * sin(_t * 23.0))
	_smoke_mat.gravity = Vector3(GameClock.weather.wind_dir * (6.0 + 40.0 * GameClock.weather.wind), 0, 0) # smoke leans downwind
	_embers.emitting = lit
	_smoke.emitting = lit or fuel > 0.0 and fuel < START_FUEL * 0.5
	if lit != _sound.playing:
		if lit: _sound.play()
		else: _sound.stop()
	queue_redraw()

func heat_at(p: Vector2) -> float:
	if not lit:
		return 0.0
	return clampf(1.0 - p.distance_to(global_position) / HEAT_RADIUS, 0.0, 1.0) * clampf(fuel / 1.5, 0.4, 1.0)

func interact_pos() -> Vector2:
	return global_position

const PILE_REACH := 450.0

## A stocked woodpile close enough to feed from without fetching.
func _woodpile() -> Woodpile:
	for w: Woodpile in get_tree().get_nodes_in_group("woodpile"):
		if w.logs > 0 and absf(w.global_position.x - global_position.x) < PILE_REACH:
			return w
	return null

## Everything E can do here, best first: [[label, action]]. An invalid action is a note.
## The first one is what a single press does, so prompt and behaviour can't drift apart.
func interact_options(p: Player) -> Array:
	var out := []
	var h := p.held
	# A bottle (in hand, or else in the pack) and the hanging pot: pour one into the other.
	var bottle: ItemStack = h if h and h != pot and h.def.capacity > 0.0 else \
		p.backpack.find(func(st): return st.def.capacity > 0.0 and not st.def.has("pot"))
	if pot and bottle:
		var bname := bottle.def.name.to_lower()
		if bottle.water > 0.001 and pot.water < pot.def.capacity - 0.01:
			out.append(["Pour the %s into the pot" % bname, _pour_in.bind(bottle, p)])
		if pot.water > 0.001 and bottle.water < bottle.def.capacity - 0.01:
			if not pot.water_clean:
				out.append(["The pot isn't boiled yet (%d%%)" % int(boil * 100.0), Callable()])
			elif bottle.water <= 0.001 or bottle.water_clean:
				out.append(["Fill the %s from the pot" % bname, _pour.bind(pot, bottle, p)])
	if pot and p.held == null and p.carrying == null:
		out.append(["Take pot", _take_pot.bind(p)])
	if pot == null and p.held and p.held.def.has("pot"):
		if tripod:
			out.append(["Hang the pot on the tripod", _set_pot.bind(p)])
		else:
			out.append(["The pot needs a tripod over the fire (build one: %s)" % Keys.label("build"), Callable()])
	if lit and p.held and p.held.def.cooks_into != "":
		out.append(["Cook %s" % p.held.def.name.to_lower(), _cook.bind(p)])
	if lit and pot and tripod: # stews and teas in the hanging pot
		for id in Builds.POT_RECIPES:
			var r: Dictionary = Builds.POT_RECIPES[id]
			if Supply.can(p, r.needs, global_position.x):
				if pot.water + 0.001 < r.water:
					out.append(["%s needs %.2f L of water in the pot" % [Items.get_def(id).name, r.water], Callable()])
				else:
					out.append(["Cook %s in the pot  (%s)" % [Items.get_def(id).name.to_lower(), Builds.needs_text(r.needs, {}).replace(" 0/", " ")], _pot_cook.bind(p, id)])
	var feeds := _fuels(p) if fuel < MAX_FUEL else []
	var in_hand := feeds.filter(func(f): return f[2] in ["log", "held"])
	for f in in_hand:
		out.append([f[0], _add_fuel.bind(p, f)])
	if not lit and fuel > 0.0:
		if p.holding("torch"):
			out.append(["Light the fire from your torch", _light_from_torch.bind(p)])
		var l := _lighter(p)
		out.append([("Strike sparks with the flint" if l.def.id == "flint" else "Light fire") if l else "Need a lighter, matches or flint", _light_fire.bind(p)])
	for f in feeds:
		if f not in in_hand:
			out.append([f[0], _add_fuel.bind(p, f)])
	if lit and p.carrying == null and (p.held == null or p.held.def.id == "sticks") and p.backpack.count_of("sticks") + (p.held.count if p.held else 0) > 0:
		out.append(["Light a torch from the fire", _torch.bind(p)])
	if lit:
		out.append(["Put the fire out", _douse.bind(p)])
	return out

func interact_title(_p: Player) -> String:
	return "Campfire (%s)" % _status()

func _status() -> String:
	var status := ("burning, %.1f h fuel" % fuel) if lit else ("unlit, %.1f h fuel" % fuel)
	if pot:
		status += ", pot %s" % ("empty" if pot.water <= 0.001 else ("boiled clean" if pot.water_clean else "heating %d%%" % int(boil * 100.0)))
	return status

func interact_label(p: Player) -> String:
	if get_tree().get_nodes_in_group("structure").any(func(s): return s is Blueprint and absf(s.global_position.x - global_position.x) < 10.0):
		return "" # a tripod blueprint sits over it: let that take the prompt
	var first := Player.first_label(interact_options(p))
	return "%s  (%s)" % [first, _status()] if first != "" else interact_title(p)

func interact(p: Player) -> void:
	Player.run_first(interact_options(p))

## Every fuel on hand, each once: [label, hours, source]. A log burns far longer than sticks.
func _fuels(p: Player) -> Array:
	var out := []
	if p.carrying and not p.carrying.dragged():
		out.append(["Add %s log" % p.carrying.size, 3.0 if p.carrying.size == "short" else 5.0, "log"])
	if p.held and p.held.def.fuel_hours > 0.0:
		out.append(["Add %s" % p.held.def.name.to_lower(), p.held.def.fuel_hours * p.held.count, "held"])
	if _woodpile() and p.carrying == null and p.held == null:
		out.append(["Add a log from the woodpile", 3.0, "pile"])
	if p.backpack.count_of("sticks") > 0:
		out.append(["Add sticks from pack", Items.get_def("sticks").fuel_hours, "pack"])
	return out

## A burning stick to carry: light in the dark, and nothing wild comes near a flame.
func _torch(p: Player) -> void:
	if p.held and p.held.def.id == "sticks":
		p.held.count -= 1
		if p.held.count <= 0:
			p.held = null
	elif not p.backpack.take("sticks", 1):
		return
	p.stow()
	p.held = ItemStack.make("torch", GameClock.clock.hours)
	p.message.emit("You light a torch from the fire.")

func _douse(p: Player) -> void:
	lit = false
	p.message.emit("You kick dirt over the fire. The fuel that's left will light again.")

func _pour(from: ItemStack, to: ItemStack, p: Player) -> void:
	var before := to.water
	var err := from.pour_into(to)
	if err != "":
		p.message.emit(err)
		return
	if to == pot and to.water > 0.0: # cold water poured in sets the boil back
		boil *= before / to.water
	p.message.emit("Poured %.2f L." % (to.water - before))

## Any water can go into the pot. Dirty mixed with clean makes it all dirty: boil it again.
func _pour_in(bottle: ItemStack, p: Player) -> void:
	if pot.water > 0.001 and pot.water_clean != bottle.water_clean:
		pot.water_clean = false
		bottle.water_clean = false
		boil = 0.0
		p.message.emit("Mixed with dirty water: the pot needs to boil again.")
	_pour(bottle, pot, p)

func _pot_cook(p: Player, id: String) -> void:
	var r: Dictionary = Builds.POT_RECIPES[id]
	Supply.gather(p, r.needs, global_position.x, func():
		p.work(r.seconds, r.hours, "Cooking " + Items.get_def(id).name.to_lower(), func():
			if pot:
				pot.water = maxf(pot.water - r.water, 0.0)
			p.receive(ItemStack.make(id, GameClock.clock.hours, r.count))
			Journal.note("cook_" + id, {"stew": "Made a stew in the pot. Hot food makes a cold night easier.",
				"mint_tea": "Brewed wild-mint tea. Good for a sick stomach.", "willow_tea": "Brewed willow bark tea for a fever."}[id])))

func _take_pot(p: Player) -> void:
	p.held = pot
	pot = null
	boil = 0.0

func _set_pot(p: Player) -> void:
	pot = p.held
	p.held = null
	boil = 0.0
	if pot.water <= 0.001:
		p.message.emit("The pot is empty. Fill it at the creek first.")

func _cook(p: Player) -> void:
	var raw := p.held
	p.held = null # it's on the fire now
	p.work(3.0, 0.3, "Cooking " + raw.def.name.to_lower(), func():
		p.receive(ItemStack.make(raw.def.cooks_into, GameClock.clock.hours, raw.count)))

## The lighter first (quickest), then matches, then flint struck on the knife.
func _lighter(p: Player) -> ItemStack:
	for id in ["lighter", "matches", "flint"]:
		if p.held and p.held.def.id == id and p.held.uses_left > 0:
			return p.held
		var s := p.backpack.find(func(s): return s.def.id == id and s.uses_left > 0)
		if s:
			return s
	return null

func _light_fire(p: Player) -> void:
	var l := _lighter(p)
	if l == null:
		p.message.emit("You need a lighter, matches or flint.")
		return
	if l.def.id == "flint":
		if not (p.holding("knife") or p.backpack.count_of("#knife") > 0):
			p.message.emit("Flint needs steel to strike on: your knife.")
			return
		p.work(2.5, 0.1, "Striking sparks", func():
			l.uses_left -= 1
			lit = true
			p.message.emit("A spark takes in the tinder. You blow it into flame. (%d strikes left in the flint)" % l.uses_left))
		return
	l.uses_left -= 1
	lit = true
	p.message.emit("The kindling catches. (%d %s left)" % [l.uses_left, "matches" if l.def.id == "matches" else "strikes"])

func _light_from_torch(_p: Player) -> void:
	lit = true

func _add_fuel(p: Player, f: Array) -> void:
	match f[2]:
		"log":
			var lg := p.carrying
			p.drop_carried()
			lg.queue_free()
		"held":
			p.held = null
		"pack":
			p.backpack.take("sticks", 1)
		"pile":
			_woodpile().take_one()
	fuel = minf(fuel + f[1], MAX_FUEL)

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 7:
		var x := lerpf(-40, 40, i / 6.0)
		draw_colored_polygon(SceneryArt.blob(Vector2(x, -4), 9.0, rng, 7, 0.2), Palette.ROCK.darkened(0.1 * (i % 2)))
	var wood := Palette.BARK.lightened(0.1)
	if fuel > 0.05:
		draw_line(Vector2(-22, -4), Vector2(6, -34), wood, 5.0)
		draw_line(Vector2(22, -4), Vector2(-6, -34), wood, 5.0)
		draw_line(Vector2(0, -2), Vector2(0, -36), wood.darkened(0.2), 5.0)
	else:
		draw_rect(Rect2(-24, -8, 48, 6), Color(0.2, 0.18, 0.16))
	if lit:
		var s := clampf(fuel / 2.0, 0.4, 1.0)
		for k in 3:
			var h := (60.0 - k * 16.0) * s * (1.0 + 0.15 * sin(_t * (9.0 + k * 3.0) + k))
			var w := (22.0 - k * 6.0) * s
			var col: Color = [Color(0.95, 0.42, 0.12), Color(1.0, 0.7, 0.25), Color(1.0, 0.92, 0.6)][k]
			draw_colored_polygon(PackedVector2Array([Vector2(-w, -4), Vector2(w, -4), Vector2(sin(_t * 7.0 + k) * 5.0, -4 - h)]), col)
	if tripod: # three poles lashed above the fire, a chain down the middle
		var top := Vector2(0, -130)
		for foot in [Vector2(-46, 2), Vector2(44, 2), Vector2(10, 0)]:
			draw_line(foot, top + Vector2(foot.x * 0.08, 0), Palette.BARK_DARK, 5.0)
		draw_line(top + Vector2(-8, 4), top + Vector2(8, -4), Color(0.3, 0.25, 0.2), 4.0)
		draw_line(top, Vector2(0, -64 if pot else -80), Color(0.35, 0.35, 0.33), 2.0)
	if pot:
		if not tripod:
			draw_line(Vector2(-30, -46), Vector2(30, -46), Palette.BARK_DARK, 3.0)
		draw_arc(Vector2(0, -62), 16.0, PI, TAU, 10, Color(0.35, 0.35, 0.33), 2.0) # bail
		draw_rect(Rect2(-16, -62, 32, 22), Color("5f5f5a"))
		if pot.water > 0.001 and lit and (boil > 0.3 or pot.water_clean):
			for i in 3:
				var y := -66.0 - fmod(_t * 30.0 + i * 12.0, 36.0)
				draw_circle(Vector2(-8 + i * 8, y), 3.0, Color(1, 1, 1, 0.35))

func _exit_tree() -> void:
	_sound.stop() # a playing stream at shutdown is reported as a leak
