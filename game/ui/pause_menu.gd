class_name PauseMenu extends PanelContainer
## Esc: pause, save to a slot (only when safe), load any slot, quit.

var player: Player
var main: Node
var _box: VBoxContainer
var _note: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	custom_minimum_size = Vector2(520, 0)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and not player.placing:
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		_build()
		_center.call_deferred() # size is known only after the new buttons lay out

func _center() -> void:
	reset_size()
	position = (get_viewport_rect().size - size) * 0.5

func _build(note := "") -> void:
	for c in _box.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 24)
	_box.add_child(title)
	_button("Resume", toggle)
	var why := player.unsafe_reason()
	_box.add_child(HSeparator.new())
	for slot in ["1", "2", "3"]:
		var b := _button("Save to slot %s  —  %s" % [slot, SaveGame.describe(slot)], func():
			var err: Error = main.save_to(slot)
			_build("Saved to slot %s." % slot if err == OK else "Save failed (%s)." % error_string(err)))
		b.disabled = why != ""
	if why != "":
		_label("Can't save right now: " + why)
	_box.add_child(HSeparator.new())
	for slot in SaveGame.SLOTS:
		var desc := SaveGame.describe(slot)
		var b := _button("Load %s  —  %s" % ["autosave" if slot == "auto" else "slot " + slot, desc], func(): main.load_from(slot))
		b.disabled = desc == "empty"
	_box.add_child(HSeparator.new())
	_button("Quit to desktop", func(): get_tree().quit())
	if note != "":
		_label(note)
	_center.call_deferred()

func _button(text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(fn)
	_box.add_child(b)
	return b

func _label(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)
