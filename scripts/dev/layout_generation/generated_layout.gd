class_name GeneratedLayout
extends RefCounted

var recipe_id := ""
var recipe_version := 0
var generator_version := 0
var seed := ""
var stacks: Array[Array] = []
var stack_lengths: Array[int] = []
var rune_counts: Dictionary = {}
var layout_hash := ""

func to_level(level_id := "generated_layout") -> LevelDefinition:
	var level := LevelDefinition.new()
	level.id = level_id
	for index in stacks.size():
		var stack := StackDefinition.new()
		stack.stack_id = index
		stack.position = Vector2(90 + index % 4 * 150, 110 + index / 4 * 300)
		stack.tile_types.assign(stacks[index]) # Index 0 remains Top.
		level.stacks.append(stack)
	return level

func ordered_stacks() -> Array:
	var copy: Array = []
	for stack in stacks: copy.append(stack.duplicate())
	return copy
