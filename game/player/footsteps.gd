class_name Footsteps extends AudioStreamPlayer2D
## Plays a surface-matched step each time the rig plants a foot.

var body: Player
var _grass := _pool("grass")
var _mud := _pool("mud")

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
	var wet := body.wade_depth > 0.0 or absf(body.global_position.x - Terrain.CREEK_X) < Terrain.CREEK_HALF + 60.0
	stream = _mud if wet else _grass
	volume_db = -14.0 if body.crouching else (-2.0 if body.running else -7.0)
	play()

func _exit_tree() -> void:
	stop()
