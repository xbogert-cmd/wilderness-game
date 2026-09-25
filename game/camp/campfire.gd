class_name Campfire extends Node2D
## Burns fuel for heat, light and cooking. A pot of water set on a lit fire boils clean.
## Runs on game time, including catch-up for hours spent away.

const MAX_FUEL := 12.0
const START_FUEL := 0.6 ## the kindling it was built from
const BOIL_HOURS := 0.35
const HEAT_RADIUS := 320.0

var world: World
var fuel := START_FUEL
var lit := false
var pot: ItemStack
var boil := 0.0
var _light: PointLight2D
var _embers: GPUParticles2D
var _smoke: GPUParticles2D
var _sound: AudioStreamPlayer2D
var _t := 0.0

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup
	add_to_group("structure")
	add_to_group("heat")
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
	_on_tick(elapsed) # catch up on the hours nobody was watching

func to_state() -> Dictionary:
	return {"kind": "campfire", "x": global_position.x, "fuel": fuel, "lit": lit, "boil": boil,
		"pot": pot.to_dict() if pot else null}

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

func _fuel_from(p: Player) -> Array: ## [label, hours, source] of the best fuel on hand
	if p.carrying and not p.carrying.dragged():
		return ["Add %s log" % p.carrying.size, 3.0 if p.carrying.size == "short" else 5.0, "log"]
	if p.held and p.held.def.fuel_hours > 0.0:
		return ["Add %s" % p.held.def.name.to_lower(), p.held.def.fuel_hours * p.held.count, "held"]
	if p.backpack.count_of("sticks") > 0:
		return ["Add sticks from pack", Items.get_def("sticks").fuel_hours, "pack"]
	return []

## The one thing E does right now: [label, action]. Prompt and behaviour can't drift apart.
func _action(p: Player) -> Array:
	if pot and p.held == null and p.carrying == null:
		return ["Take pot", _take_pot.bind(p)]
	if pot == null and p.held and p.held.def.has("pot"):
		return ["Set pot on the fire", _set_pot.bind(p)]
	if lit and p.held and p.held.def.cooks_into != "":
		return ["Cook %s" % p.held.def.name.to_lower(), _cook.bind(p)]
	var f := _fuel_from(p)
	var can_feed := not f.is_empty() and fuel < MAX_FUEL
	if can_feed and (p.carrying or p.held):
		return [f[0], _add_fuel.bind(p, f)]
	if not lit and fuel > 0.0:
		return ["Light fire" if _lighter(p) else "Need a lighter", _light_fire.bind(p)]
	if can_feed:
		return [f[0], _add_fuel.bind(p, f)]
	return ["", Callable()]

func interact_label(p: Player) -> String:
	var status := ("burning, %.1f h fuel" % fuel) if lit else ("unlit, %.1f h fuel" % fuel)
	if pot:
		status += ", pot %s" % ("empty" if pot.water <= 0.001 else ("boiled clean" if pot.water_clean else "heating %d%%" % int(boil * 100.0)))
	var a := _action(p)
	return "%s  (%s)" % [a[0], status] if a[0] != "" else "Campfire (%s)" % status

func interact(p: Player) -> void:
	var a := _action(p)
	if a[1].is_valid():
		a[1].call()

func _lighter(p: Player) -> ItemStack:
	if p.held and p.held.def.has("lighter") and p.held.uses_left > 0:
		return p.held
	return p.backpack.find(func(s): return s.def.has("lighter") and s.uses_left > 0)

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

func _light_fire(p: Player) -> void:
	var l := _lighter(p)
	if l == null:
		p.message.emit("You need a lighter.")
		return
	l.uses_left -= 1
	lit = true
	p.message.emit("The kindling catches. (%d strikes left)" % l.uses_left)

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
	if pot:
		draw_line(Vector2(-30, -46), Vector2(30, -46), Palette.BARK_DARK, 3.0)
		draw_rect(Rect2(-16, -62, 32, 22), Color("5f5f5a"))
		if pot.water > 0.001 and lit and (boil > 0.3 or pot.water_clean):
			for i in 3:
				var y := -66.0 - fmod(_t * 30.0 + i * 12.0, 36.0)
				draw_circle(Vector2(-8 + i * 8, y), 3.0, Color(1, 1, 1, 0.35))

func _exit_tree() -> void:
	_sound.stop() # a playing stream at shutdown is reported as a leak
