class_name EncounterDefinition
extends Resource

# One authored pair. Never combine an arbitrary enemy and layout at runtime.
@export var id := ""
@export var chapter := 0
@export_enum("normal", "elite", "boss") var role := "normal"
@export var enemy_id := ""
@export var level: LevelDefinition
@export_enum("MODERATE", "HIGH", "VERY_HIGH") var danger := "MODERATE"
@export_enum("ATTACK", "CONTROL", "DEFENSE", "MIXED") var reward_category := "MIXED"
@export var mechanic_key := ""

func battle_level() -> LevelDefinition:
	var copy := level.duplicate(true) as LevelDefinition
	copy.encounter_enemy_ids.assign([enemy_id])
	copy.milestone = "boss" if role == "boss" else ("mini_boss" if role == "elite" else "")
	return copy
