class_name Backpack extends RefCounted
## The only stored inventory: a spatial grid plus a few exterior tool attachments.
## Pure logic; BackpackUI draws it.

const W := 6
const H := 7
const ATTACH_SLOTS := 2
const COMFORT_KG := 14.0

var entries: Array[Dictionary] = [] ## {stack: ItemStack, pos: Vector2i, rot: bool}
var attachments: Array = [null, null] ## ItemStack or null

## Grid cells of a def, rotated 90° clockwise when rot.
static func cells(def: ItemDef, rot: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var h := def.size().y
	for c in def.shape:
		out.append(Vector2i(h - 1 - c.y, c.x) if rot else c)
	return out

func entry_at(cell: Vector2i) -> Dictionary:
	for e in entries:
		for c in cells(e.stack.def, e.rot):
			if e.pos + c == cell:
				return e
	return {}

func fits(stack: ItemStack, pos: Vector2i, rot: bool, ignore: ItemStack = null) -> bool:
	for c in cells(stack.def, rot):
		var p := pos + c
		if p.x < 0 or p.y < 0 or p.x >= W or p.y >= H:
			return false
		var e := entry_at(p)
		if not e.is_empty() and e.stack != ignore:
			return false
	return true

func place(stack: ItemStack, pos: Vector2i, rot: bool) -> bool:
	if not fits(stack, pos, rot, stack):
		return false
	remove(stack)
	entries.append({"stack": stack, "pos": pos, "rot": rot})
	return true

func remove(stack: ItemStack) -> void:
	for i in entries.size():
		if entries[i].stack == stack:
			entries.remove_at(i)
			return
	for i in ATTACH_SLOTS:
		if attachments[i] == stack:
			attachments[i] = null

func contains(stack: ItemStack) -> bool:
	return stack in attachments or entries.any(func(e): return e.stack == stack)

## Merge into matching stacks first, then first free spot (either rotation).
func add(stack: ItemStack) -> bool:
	if stack.def.max_stack > 1:
		for e in entries:
			var s: ItemStack = e.stack
			if s.def == stack.def and s.count < s.def.max_stack and absf(s.made_hour - stack.made_hour) < 12.0:
				var moved := mini(stack.count, s.def.max_stack - s.count)
				s.count += moved
				s.made_hour = minf(s.made_hour, stack.made_hour) # the older food decides spoilage
				stack.count -= moved
				if stack.count == 0:
					return true
	for y in H:
		for x in W:
			for rot in [false, true]:
				if fits(stack, Vector2i(x, y), rot):
					entries.append({"stack": stack, "pos": Vector2i(x, y), "rot": rot})
					return true
	return false

func attach(stack: ItemStack, slot: int) -> bool:
	if not stack.def.has("attachable") or attachments[slot] != null:
		return false
	remove(stack)
	attachments[slot] = stack
	return true

func all_stacks() -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for e in entries:
		out.append(e.stack)
	for a in attachments:
		if a != null:
			out.append(a)
	return out

func find(pred: Callable) -> ItemStack:
	for s in all_stacks():
		if pred.call(s):
			return s
	return null

## An item id, or "#tag" for anything carrying that tag (e.g. "#cord": paracord or vine cord).
static func matches(s: ItemStack, id: String) -> bool:
	return s.def.has(id.substr(1)) if id.begins_with("#") else s.def.id == id

func count_of(id: String) -> int:
	var n := 0
	for s in all_stacks():
		if matches(s, id):
			n += s.count
	return n

## Removes n units of id across stacks. All-or-nothing.
func take(id: String, n: int) -> bool:
	if count_of(id) < n:
		return false
	for s in all_stacks():
		if n == 0:
			break
		if matches(s, id):
			var k := mini(n, s.count)
			s.count -= k
			n -= k
			if s.count == 0:
				remove(s)
	return true

func weight() -> float:
	var w := 0.0
	for s in all_stacks():
		w += s.weight()
	return w

## Movement multiplier from load. Never below 0.6.
func encumbrance_mult() -> float:
	return 1.0 - clampf((weight() - COMFORT_KG) / 20.0, 0.0, 0.4)

func to_dict() -> Dictionary:
	var es := []
	for e in entries:
		es.append({"s": e.stack.to_dict(), "x": e.pos.x, "y": e.pos.y, "r": e.rot})
	return {"entries": es, "attach": attachments.map(func(a): return a.to_dict() if a else null)}

func from_dict(d: Dictionary) -> void:
	entries.clear()
	for e in d.entries:
		entries.append({"stack": ItemStack.from_dict(e.s), "pos": Vector2i(int(e.x), int(e.y)), "rot": bool(e.r)})
	attachments = (d.attach as Array).map(func(a): return ItemStack.from_dict(a) if a else null)
