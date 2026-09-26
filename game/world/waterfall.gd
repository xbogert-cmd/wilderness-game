class_name Waterfall extends Node2D
## The falls below the basin rim: the tarn's outlet pours over a cliff just behind the
## gameplay plane into the Falls Pool, which you can wade, drink from and fish. The cliff and
## the falling water sit behind everything; spray drifts across in front.

const LIP := -1150.0 ## where the water leaves the cliff, above the pool
const HALF := 70.0 ## half-width of the falling water at the lip

var terrain: Terrain
var _mist: CPUParticles2D
var _t := 0.0

func _ready() -> void:
	var i := terrain.water_index(Terrain.FALLS_X)
	position = Vector2(Terrain.FALLS_X, terrain.surface_of(i, false))
	z_as_relative = false
	z_index = -14 # behind the trees along the plane
	_mist = CPUParticles2D.new()
	_mist.amount = 40
	_mist.lifetime = 3.0
	_mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_mist.emission_rect_extents = Vector2(140, 10)
	_mist.direction = Vector2(0, -1)
	_mist.spread = 60.0
	_mist.initial_velocity_min = 30.0
	_mist.initial_velocity_max = 90.0
	_mist.gravity = Vector2(20, -10)
	_mist.scale_amount_min = 0.5
	_mist.scale_amount_max = 1.4
	_mist.color = Color(0.92, 0.95, 1.0, 0.22)
	_mist.texture = Underground.light_texture() # soft round puffs
	_mist.z_as_relative = false
	_mist.z_index = 6 # spray drifts in front of you at the pool
	_mist.position = Vector2(0, -10)
	add_child(_mist)
	add_to_group("landmark")

func _process(delta: float) -> void:
	_t += delta
	var frozen := GameClock.weather.ice > 0.85
	_mist.emitting = not frozen
	var cam := get_viewport().get_camera_2d()
	if cam and absf(cam.get_screen_center_position().x - global_position.x) < 2600.0:
		queue_redraw()
	var p: Player = get_tree().get_first_node_in_group("player")
	if p and absf(p.global_position.x - global_position.x) < 900.0:
		Journal.note("falls", "The tarn's outlet goes over the basin rim in a long white fall into a deep pool. Below it the country drops into big timber, dark and wet.")

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	# The cliff: a ragged wall of dark rock with ledges, wet near the water.
	var cliff := PackedVector2Array([Vector2(-760, 1600)]) # down behind the ground: no edge shows below the pool
	for k in 13:
		var x := -700.0 + k * 115.0
		cliff.append(Vector2(x, LIP - 140.0 - absf(sin(k * 1.7)) * 220.0 + rng.randf_range(-40, 40) + absf(x) * 0.25))
	cliff.append(Vector2(760, 1600))
	draw_colored_polygon(cliff, Color("4a4a48"))
	for k in 9:
		var y := LIP + 60.0 + k * 120.0
		draw_line(Vector2(-rng.randf_range(300, 600), y), Vector2(rng.randf_range(300, 600), y + rng.randf_range(-20, 20)), Color("3a3a38"), 5.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-HALF - 50, LIP), Vector2(HALF + 50, LIP), Vector2(HALF + 110, 20), Vector2(-HALF - 110, 20)]), Color("2e3634")) # wet rock
	var frozen := GameClock.weather.ice > 0.85
	var sheet := Color(0.85, 0.92, 0.96, 0.95) if not frozen else Color(0.82, 0.9, 0.96)
	draw_colored_polygon(PackedVector2Array([Vector2(-HALF, LIP), Vector2(HALF, LIP), Vector2(HALF + 45, 0), Vector2(-HALF - 45, 0)]), Color(sheet, 0.75))
	if frozen: # hung up in icicles
		for k in 12:
			var x := -HALF + k * 12.0
			draw_line(Vector2(x, LIP), Vector2(x * 1.3, -rng.randf_range(40, 300)), Color(0.7, 0.8, 0.9), 5.0)
		return
	for k in 16: # streaks racing down
		var x := -HALF + 6.0 + k * (HALF * 2.0 - 12.0) / 15.0
		var speed := 900.0 + (k * 37 % 5) * 90.0
		var phase := fposmod(_t * speed + k * 211.0, 260.0)
		var y := LIP + phase
		while y < 0.0:
			var t := (y - LIP) / -LIP
			draw_line(Vector2(x * (1.0 + t * 0.6), y), Vector2(x * (1.0 + t * 0.6), minf(y + 90.0, 0.0)), Color(1, 1, 1, 0.55), 3.0)
			y += 260.0
	draw_colored_polygon(Transform2D(0.0, Vector2(1, 0.3), 0.0, Vector2(0, -6)) * SceneryArt.blob(Vector2.ZERO, 170.0, rng, 12, 0.2), Color(1, 1, 1, 0.55)) # the churn where it lands
