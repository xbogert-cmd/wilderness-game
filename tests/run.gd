extends SceneTree
## Headless test runner: godot --headless -s tests/run.gd
## Runs every test_*() method in tests/test_*.gd. Exit code = failure count.

var failures := 0
var current := ""

func _init() -> void:
	var dir := DirAccess.open("res://tests")
	var passed := 0
	for file in dir.get_files():
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var suite: Object = load("res://tests/" + file).new()
		suite.set("t", self)
		for m in suite.get_method_list():
			if m.name.begins_with("test_"):
				current = file + "::" + m.name
				var before := failures
				suite.call(m.name)
				if failures == before:
					passed += 1
	print("%d passed, %d failed" % [passed, failures])
	quit(failures)

func ok(cond: bool, msg := "") -> void:
	if not cond:
		failures += 1
		printerr("FAIL ", current, "  ", msg)

func near(a: float, b: float, msg := "", eps := 0.001) -> void:
	ok(absf(a - b) <= eps, "%s (got %s, want %s)" % [msg, a, b])
