class_name BoardModel
extends RefCounted

var level: LevelDefinition
var active: Dictionary = {}

func _init(definition: LevelDefinition) -> void:
	level = definition
	reset()

func reset() -> void:
	active.clear()
	for placement in level.placements: active[placement.tile_id] = placement

func remaining_count() -> int:
	return active.size()

func is_empty() -> bool:
	return active.is_empty()

func placement(tile_id: int) -> TilePlacement:
	return active.get(tile_id)

func tile_rect(tile: TilePlacement) -> Rect2:
	return Rect2(tile.position - level.tile_size * 0.5, level.tile_size)

func is_available(tile_id: int) -> bool:
	var tile := placement(tile_id)
	if tile == null: return false
	var rect := tile_rect(tile)
	for other in active.values():
		if other.layer > tile.layer and rect.intersects(tile_rect(other)): return false
	return true

func remove_tile(tile_id: int) -> TilePlacement:
	if not is_available(tile_id): return null
	var tile := placement(tile_id)
	active.erase(tile_id)
	return tile

func available_ids() -> Array[int]:
	var result: Array[int] = []
	for tile_id in active:
		if is_available(tile_id): result.append(tile_id)
	result.sort_custom(func(a, b): return placement(a).layer > placement(b).layer)
	return result
