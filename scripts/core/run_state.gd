class_name RunState
extends RefCounted

enum Status { IDLE, BATTLE, BETWEEN_ENCOUNTERS, VICTORY, DEFEAT, ABANDONED, ENCOUNTER_CHOICE, REWARD }

var run_instance_id := ""
var status := Status.IDLE
var current_slot_index := 0
var completed_encounters := 0
var boundary_hp := 40
var current_encounter_instance_id := ""
var last_processed_result_id := ""
var defeat_reason := ""
var acquired_relic_ids: Array[String] = []
var encounter_offer: Array[String] = []
var reward_offer: Array[String] = []
var defeated_normal_archetypes: Dictionary = {} # chapter index -> enemy IDs
var selected_encounter_id := ""
var reward_claimed := false

func offer_id(kind: String) -> String:
	return "%s:%d:%s" % [run_instance_id, current_slot_index, kind]

func is_active() -> bool:
	return status in [Status.BATTLE, Status.BETWEEN_ENCOUNTERS, Status.ENCOUNTER_CHOICE, Status.REWARD]
