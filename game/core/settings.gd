class_name Settings extends RefCounted
## Player preferences that aren't part of a save: volumes, key bindings, hints. Kept in
## settings.cfg beside the saves folder (test runs keep their own copy in test_saves).

const BUSES := ["Master", "Music", "SFX", "Ambience", "Weather"]
## Actions a player can rebind, with a friendly name.
const ACTIONS := {
	"move_left": "Move left", "move_right": "Move right", "run": "Run", "crouch": "Crouch", "hop": "Hop", "move_down": "Go down / drop through",
	"interact": "Interact", "lift": "Lift / let go", "stow": "Put away", "backpack": "Backpack", "build": "Build menu",
	"map": "Map & journal", "rest": "Sleep", "slot_1": "Strap 1", "slot_2": "Strap 2", "rotate_item": "Rotate item",
}

static var volume := {"Master": 1.0, "Music": 0.8, "SFX": 1.0, "Ambience": 1.0, "Weather": 1.0}
static var hints := true ## one-time tips and the first-days checklist
static var keys := {} ## action -> physical keycode the player chose

static func path() -> String:
	return "user://settings.cfg" if SaveGame.DIR == "user://saves" else SaveGame.DIR + "/settings.cfg"

static func load_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path()) == OK:
		for b in BUSES:
			volume[b] = float(cfg.get_value("volume", b, volume[b]))
		hints = bool(cfg.get_value("ui", "hints", true))
		for a in ACTIONS:
			if cfg.has_section_key("keys", a):
				keys[a] = int(cfg.get_value("keys", a))
	apply()

static func apply() -> void:
	for b in BUSES:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volume[b], 0.0001)))
			AudioServer.set_bus_mute(i, volume[b] <= 0.001)
	for a in keys:
		bind(a, keys[a], false)
	Keys.refresh()

static func save() -> void:
	var cfg := ConfigFile.new()
	for b in BUSES:
		cfg.set_value("volume", b, volume[b])
	cfg.set_value("ui", "hints", hints)
	for a in keys:
		cfg.set_value("keys", a, keys[a])
	DirAccess.make_dir_recursive_absolute(path().get_base_dir())
	cfg.save(path())

## Rebinds an action's keyboard key (mouse bindings on it are kept).
static func bind(action: String, physical: int, remember := true) -> void:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			InputMap.action_erase_event(action, e)
	var k := InputEventKey.new()
	k.physical_keycode = physical as Key
	InputMap.action_add_event(action, k)
	if remember:
		keys[action] = physical
		Keys.refresh()
		save()

## Puts every key back to the project defaults.
static func reset_keys() -> void:
	keys.clear()
	InputMap.load_from_project_settings()
	Keys.refresh()
	save()
