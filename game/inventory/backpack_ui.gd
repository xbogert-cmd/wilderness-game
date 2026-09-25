class_name BackpackUI extends Control
## Tab: the pack, fully paused. Drag items to rearrange (R rotates while dragging), onto the
## exterior slots, into your hands, or off the panel to drop them. Click to select for actions.
## Also shows every condition and the recipes you know.

const CELL := 56.0
const GRID_POS := Vector2(60, 110)
const SLOT_SIZE := Vector2(CELL * 1.2, CELL * 3.2)
const TEXT := Color(0.93, 0.9, 0.83)
const PANEL := Color(0.09, 0.1, 0.09, 0.93)

var player: Player
var selected: ItemStack
var _drag: Dictionary = {} ## {stack, rot, grab: Vector2 cell offset, moved}
var _press_pos := Vector2.ZERO
var _side: VBoxContainer
var _info: Label
var _actions: VBoxContainer
var _status: Label
var _font: Font

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_font = get_theme_default_font()
	_side = VBoxContainer.new()
	_side.position = Vector2(_panel_right() + 40.0, 110)
	_side.custom_minimum_size = Vector2(430, 0)
	_side.add_theme_constant_override("separation", 8)
	add_child(_side)
	_info = _label(16)
	_actions = VBoxContainer.new()
	_side.add_child(_actions)
	_status = _label(15)

func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(430, 0)
	_side.add_child(l)
	return l

func _panel_right() -> float:
	return GRID_POS.x + Backpack.W * CELL + 40.0 + SLOT_SIZE.x + 20.0

func _slot_rect(i: int) -> Rect2:
	return Rect2(GRID_POS + Vector2(Backpack.W * CELL + 30.0, i * (SLOT_SIZE.y + 16.0)), SLOT_SIZE)

func _hands_rect() -> Rect2:
	return Rect2(GRID_POS + Vector2(0, Backpack.H * CELL + 30.0), Vector2(CELL * 3, CELL * 2))

func _panel_rect() -> Rect2:
	var right := maxf(_panel_right() + 470.0, _side.position.x + _side.size.x + 30.0) # grows to fit the side text
	return Rect2(GRID_POS - Vector2(30, 70), Vector2(right - GRID_POS.x + 30.0, Backpack.H * CELL + 260.0))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("backpack") or (visible and event.is_action_pressed("menu")):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and _drag and event.is_action_pressed("rotate_item"):
		_drag.rot = not _drag.rot
		queue_redraw()

func toggle() -> void:
	if not visible and (player.working > 0.0 or player.placing):
		return
	visible = not visible
	get_tree().paused = visible
	_drag = {}
	_refresh()

func _cell_at(p: Vector2) -> Vector2i:
	var c := (p - GRID_POS) / CELL
	return Vector2i(floori(c.x), floori(c.y))

