class_name TreeFire extends Node2D
## A tree the lightning hit: its crown burning, embers raining down, for an hour or two
## until the rain beats it out. Nothing comes of it after (the country doesn't burn), but
## while it lasts it's fire: warm yourself at it, or light a torch from the embers.
## Not saved: a strike is gone by the time you'd load.

var height := 900.0 ## the tree's
var left := 1.5 ## game hours of burning
var _t := 0.0
var _light: PointLight2D
var _embers: GPUParticles2D
var _smoke: GPUParticles2D

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("heat")
	z_as_relative = false
	z_index = 4
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
	_light.texture_scale = 7.0
	_light.color = Color(1.0, 0.55, 0.25)
	_light.position = Vector2(0, -height * 0.45)
	add_child(_light)
	_embers = _particles(Color(1.0, 0.6, 0.2), 110, 3.6, 10.0, Vector3(0, 140, 0)) # sparks falling out of the crown
	_smoke = _particles(Color(0.35, 0.35, 0.35, 0.35), 40, 5.0, 26.0, Vector3(0, -50, 0))
	GameClock.ticked.connect(_on_tick)

func _particles(c: Color, amount: int, life: float, size: float, gravity: Vector3) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.position = Vector2(0, -height * 0.72)
	p.visibility_rect = Rect2(-800, -600, 1600, height + 900)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(90, height * 0.15, 0)
	m.direction = Vector3(0, -1, 0)
	m.spread = 60.0
	m.initial_velocity_min = 20.0
	m.initial_velocity_max = 70.0
	m.gravity = gravity
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

func _on_tick(dh: float) -> void:
	left -= dh * (1.0 + 1.5 * GameClock.weather.rain()) # the rain beats it down
	if left <= 0.0:
		queue_free()

func strength() -> float:
	return clampf(left / 0.5, 0.0, 1.0)

func _process(delta: float) -> void:
	_t += delta
	var wind := GameClock.weather.wind * GameClock.weather.wind_dir
	(_embers.process_material as ParticleProcessMaterial).gravity = Vector3(wind * 90.0, 140.0, 0)
	(_smoke.process_material as ParticleProcessMaterial).gravity = Vector3(wind * 120.0, -50.0, 0)
	_embers.amount_ratio = strength()
	var dark := 1.0 - GameClock.clock.daylight() * (1.0 - GameClock.weather.cloud * 0.5)
	_light.energy = strength() * lerpf(0.3, 1.4, dark) * (1.0 + 0.2 * sin(_t * 9.0) + 0.1 * sin(_t * 21.0))
	queue_redraw()

func _draw() -> void:
	var k := strength()
	var top := -height
	var r := RandomNumberGenerator.new()
	var lean := GameClock.weather.wind * GameClock.weather.wind_dir * 25.0
	for g in 3: # the glow in the smoke round the burning crown
		draw_circle(Vector2(0, top * 0.62), (220.0 - g * 60.0) * k, Color(1.0, 0.5, 0.15, 0.06 + g * 0.04))
	for i in 16: # tongues of flame up through the crown and down the trunk, flickering
		r.seed = i * 7919
		var y := lerpf(top * 0.95, top * 0.3, r.randf())
		var x := r.randf_range(-80.0, 80.0) * clampf(1.0 - absf(y - top * 0.7) / (height * 0.45), 0.15, 1.0)
		var h := r.randf_range(60.0, 130.0) * k * (0.8 + 0.3 * sin(_t * r.randf_range(7.0, 13.0) + i))
		var wdt := r.randf_range(18.0, 34.0) * k
		_flame(Vector2(x, y), wdt, h, lean, Color(1.0, 0.42, 0.1, 0.85))
		_flame(Vector2(x, y), wdt * 0.55, h * 0.6, lean * 0.7, Color(1.0, 0.82, 0.35, 0.9))

## A tongue of flame: round at the base, drawn up to a point that leans with the wind.
func _flame(at: Vector2, wdt: float, h: float, lean: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for j in 7: # the round bottom
		pts.append(at + Vector2.from_angle(PI * j / 6.0) * wdt * Vector2(1.0, 0.7))
	pts.append(at + Vector2(-wdt * 0.6 + lean * 0.4, -h * 0.5))
	pts.append(at + Vector2(lean, -h))
	pts.append(at + Vector2(wdt * 0.6 + lean * 0.4, -h * 0.5))
	pts.reverse()
	draw_colored_polygon(pts, c)

## Warm near the foot of it, from the fire coming down.
func heat_at(p: Vector2) -> float:
	return clampf(1.0 - absf(p.x - global_position.x) / 320.0, 0.0, 1.0) * 0.6 * strength() if absf(p.y - global_position.y) < 300.0 else 0.0

func interact_pos() -> Vector2:
	return global_position

func interact_label(p: Player) -> String:
	if p.holding("torch"):
		return "The lightning-struck tree is burning"
	if p.carrying == null and (p.held == null or p.held.def.id == "sticks") and p.backpack.count_of("sticks") + (p.held.count if p.held else 0) > 0:
		return "Light a torch from the burning tree's embers"
	return "The lightning-struck tree is burning (sticks would make a torch)"

func interact(p: Player) -> void:
	if p.holding("torch") or p.carrying != null or not (p.held == null or p.held.def.id == "sticks"):
		return
	if p.held and p.held.def.id == "sticks":
		p.held.count -= 1
		if p.held.count <= 0:
			p.held = null
	elif not p.backpack.take("sticks", 1):
		return
	p.stow()
	p.held = ItemStack.make("torch", GameClock.clock.hours)
	p.message.emit("You hold a stick into the embers raining down until it catches. Fire from the sky.")
	Journal.note("sky_fire", "Lightning hit a tree near me and set its crown burning. It rained embers for an hour, and I lit a torch from them before the rain put it out.")
