class_name Shadows extends Node2D
## A soft shadow on the ground under you, the animals, the trees you can fell and
## everything built, thrown away from the sun and longer when it's low. One node draws them all.

var world: World
var player: Player

func _ready() -> void:
	z_as_relative = false
	z_index = 2 # on the ground, under everything standing on it

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if player.under > 0.5:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var cx := cam.get_screen_center_position().x
	var reach := 1300.0 / cam.zoom.x
	var sun := Atmosphere.sun_k
	var low := absf(Atmosphere.sun_dir) # far over to one side: low, and the shadows long
	var lean := -Atmosphere.sun_dir # shadows fall away from the sun
	var a := 0.12 + 0.2 * sun
	for g in ["player", "animals", "predators", "small_game", "structure", "choppable"]:
		for n: Node2D in get_tree().get_nodes_in_group(g):
			var x := n.global_position.x
			if absf(x - cx) > reach or not n.visible:
				continue
			var w := 46.0
			if n.has_method("width"):
				w = n.width()
			elif "def" in n and n.def is SpeciesDef:
				w = 120.0 * n.def.size
			elif n is ChoppableTree:
				if n.felled:
					continue
				w = n.height * 0.2
			var ground := world.terrain.height_at(x)
			if world.terrain.water_surface_at(x) != INF:
				continue # (none on the water)
			var lift := clampf((ground - n.global_position.y) / 220.0, 0.0, 1.0) # up off the ground: fainter
			if lift >= 1.0:
				continue
			var stretch := 1.0 + 0.9 * sun * low
			var c := Vector2(x + lean * w * 0.35 * sun, ground + 4.0)
			var r := Vector2(w * 0.55 * stretch, clampf(w * 0.09, 5.0, 14.0))
			for k in 3: # soft edge: three rings
				var s := 1.0 - k * 0.22
				draw_set_transform(c, 0.0, Vector2(r.x * s, r.y * s))
				draw_circle(Vector2.ZERO, 1.0, Color(0, 0, 0, a * 0.4 * (1.0 - lift)))
	draw_set_transform_matrix(Transform2D.IDENTITY)
