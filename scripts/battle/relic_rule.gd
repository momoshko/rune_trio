class_name RelicRule
extends Resource

@export var rune := "" # Exact Rune, "*" (all), or "attack" (four base attack Runes).
@export_enum("ALWAYS", "FIRST_ACTIVATION", "EVEN_STREAK", "AFTER_TYPE", "AFTER_OTHER", "SHIELD_EMPTY", "SHIELD_PRESENT", "FIRST_TRIPLE") var condition := "ALWAYS"
@export var previous_type := ""
@export var hp_at_most := -1
@export var occupancy_min := -1
@export var occupancy_max := -1
@export var every_n := 0
@export_enum("DAMAGE", "TIMELINE", "OVERFLOW_SHIELD", "ORDINARY_DAMAGE", "HEALING", "SHIELD", "ECHO_HALF_BASE") var effect := "DAMAGE"
@export var amount := 0
