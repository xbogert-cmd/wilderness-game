class_name BuildBook extends Book
## The build book (B): everything you can put up, by chapter, with a picture of it built, what
## it's for, what it takes (pack items, and logs lying close by or on your shoulder) and where
## to get what you're short of. Place the blueprint, then bring the materials and press E.

const PICTURES := "res://assets/builds/%s.png"

var build_mode: BuildMode

func title() -> String:
	return "Things to build"

func hint() -> String:
	return "Pick one, then place its blueprint on the ground  ·  %s or Esc to close" % Keys.label("build")

func chapters() -> Dictionary:
	return Builds.BUILD_GROUPS

func entry_name(id: String) -> String:
	return Builds.STRUCTURES[id].name

func closes_on(event: InputEvent) -> bool:
	return event.is_action_pressed("menu") or event.is_action_pressed("build")

func ready_now(id: String) -> bool:
	var d: Dictionary = Builds.STRUCTURES[id]
	var have := _have()
	return d.needs.keys().all(func(k): return have.get(k, 0) >= d.needs[k])

## What you could bring: pack items (and chests close by), logs lying within reach of here.
func _have() -> Dictionary:
	var have := {}
	for l in get_tree().get_nodes_in_group("log"):
		if absf(l.global_position.x - player.global_position.x) < 2500.0:
			have[l.size] = have.get(l.size, 0) + 1
	for id in Builds.STRUCTURES:
		for k in Builds.STRUCTURES[id].needs:
			if not Builds.is_log(k):
				have[k] = Supply.have(player, k, player.global_position.x)
	return have

func fill_page(id: String) -> void:
	var d: Dictionary = Builds.STRUCTURES[id]
	var pic := Book.Pic.new()
	pic.picture = load(PICTURES % id) if ResourceLoader.exists(PICTURES % id) else null
	pic.custom_minimum_size = Vector2(RIGHT.size.x - 100.0, 300)
	page().add_child(pic)
	page().add_child(ink(d.name, 32))
	var what: String = Builds.WHAT.get(id, "")
	page().add_child(ink(what.left(1).to_upper() + what.substr(1) + ".", 18, FADED))
	page().add_child(ink("What it takes", 22))
	var have := _have()
	for k in d.needs:
		page().add_child(need_row(k, have.get(k, 0), d.needs[k]))
	var note := "Takes about %s once everything's there." % RecipeBook._time(d.hours)
	if d.has("on"):
		note += " Goes over a campfire."
	elif d.has("water"):
		note += " " + BuildMode.WATER_WHERE[d.water]
	page().add_child(ink(note + " You can place it first and bring the materials after.", 16, FADED))
	add_action("Place the blueprint", true, func():
		close()
		build_mode.choose(id))
