class_name Sfx extends RefCounted
## One-shot positional sounds without per-object player nodes.

static var _pools := {}

## A cached randomizer over several takes of the same sound.
static func pool(name: String, paths: PackedStringArray, pitch := 1.1, volume_jitter := 2.0) -> AudioStreamRandomizer:
	if not _pools.has(name):
		var r := AudioStreamRandomizer.new()
		for p in paths:
			r.add_stream(-1, load(p))
		r.random_pitch = pitch
		r.random_volume_offset_db = volume_jitter
		_pools[name] = r
	return _pools[name]

## Plays at a world position and cleans itself up.
static func play_at(parent: Node, pos: Vector2, stream: AudioStream, volume_db := 0.0, pitch := 1.0, bus := &"SFX") -> void:
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	p.max_distance = 2600.0
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()

static func wings() -> AudioStream:
	return pool("wings", ["res://assets/audio/sfx/wings_1.wav", "res://assets/audio/sfx/wings_2.wav", "res://assets/audio/sfx/wings_3.wav"])

static func splash() -> AudioStream:
	return pool("splash", ["res://assets/audio/sfx/splash_1.wav", "res://assets/audio/sfx/splash_2.wav"])

static func snort() -> AudioStream:
	return pool("snort", ["res://assets/audio/sfx/snort_1.wav", "res://assets/audio/sfx/snort_2.wav"], 1.08)

static func chop() -> AudioStream:
	return pool("chop", ["res://assets/audio/sfx/chop_1.wav", "res://assets/audio/sfx/chop_2.wav", "res://assets/audio/sfx/chop_3.wav", "res://assets/audio/sfx/chop_4.wav"], 1.08, 2.5)

static func bleat() -> AudioStream:
	return pool("bleat", ["res://assets/audio/sfx/bleat_1.wav", "res://assets/audio/sfx/bleat_2.wav"], 1.05, 1.5)

static func howl() -> AudioStream:
	return pool("howl", ["res://assets/audio/sfx/howl_1.wav", "res://assets/audio/sfx/howl_2.wav"], 1.06, 2.0)

static func growl() -> AudioStream:
	return pool("growl", ["res://assets/audio/sfx/growl.wav"], 1.1, 2.0)

static func roar() -> AudioStream:
	return pool("roar", ["res://assets/audio/sfx/roar.wav"], 1.05, 1.0)

static func caw() -> AudioStream:
	return pool("caw", ["res://assets/audio/sfx/caw_1.wav", "res://assets/audio/sfx/caw_2.wav"], 1.1, 2.0)

## Hooves: grass footsteps pitched up and lighter.
static func hoof() -> AudioStream:
	var paths: PackedStringArray = []
	for i in range(1, 7):
		paths.append("res://assets/audio/steps/grass_%d.wav" % i)
	return pool("hoof", paths, 1.15, 3.0)
