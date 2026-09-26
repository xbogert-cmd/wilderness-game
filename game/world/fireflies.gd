class_name Fireflies extends CPUParticles2D
## On summer nights in the valley, the meadows and the bottoms, fireflies drift and
## blink low over the grass around you. On a CanvasLayer that follows the view (so the dark
## doesn't dim them); the emitter keeps up with the camera, the flies stay where they are.

var player: Player
var camera: Camera2D

func _ready() -> void:
	amount = 46
	lifetime = 6.0
	preprocess = 6.0
	local_coords = false
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(1300, 160)
	direction = Vector2(1, -0.3)
	spread = 180.0
	initial_velocity_min = 4.0
	initial_velocity_max = 22.0
	gravity = Vector2(0, -3)
	scale_amount_min = 0.09
	scale_amount_max = 0.15
	texture = Underground.light_texture()
	var ramp := Gradient.new() # each one blinks a few times in its life
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.2, 0.42, 0.5, 0.58, 0.8, 0.88, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	color_ramp = ramp
	color = Color(0.85, 1.0, 0.45)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	z_as_relative = false
	z_index = 9
	emitting = false

const WHERE := ["valley", "meadow", "marsh", "river", "grove"]

func _process(_delta: float) -> void:
	global_position = camera.get_screen_center_position() + Vector2(0, 150) # low: over the grass round your feet
	var w := GameClock.weather
	var clock := GameClock.clock
	var summer := clock.year_pos() > 0.2 and clock.year_pos() < 0.5 # late spring through summer
	emitting = summer and clock.daylight() < 0.15 and w.precip < 0.2 and w.air_temp_c(clock) > 10.0 \
		and player.under < 0.3 and Terrain.biome(player.global_position.x) in WHERE
