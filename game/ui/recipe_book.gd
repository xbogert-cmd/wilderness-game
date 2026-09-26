class_name RecipeBook extends Book
## The recipe book: E at the workbench (or from the pack). Every recipe you know, by chapter;
## pick one to see what it makes, what it takes (the pack and chests close by count), and where
## to get anything you're short of. Bench recipes need a workbench close by.

func _ready() -> void:
	super()
	add_to_group("recipe_book")

func title() -> String:
	return "Recipes"

func hint() -> String:
	return "Pick a recipe  ·  %s or Esc to close" % Keys.label("interact")

func chapters() -> Dictionary:
	var out := {}
	for ch in Builds.GROUPS:
		var ids: Array = Builds.GROUPS[ch].filter(func(id): return id in player.known_recipes)
		if ids:
			out[ch] = ids
	return out

func entry_name(id: String) -> String:
	return Items.get_def(id).name

func closes_on(event: InputEvent) -> bool:
	return event.is_action_pressed("menu") or event.is_action_pressed("interact") or event.is_action_pressed("backpack")

func ready_now(id: String) -> bool:
	var r: Dictionary = Builds.RECIPES[id]
	return Supply.can(player, r.needs, Workbench.station_x(player)) and _bench_ok(r)

func _bench_ok(r: Dictionary) -> bool:
	return not r.get("bench", false) or Workbench.near(player)

func fill_page(id: String) -> void:
	var r: Dictionary = Builds.RECIPES[id]
	var d := Items.get_def(id)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	var pic := Book.Pic.new()
	pic.key = id
	pic.custom_minimum_size = Vector2(150, 150)
	head.add_child(pic)
	var col := VBoxContainer.new()
	var name_l := ink(d.name + ("  ×%d" % r.count if r.get("count", 1) > 1 else ""), 32)
	name_l.custom_minimum_size.x = RIGHT.size.x - 290.0
	col.add_child(name_l)
	var desc := ink(d.description, 17, FADED)
	desc.custom_minimum_size.x = RIGHT.size.x - 290.0
	col.add_child(desc)
	if d.slot != "":
		col.add_child(ink("Worn: +%d °C" % int(d.warmth_c), 17, FADED))
	head.add_child(col)
	page().add_child(head)
	page().add_child(ink("What it takes", 22))
	var station := Workbench.station_x(player)
	var ok := true
	for k in r.needs:
		var have := Supply.have(player, k, station)
		ok = ok and have >= r.needs[k]
		page().add_child(need_row(k, have, r.needs[k]))
	var bench: bool = r.get("bench", false)
	var where := "at a workbench" if bench else "anywhere, in your hands"
	page().add_child(ink("Takes %s, %s. The pack and any chest close by count." % [_time(r.hours), where], 16, FADED))
	var text := "Make it"
	if not _bench_ok(r):
		text = "Needs a workbench close by"
	elif not ok:
		text = "Missing makings"
	add_action(text, ok and _bench_ok(r), func():
		close()
		RecipeBook.craft(player, id))

static func _time(h: float) -> String:
	return "%d minutes" % roundi(h * 60.0) if h < 1.0 else ("%s hours" % str(snappedf(h, 0.5)).trim_suffix(".0") if h != 1.0 else "an hour")

## Pulls the makings from the pack and any chests nearby (walking over to fetch them), then works.
static func craft(p: Player, id: String) -> void:
	var r: Dictionary = Builds.RECIPES[id]
	Supply.gather(p, r.needs, Workbench.station_x(p), func():
		p.work(r.seconds, r.hours, "Crafting " + Items.get_def(id).name.to_lower(), func():
			p.receive(ItemStack.make(id, GameClock.clock.hours, r.get("count", 1)))))
