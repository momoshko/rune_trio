class_name LevelDefinition
extends Resource

@export var id := "level_1"
@export var name_key := "LEVEL_1"
@export var tile_size := Vector2(92, 108)
@export var design_size := Vector2(560, 720)
@export var placements: Array[TilePlacement] = []
@export var known_solution := PackedInt32Array()
