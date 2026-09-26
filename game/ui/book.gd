class_name Book extends Control
## A book laid open, fully paused: chapters and their entries down the left page, the chosen
## entry on the right with a picture, what it needs (have / need, and where to get what you're
## short of) and a button to do it. The recipe book and the build book are both one of these.

const PAPER := Color(0.87, 0.81, 0.68)
const PAPER_DARK := Color(0.78, 0.71, 0.57)
const INK := Color(0.23, 0.18, 0.12)
const FADED := Color(0.23, 0.18, 0.12, 0.5)
const GOOD := Color(0.18, 0.42, 0.18)
const SHORT := Color(0.62, 0.2, 0.14)
const LEFT := Rect2(190, 80, 700, 920)
const RIGHT := Rect2(930, 80, 800, 920)

var player: Player
var chosen := ""
var action: Button ## the right page's button (make it, place it)
var _list: VBoxContainer
var _page: VBoxContainer
var _buttons := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var scroll := ScrollContainer.new()
	scroll.position = LEFT.position + Vector2(50, 110)
	scroll.size = LEFT.size - Vector2(90, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(scroll.size.x - 20.0, 0)
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)
	_page = VBoxContainer.new()
	_page.position = RIGHT.position + Vector2(50, 50)
	_page.custom_minimum_size = Vector2(RIGHT.size.x - 100.0, 0)
	_page.add_theme_constant_override("separation", 10)
	add_child(_page)

# --- For the books to fill in ----------------------------------------------------------

func title() -> String:
	return ""

func hint() -> String:
	return "Esc to close"

## {chapter name: [entry ids]}
func chapters() -> Dictionary:
	return {}

func entry_name(_id: String) -> String:
	return ""

## Can it be done right now? (Entries you can do show in full ink.)
func ready_now(_id: String) -> bool:
	return false

func fill_page(_id: String) -> void:
	pass

func closes_on(event: InputEvent) -> bool:
	return event.is_action_pressed("menu")

# --- Open, close, choose ---------------------------------------------------------------

func open(id := "") -> void:
	if visible or player.working > 0.0 or player.placing or get_tree().paused:
		return
	visible = true
	get_tree().paused = true
	_fill_list()
	choose(id if id != "" else (chosen if chosen != "" else _first()))

func close() -> void:
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and closes_on(event):
		close()
		get_viewport().set_input_as_handled()

func _first() -> String:
	for c in chapters().values():
		if c:
			return c[0]
	return ""

func _fill_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_buttons.clear()
	var chs := chapters()
	for ch in chs:
		var head := ink(ch, 22, INK)
		head.add_theme_constant_override("line_spacing", 0)
		if _list.get_child_count() > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 12)
			_list.add_child(gap)
		_list.add_child(head)
		for id in chs[ch]:
			var b := Button.new()
			b.flat = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text = "    " + entry_name(id)
			b.add_theme_font_size_override("font_size", 19)
			var c := INK if ready_now(id) else FADED
			for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(k, c)
			b.pressed.connect(choose.bind(id))
			_list.add_child(b)
			_buttons[id] = b

## The list button for an entry (checks click it for real).
func entry_button(id: String) -> Button:
	return _buttons.get(id)

func choose(id: String) -> void:
	chosen = id
	for k in _buttons:
		var b: Button = _buttons[k]
		b.text = ("  ▸ " if k == id else "    ") + entry_name(k)
	for c in _page.get_children():
		c.queue_free()
	action = null
	if id != "":
		fill_page(id)
	queue_redraw()

# --- Page pieces -------------------------------------------------------------------------

