class_name SaveGame extends RefCounted
## Versioned JSON saves in user://saves. Slots "1".."3" are manual, "auto" is written at camp.
## Loading works by reloading the main scene with `pending` set; Main applies it on startup.

const VERSION := 1
## Runs with debug flags (checks, previews) save apart so they can never touch a player's saves.
static var DIR := "user://test_saves" if OS.get_cmdline_user_args().size() > 0 else "user://saves"
const SLOTS: PackedStringArray = ["1", "2", "3", "auto"]

static var pending := {} ## save data waiting for the next scene start

static func path(slot: String) -> String:
	return "%s/slot_%s.json" % [DIR, slot]

static func write(slot: String, data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(DIR)
	data.version = VERSION
	data.saved_unix = Time.get_unix_time_from_system()
	var tmp := path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data))
	f.close()
	return DirAccess.rename_absolute(tmp, path(slot)) # never leave a half-written slot behind

## Returns {} if the slot is empty, unreadable, or from a newer build.
static func read(slot: String) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path(slot))) != OK or not (j.data is Dictionary):
		return {}
	var d: Dictionary = j.data
	if int(d.get("version", 0)) > VERSION:
		return {}
	return migrate(d)

## Upgrades older saves step by step. Add a branch per version bump.
static func migrate(d: Dictionary) -> Dictionary:
	while int(d.get("version", 0)) < VERSION:
		match int(d.get("version", 0)):
			0: # pre-release saves had no version field; nothing else changed
				d.version = 1
	return d

static func describe(slot: String) -> String:
	var d := read(slot)
	if d.is_empty():
		return "empty"
	var c := Clock.new()
	c.from_dict(d.clock)
	var when := Time.get_datetime_string_from_unix_time(int(d.saved_unix), true)
	return "Day %d, %02d:%02d %s  (saved %s)" % [c.day() + 1, int(c.hour_of_day()), int(fmod(c.hour_of_day(), 1.0) * 60.0), c.season_name(), when]
