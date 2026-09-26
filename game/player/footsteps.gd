class_name Footsteps extends AudioStreamPlayer2D
## Plays a surface-matched step each time the rig plants a foot.

var body: Player
var _grass := _pool("grass")
var _mud := _pool("mud")
var _snow := Sfx.pool("step_snow", Sfx.takes("step_snow", 6), 1.1, 2.5)
var _leaves := Sfx.pool("step_leaves", Sfx.takes("step_leaves", 6), 1.1, 2.5)
const LEAF_LITTER := ["valley", "grove", "river", "foothills", "meadow"] ## where autumn leaves lie

static func _pool(surface: String) -> AudioStreamRandomizer:
	var r := AudioStreamRandomizer.new()
	for i in range(1, 7):
		r.add_stream(-1, load("res://assets/audio/steps/%s_%d.wav" % [surface, i]))
	r.random_pitch = 1.12
	r.random_volume_offset_db = 2.5
	return r

func _ready() -> void:
	bus = &"SFX"
	max_distance = 2500.0

func step() -> void:
	var wet := body.wade_depth > 0.0 or body.world.terrain.water_index(body.global_position.x, 60.0) >= 0
	var yp := GameClock.clock.year_pos()
	var snow := GameClock.weather.snow_cm > 3.0 and not wet
	var leaves := not wet and not snow and yp > 0.55 and yp < 0.85 and Terrain.biome(body.global_position.x) in LEAF_LITTER
	stream = _mud if wet else (_snow if snow else (_leaves if leaves else _grass))
	pitch_scale = 1.0
	if body.underground or body.global_position.y < body.world.ground_y(body.global_position.x) - 40.0:
		pitch_scale = 0.85 # rock and hard dirt, or deck boards: no prints in the snow below
	else:
		body.world.tracks.add(body.global_position.x + body.facing * randf_range(-12.0, 12.0), "boot", body.facing)
	volume_db = -14.0 if body.crouching else (-2.0 if body.running else -7.0)
	play()

func _exit_tree() -> void:
	stop()
