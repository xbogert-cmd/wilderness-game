class_name Cabin extends Node2D
## A small log cabin: the long build. Keeps off rain and snow like the lean-to, and its walls
## hold warmth, so it's the best place to sleep. Building or sleeping in it makes it camp.

const COVER := 170.0
const WARMTH := 0.45 ## at most, felt like standing near a fire (heat_at scale)
const HOLDS_C := 12.0 ## the walls keep it about this warm inside; no extra heat on mild days

var world: World
var _snow_drawn := -1.0
var _lamp: PointLight2D ## the window's glow: drawn colours alone are dimmed by the night tint

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup
	add_to_group("structure")
	add_to_group("shelter")
	add_to_group("heat")
	z_as_relative = false
	z_index = 2
	_lamp = PointLight2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	_lamp.texture = tex
	_lamp.texture_scale = 2.2
	_lamp.color = Color(1.0, 0.7, 0.38)
	_lamp.position = Vector2(108, -128)
	add_child(_lamp)

func load_state(d: Dictionary, _elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))
	if d.get("fresh", false):
		var p: Player = get_tree().get_first_node_in_group("player")
		p.camp_x = global_position.x
		p.message.emit("The cabin is finished. Four walls and a roof: this is home now.")
		p.made_camp.emit()

func to_state() -> Dictionary:
	return {"kind": "cabin", "x": global_position.x}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.cabin.width

func covers(x: float) -> bool:
	return absf(x - global_position.x) < COVER

func heat_at(p: Vector2) -> float:
	if not covers(p.x) or absf(p.y - global_position.y) > 300.0:
		return 0.0
	var outside := GameClock.weather.air_temp_c(GameClock.clock)
	return clampf((HOLDS_C - outside) / GameClock.tuning.fire_heat_c, 0.0, WARMTH)

func interact_pos() -> Vector2:
	return global_position

func prompt_point(_p: Player) -> Vector2:
	return global_position + Vector2(0, -330)

func interact_label(p: Player) -> String:
	var q := p.sleep_quality()
	return "Sleep in the cabin  (%s rest%s)" % ["good" if q > 0.75 else ("fair" if q > 0.5 else "poor"), "" if p.backpack.count_of("sleeping_bag") > 0 else ", no sleeping bag"]

func interact(p: Player) -> void:
	p.camp_x = global_position.x
	p.sleep()

var _night_drawn := -1.0

func _process(_delta: float) -> void:
	var cm := GameClock.weather.snow_cm
	var night := 1.0 - GameClock.clock.daylight()
	if absf(cm - _snow_drawn) > 1.0 or (cm == 0.0 and _snow_drawn != 0.0) or absf(night - _night_drawn) > 0.05:
		_snow_drawn = cm
		_night_drawn = night
		_lamp.energy = night * 0.9
		_lamp.visible = night > 0.05
		queue_redraw()

## Gable end toward the viewer: stacked log courses with round ends at the corners, a
## door, a small window that glows at night, and a pitched roof that holds snow.
func _draw() -> void:
	var half := 190.0
	var wall := 200.0
	var log_h := 25.0
	var bark := Palette.BARK
	var rng := RandomNumberGenerator.new() # a footing of stacked stones, for sloped ground
	rng.seed = 11
	for row in 2:
		var sx := -half - 4.0 + row * 14.0
		while sx < half:
			draw_colored_polygon(SceneryArt.blob(Vector2(sx, 6.0 + row * 20.0), 13.0, rng, 7, 0.2), Palette.ROCK.darkened(0.15 + 0.1 * rng.randf()))
			sx += 26.0
	for i in int(wall / log_h):
		var y := -log_h * (i + 0.5)
		var c := bark.lightened(0.08) if i % 2 == 0 else bark.darkened(0.05)
		draw_rect(Rect2(-half, y - log_h * 0.5, half * 2.0, log_h), c)
		draw_line(Vector2(-half, y + log_h * 0.5), Vector2(half, y + log_h * 0.5), Palette.BARK_DARK, 2.0)
		for sx in [-half - 6.0, half + 6.0]: # log ends at the corners
			draw_circle(Vector2(sx, y), log_h * 0.52, bark.darkened(0.2))
			draw_circle(Vector2(sx, y), log_h * 0.36, Color("cfae7e"))
	# Gable, then the roof laid right on its sloped edges and overhanging the walls.
	var rise := 120.0
	var peak := Vector2(0, -wall - rise)
	draw_colored_polygon(PackedVector2Array([Vector2(-half, -wall), Vector2(half, -wall), peak]), bark.darkened(0.12))
	var over := 34.0 # eave overhang
	var slope := rise / half
	var eave_l := Vector2(-half - over, -wall + over * slope)
	var eave_r := Vector2(half + over, -wall + over * slope)
	var t := 18.0 # roof thickness
	draw_colored_polygon(PackedVector2Array([eave_l, peak, eave_r, eave_r + Vector2(0, -t), peak + Vector2(0, -t * 1.15), eave_l + Vector2(0, -t)]), Palette.BARK_DARK)
	for k in 4: # purlin ends under the eaves
		var f := (k + 1) / 5.0
		for side in [-1.0, 1.0]:
			draw_circle(Vector2(side * half * (1.0 - f), -wall - rise * f + 4.0), 5.0, bark.darkened(0.3))
	var snow := clampf(GameClock.weather.snow_cm, 0.0, 30.0)
	if snow > 0.5:
		var top_l := eave_l + Vector2(0, -t)
		var top_r := eave_r + Vector2(0, -t)
		var top_p := peak + Vector2(0, -t * 1.15)
		draw_colored_polygon(PackedVector2Array([top_l, top_p, top_r, top_r + Vector2(0, -snow), top_p + Vector2(0, -snow * 1.1), top_l + Vector2(0, -snow)]), Color(0.94, 0.96, 0.99))
	draw_rect(Rect2(-40, -120, 80, 120), Color(0.14, 0.1, 0.08)) # door
	draw_rect(Rect2(-40, -120, 80, 120), Palette.BARK_DARK, false, 4.0)
	var night := 1.0 - GameClock.clock.daylight()
	draw_rect(Rect2(80, -150, 56, 44), Color(0.1, 0.09, 0.08).lerp(Color(1.0, 0.72, 0.38), night * 0.85)) # window
	draw_rect(Rect2(80, -150, 56, 44), Palette.BARK_DARK, false, 4.0)
	draw_line(Vector2(108, -150), Vector2(108, -106), Palette.BARK_DARK, 3.0)
