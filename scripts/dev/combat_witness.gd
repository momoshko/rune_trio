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
var core_shield := 0
var remaining_board_runes := 0
var enemy_attacks_executed := 0
var frozen_attacks_skipped := 0
var peak_row_after_clear := 0
var turns_ending_at_row_6 := 0
var longest_post_action_row_pressure := 0
var triple_counts: Dictionary = {}
var vulnerability_bonus_uses := 0
var armor_reduction_uses := 0
var final_state_key := ""

func summary() -> Dictionary:
	return {"stack_ids":stack_ids, "triples":triples, "core_hp":core_hp,
		"enemy_hp":enemy_hp, "action_count":action_count, "core_shield":core_shield,
		"max_row_occupancy":max_row_occupancy, "hp_damage_received":hp_damage_received,
		"remaining_board_runes":remaining_board_runes,
		"enemy_attacks_executed":enemy_attacks_executed,
		"frozen_attacks_skipped":frozen_attacks_skipped,
		"peak_row_after_clear":peak_row_after_clear,
		"turns_ending_at_row_6":turns_ending_at_row_6,
		"longest_post_action_row_pressure":longest_post_action_row_pressure,
		"triple_counts":triple_counts, "vulnerability_bonus_uses":vulnerability_bonus_uses,
		"armor_reduction_uses":armor_reduction_uses,
		"final_state_key":final_state_key}
