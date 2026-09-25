class_name Keys extends RefCounted
## Human-readable name of the first binding of an input action, so prompts follow remapping.

const MOUSE := {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"}

static func label(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var code: int = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
			var local := DisplayServer.keyboard_get_keycode_from_physical(code) if e.physical_keycode != KEY_NONE else code
			return OS.get_keycode_string(local if local != KEY_NONE else code)
		if e is InputEventMouseButton:
			return MOUSE.get(e.button_index, "Mouse")
	return "?"
