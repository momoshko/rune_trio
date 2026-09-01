class_name LevelDefinition
extends Resource

@export var id := "level_1"
@export var name_key := "LEVEL_1"
@export var tile_size := Vector2(92, 108)
@export var design_size := Vector2(560, 720)
@export var stacks: Array[StackDefinition] = []
@export var placements: Array[TilePlacement] = []
@export var known_solution := PackedInt32Array()
@export var encounter_enemy_ids: Array[String] = []
@export var boss_id := ""
@export var location_id := "stone_ruins"
@export var milestone := ""

func tile_count() -> int:
	var total := 0
	for stack in stacks: total += stack.tile_types.size()
	return total
