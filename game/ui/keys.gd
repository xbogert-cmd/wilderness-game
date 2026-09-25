class_name Keys extends RefCounted
## Human-readable name of the first binding of an input action, so prompts follow remapping.
## Cached; call Keys.refresh() after changing bindings.

const MOUSE := {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"}

static var _cache := {}

static func refresh() -> void:
	_cache.clear()

static func label(action: String) -> String:
	if not _cache.has(action):
		_cache[action] = _lookup(action)
	return _cache[action]

static func _lookup(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var code: int = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
			if e.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
				var local := DisplayServer.keyboard_get_keycode_from_physical(code) # respects the user's layout
				if local != KEY_NONE:
					code = local
			return OS.get_keycode_string(code)
		if e is InputEventMouseButton:
			return MOUSE.get(e.button_index, "Mouse")
	return "?"
