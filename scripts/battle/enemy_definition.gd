class_name EnemyDefinition
extends Resource

@export var id := "training_dummy"
@export var name_key := "ENEMY_TRAINING_DUMMY"
@export var max_hp := 18
@export var attack_damage := 6
@export var attack_interval_triples := 3
@export var visual_color := Color("c97872")
@export var tags: Array[String] = []
@export var rock_throw_damage := 0

static func legacy(balance: BalanceConfig) -> EnemyDefinition:
	var definition := EnemyDefinition.new()
	definition.max_hp = balance.enemy_hp
	definition.attack_damage = balance.enemy_attack_damage
	definition.attack_interval_triples = balance.enemy_attack_interval
	return definition
