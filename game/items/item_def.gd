class_name ItemDef extends Resource
## Static definition of a packable item. One .tres per item in data/items/.

@export var id := ""
@export var name := ""
@export var shape: Array[Vector2i] = [Vector2i.ZERO] ## occupied grid cells
@export var weight := 0.5 ## kg per unit
@export var color := Color.GRAY
@export var tags: PackedStringArray = [] ## tool, axe, knife, attachable, food, container, fuel, medical, lighter
@export var max_stack := 1
@export var food := 0.0 ## hunger restored when fresh
@export var spoil_hours := 0.0 ## 0 = never; stale at half, spoiled at full
@export var capacity := 0.0 ## litres (containers)
@export var fuel_hours := 0.0 ## burn time added to a fire
@export var uses := 0 ## e.g. lighter strikes
@export var treats := "" ## injury region a medical item treats
@export var description := ""

func has(tag: String) -> bool:
	return tag in tags

func size() -> Vector2i:
	var s := Vector2i.ZERO
	for c in shape:
		s = Vector2i(maxi(s.x, c.x + 1), maxi(s.y, c.y + 1))
	return s
