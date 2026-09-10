class_name LayoutRecipe
extends Resource

@export_group("Identity")
@export var recipe_id := ""
@export var recipe_version := 1

@export_group("Construction")
@export var min_stacks := 5
@export var max_stacks := 6
@export var min_total_runes := 24
@export var max_total_runes := 30
@export var min_stack_length := 4
@export var max_stack_length := 6
@export var rune_minimums: Dictionary = {}
@export var rune_maximums: Dictionary = {}
@export var rune_weights: Dictionary = {}
@export var early_access: Array[Dictionary] = []
@export var max_same_type_streak := 2