func _in_grid(p: Vector2) -> bool:
	return Rect2(GRID_POS, Vector2(Backpack.W, Backpack.H) * CELL).has_point(p)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		elif _drag:
			_release(event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		if _drag and event.position.distance_to(_press_pos) > 6.0:
			_drag.moved = true
		queue_redraw()

func _press(p: Vector2) -> void:
	_press_pos = p
	var hit := _stack_at(p)
	if hit:
		_drag = {"stack": hit.stack, "rot": hit.rot, "grab": hit.grab, "moved": false}
		selected = hit.stack
		_refresh()

## Whatever sits under p: {stack, rot, grab} or {}.
func _stack_at(p: Vector2) -> Dictionary:
	var hit := {}
	if _in_grid(p):
		var e := player.backpack.entry_at(_cell_at(p))
		if e:
			hit = {"stack": e.stack, "rot": e.rot, "grab": Vector2(_cell_at(p) - e.pos)}
	for i in Backpack.ATTACH_SLOTS:
		if _slot_rect(i).has_point(p) and player.backpack.attachments[i]:
			hit = {"stack": player.backpack.attachments[i], "rot": false, "grab": Vector2.ZERO}
	if _hands_rect().has_point(p) and player.held:
		hit = {"stack": player.held, "rot": false, "grab": Vector2.ZERO}
	return hit

func _release(p: Vector2) -> void:
	var s: ItemStack = _drag.stack
	if not _drag.moved:
		_drag = {}
		queue_redraw()
		return
	var b := player.backpack
	var from_hands := player.held == s
	if _in_grid(p):
		var pos := _cell_at(p) - Vector2i(_drag.grab)
		if b.fits(s, pos, _drag.rot, s):
			if from_hands:
				player.held = null
				player.held_slot = -1
			b.place(s, pos, _drag.rot)
	elif _hands_rect().has_point(p):
		player.hold(s)
	else:
		var slot := -1
		for i in Backpack.ATTACH_SLOTS:
			if _slot_rect(i).has_point(p):
				slot = i
		if slot >= 0:
			if from_hands and b.attachments[slot] == null and s.def.has("attachable"):
				player.held = null
				player.held_slot = -1
			b.attach(s, slot)
		elif not _panel_rect().has_point(p):
			player.drop_stack(s)
			selected = null
	_drag = {}
	_refresh()

# --- Side panel ----------------------------------------------------------------

func _refresh() -> void:
	queue_redraw()
	for c in _actions.get_children():
		c.queue_free()
	var now := GameClock.clock.hours
	if selected and not (player.backpack.contains(selected) or player.held == selected):
		selected = null
	if selected:
		var d := selected.def
		_info.text = "%s\n%s\nWeight %.1f kg" % [selected.label(now), d.description, selected.weight()]
		if d.has("tool"):
			_info.text += "\nEdge %d%% · Condition %d%%" % [int(selected.sharpness * 100), int(selected.condition * 100)]
		if player.held != selected:
			_button("Hold in hands", func(): player.hold(selected))
		if d.has("food"):
			_button("Eat", func(): _use_now())
		var creek := Creek.reachable(player)
		if d.capacity > 0.0 and creek and not (Creek.frozen() and not creek.hole_open()):
			_button("Fill at the creek", func(): creek.fill(player, selected); _refresh())
		if d.capacity > 0.0 and selected.water > 0.001:
			_button("Drink", func(): _use_now())
			_button("Empty it out", func(): selected.water = 0.0)
			for other in player.backpack.all_stacks() + ([player.held] if player.held else []):
				if other != selected and other.def.capacity > 0.0:
					_button("Pour into %s" % other.def.name.to_lower(), func():
						var err := selected.pour_into(other)
						if err != "": player.message.emit(err))
		if d.has("medical"):
			_button("Use on %s" % d.treats, func(): _use_now())
		_button("Drop", func(): player.drop_stack(selected); selected = null)
	else:
		_info.text = "Drag to rearrange · %s rotates while dragging" % Keys.label("rotate_item") + "\nDrop on a side slot to strap a tool outside · on Hands to hold it\nDrag off the panel to drop · click to select"
	_actions.add_child(HSeparator.new())
	var head := Label.new()
	head.text = "Recipes"
	head.add_theme_color_override("font_color", TEXT)
	_actions.add_child(head)
	for id in player.known_recipes:
		var r: Dictionary = Builds.RECIPES[id]
		var have := {}
		var ok := true
		for k in r.needs:
			have[k] = player.backpack.count_of(k)
			ok = ok and have[k] >= r.needs[k]
		var b := _button("Craft %s — %s (%.2f h)" % [Items.get_def(id).name.to_lower(), Builds.needs_text(r.needs, have), r.hours], _craft.bind(id))
		b.disabled = not ok
	var c := player.cond
	_status.text = "Health %d · Stamina %d · Hunger %d · Thirst %d\nWarmth %d · Wetness %d%% · Air %d °C\nInjuries: %s\nPack %.1f kg%s" % [
		c.health, c.stamina, c.hunger, c.thirst, c.warmth, int(c.wetness * 100), roundi(GameClock.weather.air_temp_c(GameClock.clock)),
		", ".join(c.injuries.keys().map(func(k): return "%s %s%s" % [c.injuries[k].kind, k, " (treated)" if c.injuries[k].treated else ""])) if c.injuries else "none",
		player.backpack.weight(), " (heavy: slower)" if player.backpack.encumbrance_mult() < 1.0 else ""]

func _button(text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func(): fn.call(); _refresh())
	_actions.add_child(b)
	return b

## Use the selected item straight from the pack, then put what's left back where it was.
func _use_now() -> void:
	var s := selected
	if player.held == s:
		player.use_held()
		return
	var spot := {}
	for e in player.backpack.entries:
		if e.stack == s:
			spot = e.duplicate()
	var prev_held := player.held
	var prev_slot := player.held_slot
	player.backpack.remove(s)
	player.held = s
	player.use_held()
	var left := player.held == s # not fully consumed
	player.held = prev_held
	player.held_slot = prev_slot
	if left and not (spot and player.backpack.place(s, spot.pos, spot.rot)):
		player.backpack.add(s)

func _craft(id: String) -> void:
	var r: Dictionary = Builds.RECIPES[id]
	for k in r.needs:
		player.backpack.take(k, r.needs[k])
	toggle()
	player.work(r.seconds, r.hours, "Crafting " + Items.get_def(id).name.to_lower(), func():
		player.receive(ItemStack.make(id, GameClock.clock.hours, r.get("count", 1))))

# --- Drawing -----------------------------------------------------------------------

func _draw() -> void:
	draw_rect(_panel_rect(), PANEL)
	_text(GRID_POS + Vector2(0, -30), "Backpack", 22)
	for y in Backpack.H:
		for x in Backpack.W:
			draw_rect(Rect2(GRID_POS + Vector2(x, y) * CELL, Vector2(CELL, CELL)).grow(-2), Color(1, 1, 1, 0.05))
	for e in player.backpack.entries:
		if not (_drag and _drag.moved and _drag.stack == e.stack):
			_item(e.stack, GRID_POS + Vector2(e.pos) * CELL, e.rot)
	for i in Backpack.ATTACH_SLOTS:
		var r := _slot_rect(i)
		draw_rect(r, Color(1, 1, 1, 0.06))
		draw_rect(r, Color(1, 1, 1, 0.2), false, 1.5)
		_text(r.position + Vector2(4, -6), "Strap %d (%s)" % [i + 1, Keys.label("slot_%d" % (i + 1))], 13)
		var s: ItemStack = player.backpack.attachments[i]
		if s and not (_drag and _drag.moved and _drag.stack == s):
			_item(s, r.position + Vector2((r.size.x - CELL) * 0.5, 6), false)
	var h := _hands_rect()
	draw_rect(h, Color(1, 1, 1, 0.06))
	draw_rect(h, Color(1, 1, 1, 0.2), false, 1.5)
	_text(h.position + Vector2(4, -6), "Hands", 13)
	if player.held and not (_drag and _drag.moved and _drag.stack == player.held):
		_item(player.held, h.position + Vector2(6, 6), false)
	if _drag and _drag.moved:
		var m := get_local_mouse_position()
		var top: Vector2 = m - (_drag.grab + Vector2(0.5, 0.5)) * CELL
		var ok := false
		if _in_grid(m):
			var pos := _cell_at(m) - Vector2i(_drag.grab)
			ok = player.backpack.fits(_drag.stack, pos, _drag.rot, _drag.stack)
			for c in Backpack.cells(_drag.stack.def, _drag.rot):
				draw_rect(Rect2(GRID_POS + Vector2(pos + c) * CELL, Vector2(CELL, CELL)).grow(-2), Color(0.5, 1, 0.5, 0.25) if ok else Color(1, 0.4, 0.4, 0.25))
		_item(_drag.stack, top, _drag.rot, 0.85)
	else:
		var hit := _stack_at(get_local_mouse_position())
		if hit:
			var t: String = hit.stack.label(GameClock.clock.hours)
			var at := get_local_mouse_position() + Vector2(16, -10)
			var sz := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
			draw_rect(Rect2(at - Vector2(6, sz.y - 2), sz + Vector2(12, 8)), Color(0, 0, 0, 0.85))
			_text(at, t, 15)

func _item(s: ItemStack, top_left: Vector2, rot: bool, alpha := 1.0) -> void:
	var outline := Color(1, 1, 1, 0.9) if s == selected else Color(1, 1, 1, 0.18)
	for c in Backpack.cells(s.def, rot):
		var r := Rect2(top_left + Vector2(c) * CELL, Vector2(CELL, CELL)).grow(-3)
		draw_rect(r, Color(s.def.color.darkened(0.7), 0.55 * alpha))
		draw_rect(r, outline, false, 1.5)
	ItemIcons.draw(self, s, top_left, CELL, rot, alpha)
	var size := Vector2(Backpack.cells(s.def, rot).reduce(func(m, c): return Vector2i(maxi(m.x, c.x + 1), maxi(m.y, c.y + 1)), Vector2i.ONE)) * CELL
	if s.count > 1:
		var t := "×%d" % s.count
		var at := top_left + size - Vector2(_font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 7, 7)
		draw_string_outline(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
		draw_string(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
	if s.def.has("food") and s.def.spoil_hours > 0.0:
		var f := s.freshness(GameClock.clock.hours)
		draw_rect(Rect2(top_left + Vector2(5, size.y - 9), Vector2(CELL * 0.5, 4)), [Color("7cc06a"), Color("d8b050"), Color("a05a3a")][f])

func _text(pos: Vector2, s: String, size := 14) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, TEXT)
