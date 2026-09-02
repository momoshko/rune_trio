class_name EnemyDefinition
extends Resource

@export_category("Enemy")
@export_group("Identity")
@export var id := "training_dummy"
@export var name_key := "ENEMY_TRAINING_DUMMY"
@export_group("Combat")
@export var max_hp := 18
@export var attack_damage := 6
@export var attack_interval_triples := 3
@export var rock_throw_damage := 0
@export_group("Visuals")
@export var visual_color := Color("c97872")
@export var texture: Texture2D
@export var portrait: Texture2D
@export_range(0.5, 2.5, 0.05) var boss_scale := 1.0
@export var tags: Array[String] = []

static func legacy(balance: BalanceConfig) -> EnemyDefinition:
	var definition := EnemyDefinition.new()
	definition.max_hp = balance.enemy_hp
	definition.attack_damage = balance.enemy_attack_damage
	definition.attack_interval_triples = balance.enemy_attack_interval
	return definition
