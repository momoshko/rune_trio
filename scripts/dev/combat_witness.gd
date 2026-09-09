class_name CombatWitness
extends RefCounted

# Detached Resource snapshots; no save files or live run state are referenced.
var initial_conditions: Dictionary = {}
var stack_ids := PackedInt32Array()
var triples: Array[String] = []
var core_hp := 0
var enemy_hp := 0
var action_count := 0
var max_row_occupancy := 0 # Includes the inserted Rune BEFORE automatic removal.
var hp_damage_received := 0
var final_state_key := ""

func summary() -> Dictionary:
	return {"stack_ids":stack_ids, "triples":triples, "core_hp":core_hp,
		"enemy_hp":enemy_hp, "action_count":action_count,
		"max_row_occupancy":max_row_occupancy, "hp_damage_received":hp_damage_received,
		"final_state_key":final_state_key}
