class_name EncounterRelicState
extends RefCounted

var activation_counts: Dictionary = {}
var consecutive_count := 0
var total_triples := 0
var previous_type := ""

func activation_snapshot() -> Dictionary:
	var copy := activation_counts.duplicate()
	copy.make_read_only()
	return copy

func finish(type_id: String, activated: Array) -> void:
	consecutive_count = consecutive_count + 1 if previous_type == type_id else 1
	previous_type = type_id
	total_triples += 1
	for id in activated: activation_counts[id] = int(activation_counts.get(id, 0)) + 1
