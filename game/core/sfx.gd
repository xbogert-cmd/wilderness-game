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

## Takes of one sound: sfx/<name>_1.wav .. <name>_<n>.wav.
static func takes(name: String, n: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for i in range(1, n + 1):
		out.append("res://assets/audio/sfx/%s_%d.wav" % [name, i])
	return out

## An axe biting into a trunk (real strikes: close ones and a few out in the forest).
static func chop() -> AudioStream:
	return pool("chop", takes("axe", 6) + takes("axe_far", 6), 1.06, 2.0)

## Bucking a felled trunk into lengths, splitting wood.
static func split() -> AudioStream:
	return pool("split", takes("split", 3) + takes("axe", 6), 1.06, 2.0)

static func bleat() -> AudioStream:
	return pool("bleat", ["res://assets/audio/sfx/bleat_1.wav", "res://assets/audio/sfx/bleat_2.wav"], 1.05, 1.5)

static func howl() -> AudioStream:
	return pool("howl", takes("wolves", 2), 1.04, 2.0) # Yellowstone wolves

static func growl() -> AudioStream:
	return pool("growl", ["res://assets/audio/sfx/growl.wav"], 1.1, 2.0)

static func roar() -> AudioStream:
	return pool("roar", takes("grizzly", 3), 1.05, 1.0)

static func caw() -> AudioStream:
	return pool("caw", takes("raven", 3), 1.06, 2.0)

## Hooves: grass footsteps pitched up and lighter.
static func hoof() -> AudioStream:
	var paths: PackedStringArray = []
	for i in range(1, 7):
		paths.append("res://assets/audio/steps/grass_%d.wav" % i)
	return pool("hoof", paths, 1.15, 3.0)
