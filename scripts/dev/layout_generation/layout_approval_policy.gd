class_name LayoutApprovalPolicy
extends Resource

@export var fast_max_states := 2000
@export var fast_time_budget_ms := 2000
@export var slow_max_states := 10000
@export var slow_time_budget_ms := 10000
@export var max_slow_candidates_per_enemy := 10
@export var alternative_max_states := 2000
@export var alternative_time_budget_ms := 2000
@export var low_hp_probe := 24
@export var consumption_advisory_threshold := 0.90
@export var low_hp_advisory_threshold := 10
@export var row_pressure_turn_fraction := 0.25
@export var row_pressure_streak := 3
