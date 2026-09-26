class_name DebugOverlay extends Label
## F3: survival state, time/weather, streamed chunks.

var player: Player
var world: World

func _ready() -> void:
	visible = false
	position = Vector2(12, 12)
	add_theme_font_size_override("font_size", 15)
	add_theme_color_override("font_shadow_color", Color.BLACK)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug"):
		visible = not visible

func _animals() -> String:
	var parts: PackedStringArray = []
	for a in get_tree().get_nodes_in_group("animals"):
		var d: float = a.position.x - player.global_position.x
		if absf(d) < 3000.0:
			parts.append("%s %s %+.0f aware %.2f" % [a.def.name, Animal.STATE_NAMES[a.state], d, a.awareness])
	return "Animals: " + ("  |  ".join(parts) if parts else "none near")

func _process(_delta: float) -> void:
	if not visible:
		return
	var c := GameClock.clock
	var w := GameClock.weather
	var k := player.cond
	text = "\n".join([
		"FPS %d" % Engine.get_frames_per_second(),
		"Day %d  %02d:%02d  %s" % [c.day() + 1, int(c.hour_of_day()), int(fmod(c.hour_of_day(), 1.0) * 60), c.season_name()],
		"Weather %s -> %s in %.1fh%s  cloud %.2f rain %.2f wind %.2f" % [Weather.NAMES[w.kind], Weather.NAMES[w.next_kind], w.hours_left, "  [WARNING]" if w.storm_warning() else "", w.cloud, w.precip, w.wind],
		"Air %.1f°C  fog %.2f  flood %.2f (%d)  ice %.2f  chinook %.1fh  breakup %.1fh%s" % [w.air_temp_c(c), w.fog, w.flood, w.floods, w.ice, w.chinook, w.breakup, "  THUNDER" if w.thunder else ""],
		"HP %.0f  STA %.0f  FOOD %.0f  WATER %.0f  WARM %.0f  WET %.2f" % [k.health, k.stamina, k.hunger, k.thirst, k.warmth, k.wetness],
		"Injuries %s" % str(k.injuries),
		"Pos %.0f, %.0f  wade %.0f  chunks %s" % [player.global_position.x, player.global_position.y, player.wade_depth, str(world.chunks.keys())],
		"Noise %.2f  visibility %.2f  tracks %d" % [player.noise(), player.visibility(), world.tracks.prints.size()],
		_animals(),
	])
