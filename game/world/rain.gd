class_name Rain extends Node2D
## Two rain sheets: a dim far one behind the gameplay plane and a near one in front.
## Snow uses two slow, drifting flake sheets the same way.
## Parent to the camera; particles are world-space so they don't slide with it.

var near: GPUParticles2D
var far: GPUParticles2D
var flakes_near: GPUParticles2D
var flakes_far: GPUParticles2D

func _ready() -> void:
	far = _sheet(900, 0.75, 22.0, 0.3, -25)
	near = _sheet(700, 1.0, 38.0, 0.55, 30)
	flakes_far = _flakes(1400, 3.0, 0.55, -25)
	flakes_near = _flakes(700, 5.5, 0.9, 30)

func _flakes(amount: int, size: float, alpha: float, z: int) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.position = Vector2(0, -1000)
	p.z_index = z
	p.z_as_relative = false
	p.visibility_rect = Rect2(-2200, -200, 4400, 2600)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(2000, 10, 0)
	m.direction = Vector3(0, 1, 0)
	m.spread = 25.0 # each flake drifts at its own slant
	m.initial_velocity_min = 110.0 + size * 10.0
	m.initial_velocity_max = 170.0 + size * 14.0
	m.gravity = Vector3.ZERO
	m.scale_min = 0.6
	m.scale_max = 1.0
	p.process_material = m
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, alpha))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = int(size * 2.0)
	tex.height = int(size * 2.0)
	p.texture = tex
	p.emitting = false
	add_child(p)
	return p

func _sheet(amount: int, speed: float, length: float, alpha: float, z: int) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = amount
	p.lifetime = 0.9
	p.local_coords = false
	p.position = Vector2(0, -900)
	p.z_index = z
	p.z_as_relative = false
	p.visibility_rect = Rect2(-2000, -200, 4000, 2400)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(1700, 10, 0)
	m.direction = Vector3(0, 1, 0)
	m.spread = 2.0
	m.initial_velocity_min = 1700.0 * speed
	m.initial_velocity_max = 2000.0 * speed
	m.gravity = Vector3.ZERO
	m.particle_flag_align_y = true
	p.process_material = m
	var g := Gradient.new()
	g.set_color(0, Color(0.8, 0.85, 0.9, 0.0))
	g.set_color(1, Color(0.8, 0.85, 0.9, alpha))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 2
	tex.height = int(length)
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	p.texture = tex
	add_child(p)
	return p

func set_weather(rain: float, snow: float, wind: float) -> void:
	for p in [near, far]:
		p.emitting = rain > 0.02
		p.amount_ratio = clampf(rain, 0.0, 1.0)
		(p.process_material as ParticleProcessMaterial).direction = Vector3(wind * 0.35 * GameClock.weather.wind_dir, 1, 0)
	for p in [flakes_near, flakes_far]:
		if snow > 0.02 and not p.emitting:
			p.restart() # fill the sky at once (preprocess) instead of waiting for flakes to fall in
		p.emitting = snow > 0.02
		p.amount_ratio = clampf(snow * 1.2, 0.0, 1.0)
		(p.process_material as ParticleProcessMaterial).direction = Vector3(wind * 1.1 * GameClock.weather.wind_dir, 1, 0)
