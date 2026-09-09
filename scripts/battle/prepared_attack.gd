class_name PreparedAttack
extends RefCounted

var sequence := 0
var base_damage := 0
var temporary_damage_bonus := 0
var damage: int:
	get: return base_damage + temporary_damage_bonus
var base_interval := 1
var countdown := 1
var frozen := false
var kind := "enemy_attack"
var telegraph := ""
var name_key := ""

func _init(index: int, attack_damage: int, interval: int, attack_kind := "enemy_attack", warning := "", attack_name_key := "") -> void:
	sequence = index
	base_damage = maxi(0, attack_damage)
	base_interval = maxi(1, interval)
	countdown = base_interval
	kind = attack_kind
	telegraph = warning
	name_key = attack_name_key

func snapshot() -> Dictionary:
	var data := {"sequence": sequence, "damage": damage, "base_damage": base_damage,
		"temporary_damage_bonus":temporary_damage_bonus, "base_interval": base_interval,
		"countdown": countdown, "frozen": frozen, "kind": kind, "telegraph": telegraph,
		"name_key":name_key}
	data.make_read_only()
	return data
