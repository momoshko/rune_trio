class_name TilePlacement
extends Resource

@export var tile_id := 0
@export var type_id := ""
@export var position := Vector2.ZERO
@export var layer := 0
@export var stack_id := 0
@export var stack_order := 0

static func create(id: int, type: String, anchor: Vector2, stack: int, order: int) -> TilePlacement:
	var tile := TilePlacement.new()
	tile.tile_id = id; tile.type_id = type; tile.position = anchor
	tile.layer = order; tile.stack_id = stack; tile.stack_order = order
	return tile
