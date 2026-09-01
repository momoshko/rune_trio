class_name BoardModel
extends RefCounted

var level: LevelDefinition
var active: Dictionary = {}
var locked_stack_id := -1

func _init(definition: LevelDefinition) -> void:
	level = definition
	reset()

func reset() -> void:
	active.clear()
	locked_stack_id = -1
	var tile_id := 0
	for stack in level.stacks:
		for order in stack.tile_types.size():
			active[tile_id] = TilePlacement.create(tile_id, stack.tile_types[order], stack.position, stack.stack_id, order)
			tile_id += 1

func remaining_count() -> int:
	return active.size()

func is_empty() -> bool:
	return active.is_empty()

func placement(tile_id: int) -> TilePlacement:
	return active.get(tile_id)

func is_available(tile_id: int) -> bool:
	var tile := placement(tile_id)
	return tile != null and tile.stack_id != locked_stack_id and top_tile(tile.stack_id) == tile

func lock_stack(stack_id: int) -> bool:
	if top_tile(stack_id) == null: return false
	var selectable_stacks := 0
	for stack in level.stacks:
		if stack.stack_id != stack_id and top_tile(stack.stack_id) != null: selectable_stacks += 1
	if selectable_stacks == 0: return false
	locked_stack_id = stack_id
	return true

func clear_stack_lock() -> void:
	locked_stack_id = -1

func safe_lock_candidates() -> Array[int]:
	var result: Array[int] = []
	for stack in level.stacks:
		if top_tile(stack.stack_id) != null and lock_would_leave_move(stack.stack_id): result.append(stack.stack_id)
	return result

func lock_would_leave_move(stack_id: int) -> bool:
	for stack in level.stacks:
		if stack.stack_id != stack_id and top_tile(stack.stack_id) != null: return true
	return false

func stack_tiles(stack_id: int) -> Array[TilePlacement]:
	var result: Array[TilePlacement] = []
	for tile in active.values():
		if tile.stack_id == stack_id: result.append(tile)
	result.sort_custom(func(a, b): return a.stack_order < b.stack_order)
	return result

func top_tile(stack_id: int) -> TilePlacement:
	var tiles := stack_tiles(stack_id)
	return tiles[0] if not tiles.is_empty() else null

func visual_depth(tile_id: int) -> int:
	var tile := placement(tile_id)
	if tile == null: return -1
	return stack_tiles(tile.stack_id).find(tile)

func remove_tile(tile_id: int) -> TilePlacement:
	if not is_available(tile_id): return null
	var tile := placement(tile_id)
	active.erase(tile_id)
	return tile

func available_ids() -> Array[int]:
	var result: Array[int] = []
	for tile_id in active:
		if is_available(tile_id): result.append(tile_id)
	result.sort_custom(func(a, b): return placement(a).stack_id < placement(b).stack_id)
	return result
