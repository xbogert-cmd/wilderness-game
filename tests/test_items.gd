extends RefCounted

var t

func test_rotation_changes_footprint() -> void:
	var def := Items.get_def("axe") # 1x3 vertical
	var cells := Backpack.cells(def, true)
	var xs := cells.map(func(c): return c.x)
	var ys := cells.map(func(c): return c.y)
	t.ok(xs.max() == 2 and ys.max() == 0, "rotated axe is 3x1: %s" % str(cells))

func test_place_and_collide() -> void:
	var b := Backpack.new()
	var pot := ItemStack.make("cook_pot")
	var bottle := ItemStack.make("water_bottle")
	t.ok(b.place(pot, Vector2i(0, 0), false), "pot placed")
	t.ok(not b.place(bottle, Vector2i(1, 1), false), "overlap refused")
	t.ok(b.place(bottle, Vector2i(2, 0), false), "free spot ok")
	t.ok(not b.fits(bottle, Vector2i(5, 6), false), "out of bounds refused")
	t.ok(b.entry_at(Vector2i(1, 1)).stack == pot, "cell lookup")

func test_rotation_makes_it_fit() -> void:
	var b := Backpack.new()
	var axe := ItemStack.make("axe")
	# Fill column 0..5 of the bottom row region so only a horizontal slot remains at y=6.
	for x in Backpack.W:
		for y in Backpack.H - 1:
			b.place(ItemStack.make("lighter"), Vector2i(x, y), false)
	t.ok(not b.fits(axe, Vector2i(0, 6), false), "vertical axe doesn't fit")
	t.ok(b.fits(axe, Vector2i(0, 6), true), "rotated axe fits")
	t.ok(b.add(axe), "auto-pack finds rotation")

func test_stacking_and_take() -> void:
	var b := Backpack.new()
	b.add(ItemStack.make("sticks", 0.0, 4))
	b.add(ItemStack.make("sticks", 0.0, 4))
	t.ok(b.count_of("sticks") == 8, "count across stacks")
	t.ok(b.entries.size() == 2, "overflow made a second stack (max 6)")
	t.ok(b.take("sticks", 7), "take across stacks")
	t.ok(b.count_of("sticks") == 1 and b.entries.size() == 1, "emptied stack removed")
	t.ok(not b.take("sticks", 2), "can't take more than held")
	t.ok(b.count_of("sticks") == 1, "failed take changes nothing")

func test_attachments() -> void:
	var b := Backpack.new()
	t.ok(b.attach(ItemStack.make("axe"), 0), "axe attaches")
	t.ok(not b.attach(ItemStack.make("water_bottle"), 1), "bottle doesn't attach")
	t.ok(b.count_of("axe") == 1, "attachments count as carried")

func test_spoilage_stages() -> void:
	var s := ItemStack.make("berries", 100.0)
	t.ok(s.freshness(110.0) == ItemStack.Fresh.FRESH, "fresh")
	t.ok(s.freshness(130.0) == ItemStack.Fresh.STALE, "stale at half life")
	t.ok(s.freshness(150.0) == ItemStack.Fresh.SPOILED, "spoiled")
	t.ok("Spoiled" in s.label(150.0), "label shows spoilage")
	t.ok(ItemStack.make("sticks").freshness(9999.0) == ItemStack.Fresh.FRESH, "non-food never spoils")

func test_water_never_mixes() -> void:
	var bottle := ItemStack.make("water_bottle")
	var pot := ItemStack.make("cook_pot")
	t.near(bottle.add_water(0.5, true), 0.5, "fill clean")
	t.near(bottle.add_water(0.3, false), 0.0, "dirty into clean refused")
	t.near(pot.add_water(5.0, false), 1.5, "pot fills to capacity")
	t.ok(pot.pour_into(bottle) != "", "pouring dirty into clean bottle refused")
	t.near(bottle.water, 0.5, "bottle unchanged")
	bottle.water = 0.0
	t.ok(pot.pour_into(bottle) == "", "pour into empty bottle ok")
	t.ok(not bottle.water_clean and is_equal_approx(bottle.water, 1.0), "bottle now holds dirty 1 L")
	t.near(pot.water, 0.5, "remainder stays in pot")

func test_pack_roundtrip() -> void:
	var b := Backpack.new()
	var bottle := ItemStack.make("water_bottle", 5.0)
	bottle.add_water(0.7, false)
	b.place(bottle, Vector2i(3, 2), true)
	b.attach(ItemStack.make("knife"), 1)
	var c := Backpack.new()
	c.from_dict(JSON.parse_string(JSON.stringify(b.to_dict())))
	var e := c.entry_at(Vector2i(3, 2))
	t.ok(not e.is_empty() and e.rot and not e.stack.water_clean, "entry, rotation and water restored")
	t.ok(c.attachments[1] != null and c.attachments[1].def.id == "knife", "attachment restored")

func test_encumbrance() -> void:
	var b := Backpack.new()
	t.near(b.encumbrance_mult(), 1.0, "empty pack no penalty")
	var heavy := ItemStack.make("cook_pot")
	heavy.water = 20.0 # 20.7 kg total: 6.7 over comfort
	b.add(heavy)
	t.near(b.encumbrance_mult(), 1.0 - 6.7 / 20.0, "linear penalty", 0.01)
	heavy.water = 100.0
	t.near(b.encumbrance_mult(), 0.6, "penalty floored")