func ink(text: String, size := 18, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(RIGHT.size.x - 200.0, 0)
	return l

## One thing it needs: a picture, "medium logs  2 / 4", and if you're short, where to get it.
func need_row(key: String, have: int, need: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var pic := Pic.new()
	pic.key = key
	pic.custom_minimum_size = Vector2(56, 56)
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	var ok := have >= need
	col.add_child(ink("%s   %d / %d%s" % [Builds.nice(key).capitalize(), mini(have, 999), need, "" if ok else "   (short %d)" % (need - have)], 19, GOOD if ok else SHORT))
	if not ok and Builds.source(key) != "":
		var src := ink(Builds.source(key), 15, FADED)
		src.custom_minimum_size.x = RIGHT.size.x - 190.0
		col.add_child(src)
	row.add_child(col)
	return row

func add_action(text: String, enabled: bool, fn: Callable) -> Button:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	_page.add_child(gap)
	action = Button.new()
	action.text = text
	action.disabled = not enabled
	action.custom_minimum_size = Vector2(320, 52)
	action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	action.add_theme_font_size_override("font_size", 20)
	action.pressed.connect(fn)
	_page.add_child(action)
	return action

func page() -> VBoxContainer:
	return _page

# --- Drawing -------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var book := Rect2(LEFT.position - Vector2(24, 20), RIGHT.end - LEFT.position + Vector2(48, 40))
	draw_rect(book, Color("4a3322")) # the cover
	draw_rect(LEFT, PAPER)
	draw_rect(RIGHT, PAPER)
	for k in 6: # shading into the spine
		var t := float(k) / 6.0
		draw_rect(Rect2(LEFT.end.x - 40.0 + k * 6.6, LEFT.position.y, 7, LEFT.size.y), Color(PAPER_DARK, t * 0.7))
		draw_rect(Rect2(RIGHT.position.x + 33.0 - k * 6.6, RIGHT.position.y, 7, RIGHT.size.y), Color(PAPER_DARK, t * 0.7))
	draw_rect(Rect2(LEFT.end.x, LEFT.position.y, RIGHT.position.x - LEFT.end.x, LEFT.size.y), Color("3a281a"))
	var font := get_theme_default_font()
	draw_string(font, LEFT.position + Vector2(50, 70), title(), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)
	draw_line(LEFT.position + Vector2(50, 88), LEFT.position + Vector2(LEFT.size.x - 60.0, 88), FADED, 2.0)
	draw_string(font, Vector2(LEFT.position.x + 50.0, LEFT.end.y - 26.0), hint(), HORIZONTAL_ALIGNMENT_LEFT, LEFT.size.x - 100.0, 15, FADED)

## A small picture of a making: an item's icon, a log of that length, or a tag's usual item.
class Pic extends Control:
	var key := ""
	var picture: Texture2D ## a build's picture instead

	func _draw() -> void:
		if picture:
			var sc := minf(size.x / picture.get_width(), size.y / picture.get_height())
			var sz := picture.get_size() * sc
			draw_texture_rect(picture, Rect2((size - sz) * 0.5, sz), false)
			return
		if Builds.is_log(key):
			var f: float = {"short": 0.45, "medium": 0.72, "long": 1.0}[key]
			var r := Rect2(Vector2(size.x * (1.0 - f) * 0.5, size.y * 0.35), Vector2(size.x * f, size.y * 0.3))
			draw_rect(r, Palette.BARK)
			draw_line(r.position + Vector2(4, r.size.y * 0.35), r.position + Vector2(r.size.x - 8.0, r.size.y * 0.4), Palette.BARK_DARK, 1.5)
			draw_circle(Vector2(r.end.x, r.get_center().y), r.size.y * 0.5, Color("c8a878"))
			draw_arc(Vector2(r.end.x, r.get_center().y), r.size.y * 0.28, 0, TAU, 12, Color("9a7a50"), 1.2)
			return
		var id: String = Builds.TAGS[key][1] if key.begins_with("#") else key
		var st := ItemStack.make(id)
		var box := Vector2(st.def.size())
		var cell := minf(size.x / box.x, size.y / box.y)
		ItemIcons.draw(self, st, (size - box * cell) * 0.5, cell)
		draw_set_transform_matrix(Transform2D.IDENTITY)
