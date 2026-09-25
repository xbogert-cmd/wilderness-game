extends RefCounted

var t
const SLOT := "test"

func test_roundtrip_file() -> void:
	var data := {"clock": {"hours": 50.5}, "player": {"x": 123.0}, "world": {"0": {"felled": {"4": 30.0}}}}
	t.ok(SaveGame.write(SLOT, data) == OK, "write ok")
	var back := SaveGame.read(SLOT)
	t.near(float(back.clock.hours), 50.5, "clock restored")
	t.ok(back.world["0"].felled.has("4"), "world state restored")
	t.ok(int(back.version) == SaveGame.VERSION, "stamped with version")
	t.ok("Day 3" in SaveGame.describe(SLOT), "describe shows day: " + SaveGame.describe(SLOT))
	DirAccess.remove_absolute(SaveGame.path(SLOT))

func test_missing_and_newer_rejected() -> void:
	t.ok(SaveGame.read("nope").is_empty(), "missing slot is empty")
	DirAccess.make_dir_recursive_absolute(SaveGame.DIR)
	var f := FileAccess.open(SaveGame.path(SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": SaveGame.VERSION + 1, "clock": {"hours": 1.0}}))
	f.close()
	t.ok(SaveGame.read(SLOT).is_empty(), "save from a newer build is refused, not half-loaded")
	f = FileAccess.open(SaveGame.path(SLOT), FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	t.ok(SaveGame.read(SLOT).is_empty(), "corrupt file is refused")
	DirAccess.remove_absolute(SaveGame.path(SLOT))

func test_migrates_unversioned() -> void:
	var d := SaveGame.migrate({"clock": {"hours": 1.0}})
	t.ok(int(d.version) == SaveGame.VERSION, "unversioned save upgraded")
