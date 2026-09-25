class_name Journal extends RefCounted
## The field journal: dated entries written the first time something happens or is found
## (a landmark, a first kill, first snow, pages left by the last lookout keeper). Each key is
## written once. Main owns the current journal; anything can add to it with Journal.note().

signal written(text: String)

static var current: Journal

var entries: Array = [] ## {hours, text}, oldest first
var keys := {}

## Adds an entry once per key. Safe to call every frame; does nothing without a journal.
static func note(key: String, text: String) -> void:
	if current == null or current.keys.has(key):
		return
	current.keys[key] = true
	current.entries.append({"hours": GameClock.clock.hours, "text": text})
	current.written.emit(text)

static func has(key: String) -> bool:
	return current != null and current.keys.has(key)

func to_dict() -> Dictionary:
	return {"entries": entries.duplicate(true), "keys": keys.keys()}

func from_dict(d: Dictionary) -> void:
	entries = d.get("entries", []).duplicate(true)
	keys = {}
	for k in d.get("keys", []):
		keys[k] = true
