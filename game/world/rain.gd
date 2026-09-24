class_name Rain extends Node2D
## Two rain sheets: a dim far one behind the gameplay plane and a near one in front.
## Parent to the camera; particles are world-space so they don't slide with it.

var near: GPUParticles2D
var far: GPUParticles2D

func _ready() -> void:
	far = _sheet(900, 0.75, 22.0, 0.3, -25)
	near = _sheet(700, 1.0, 38.0, 0.55, 30)

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

func set_weather(precip: float, wind: float) -> void:
	for p in [near, far]:
		p.emitting = precip > 0.02
		p.amount_ratio = clampf(precip, 0.0, 1.0)
		(p.process_material as ParticleProcessMaterial).direction = Vector3(wind * 0.35, 1, 0)
