class_name Items extends RefCounted
## Registry of ItemDefs, loaded once from data/items/*.tres.

static var _defs := {}

static func get_def(id: String) -> ItemDef:
	if _defs.is_empty():
		for f in DirAccess.get_files_at("res://data/items"):
			var path := "res://data/items/" + f.trim_suffix(".remap")
			if path.ends_with(".tres"):
				var d: ItemDef = load(path)
				_defs[d.id] = d
	assert(_defs.has(id), "unknown item " + id)
	return _defs[id]
