class_name PauseMenu extends PanelContainer
## Esc: pause, save to a slot (only when safe), load any slot, settings, quit.
## Settings: volume per sound bus, hints on or off, and key rebinding (click an action, press a key).

var player: Player
var main: Node
var _box: VBoxContainer
var _note: Label
var _waiting := "" ## action waiting for a new key

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	custom_minimum_size = Vector2(520, 0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.08, 0.07, 0.94)
	bg.set_corner_radius_all(8)
	bg.set_content_margin_all(18)
	add_theme_stylebox_override("panel", bg)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)

func _input(event: InputEvent) -> void:
	if _waiting == "" or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		var code: int = event.physical_keycode
		if code != KEY_ESCAPE:
			Settings.bind(_waiting, code)
		_waiting = ""
		_settings()

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
		_box.remove_child(c) # gone now, so the panel measures only what's new
		c.queue_free()
	var title := Label.new()
	title.text = "Paused  ·  Day %d, %s" % [GameClock.clock.day() + 1, GameClock.clock.season_name()]
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
	_button("Settings", _settings)
	_button("Quit to desktop", func(): get_tree().quit())
	if note != "":
		_label(note)
	_center.call_deferred()

## Volumes, hints, keys.
func _settings() -> void:
	for c in _box.get_children():
		_box.remove_child(c) # gone now, so the panel measures only what's new
		c.queue_free()
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 24)
	_box.add_child(title)
	for b in Settings.BUSES:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = {"Master": "Volume", "Music": "Music", "SFX": "Sounds", "Ambience": "Ambience", "Weather": "Rain and wind"}[b]
		l.custom_minimum_size = Vector2(150, 0)
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = Settings.volume[b]
		s.custom_minimum_size = Vector2(300, 0)
		s.value_changed.connect(func(v: float):
			Settings.volume[b] = v
			Settings.apply()
			Settings.save())
		row.add_child(s)
		_box.add_child(row)
	var hints := CheckBox.new()
	hints.text = "Hints and the first-days checklist"
	hints.button_pressed = Settings.hints
	hints.toggled.connect(func(on: bool):
		Settings.hints = on
		Settings.save())
	_box.add_child(hints)
	_box.add_child(HSeparator.new())
	_label("Keys: click one, then press the new key (Esc cancels).")
	var grid := GridContainer.new()
	grid.columns = 2
	for a in Settings.ACTIONS:
		var l := Label.new()
		l.text = Settings.ACTIONS[a]
		l.custom_minimum_size = Vector2(170, 0)
		grid.add_child(l)
		var b := Button.new()
		b.text = "Press a key…" if _waiting == a else Keys.label(a)
		b.custom_minimum_size = Vector2(150, 0)
		b.pressed.connect(func():
			_waiting = a
			_settings())
		grid.add_child(b)
	_box.add_child(grid)
	_button("Reset keys to defaults", func():
		Settings.reset_keys()
		_settings())
	_box.add_child(HSeparator.new())
	_button("Back", func(): _build())
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
