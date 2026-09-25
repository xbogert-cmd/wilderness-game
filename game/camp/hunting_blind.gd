class_name HuntingBlind extends Node2D
## A low screen of woven branches. Crouched behind it you're nearly invisible and quieter,
## so deer can graze or walk right past; you can still draw a bow over it. It stands in
## front of the player (and turns see-through while you're in it, so you can see yourself).

const COVER := 75.0
const VISIBILITY := 0.12 ## multiplies the player's visibility while crouched inside
const QUIET := 0.5 ## multiplies the player's noise while crouched inside

var world: World

func _ready() -> void:
	add_to_group("persist")
	add_to_group("structure")
	add_to_group("blind")
	z_as_relative = false
	z_index = 8 # in front of the player

func load_state(d: Dictionary, _elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))
	queue_redraw()

func to_state() -> Dictionary:
	return {"kind": "blind", "x": global_position.x}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.blind.width

func hides(p: Player) -> bool:
	return p.crouching and absf(p.global_position.x - global_position.x) < COVER

static func hiding(p: Player) -> bool:
	for b: HuntingBlind in p.get_tree().get_nodes_in_group("blind"):
		if b.hides(p):
			return true
	return false

var _snowy := false

func _process(delta: float) -> void:
	if (GameClock.weather.snow_cm > 2.0) != _snowy:
		_snowy = not _snowy
		queue_redraw()
	var p: Player = get_tree().get_first_node_in_group("player")
	var inside := p and absf(p.global_position.x - global_position.x) < COVER
	modulate.a = move_toward(modulate.a, 0.55 if inside else 1.0, delta * 3.0)

func _draw() -> void:
	var half := width() * 0.5
	var stake := Palette.BARK_DARK
	for sx in [-half + 8.0, 0.0, half - 8.0]:
		draw_line(Vector2(sx, 6), Vector2(sx * 0.95, -96), stake, 5.0)
	for k in 3: # woven withies
		var y := -22.0 - k * 26.0
		draw_line(Vector2(-half, y), Vector2(half, y - 4.0), Palette.BARK, 4.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 16: # evergreen boughs stuffed into the weave
		var c := Vector2(rng.randf_range(-half + 10.0, half - 10.0), rng.randf_range(-100.0, -18.0))
		var shade := Palette.FIR_DARK.lerp(Palette.FIR_LIGHT, rng.randf())
		draw_colored_polygon(SceneryArt.blob(c, rng.randf_range(16.0, 26.0), rng, 7, 0.35), shade)
	if GameClock.weather.snow_cm > 2.0:
		for i in 5:
			var c := Vector2(-half + 18.0 + i * (half * 2.0 - 36.0) / 4.0, -104.0 + (i % 2) * 6.0)
			draw_colored_polygon(SceneryArt.blob(c, 12.0, rng, 6, 0.2), Color(0.94, 0.96, 0.99))
