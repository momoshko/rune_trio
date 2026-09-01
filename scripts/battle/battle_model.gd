class_name BattleModel
extends RefCounted

var config: BalanceConfig
var core_hp: int
var core_shield := 0
var enemy_hp: int
var enemy_frozen := false
var enemy_action_counter: int
var current_enemy: EnemyDefinition
var boss_cycle_step := 0
var boss_telegraph := ""

func _init(balance: BalanceConfig, enemy: EnemyDefinition = null) -> void:
	config = balance
	reset(enemy)

func reset(enemy: EnemyDefinition = null) -> void:
	core_hp = config.core_max_hp; core_shield = 0
	start_enemy(enemy if enemy else EnemyDefinition.legacy(config))

func start_enemy(definition: EnemyDefinition) -> void:
	current_enemy = definition
	enemy_hp = definition.max_hp; enemy_frozen = false
	enemy_action_counter = definition.attack_interval_triples
	boss_cycle_step = 0; boss_telegraph = ""

func is_boss() -> bool:
	return current_enemy != null and current_enemy.tags.has("boss")

func is_large_enemy() -> bool:
	return is_boss() or (current_enemy != null and current_enemy.tags.has("mini_boss"))

func apply_triple(type_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	match type_id:
		"fire": damage_enemy(config.fire_damage, "fire", events)
		"ice":
			damage_enemy(config.ice_damage, "ice", events)
			enemy_frozen = true; events.append({"type":"status", "target":"enemy", "effect":"freeze"})
		"lightning": damage_enemy(config.lightning_damage, "lightning", events)
		"wind":
			damage_enemy(config.wind_damage, "wind", events)
			enemy_action_counter = mini(config.enemy_action_delay_max, enemy_action_counter + 1)
			events.append({"type":"delay", "target":"enemy", "value":enemy_action_counter})
		"life":
			var healed := mini(config.life_heal, config.core_max_hp - core_hp)
			core_hp += healed; events.append({"type":"heal", "target":"core", "value":healed})
		"shield":
			var gained := mini(config.shield_gain, config.shield_max - core_shield)
			core_shield += gained; events.append({"type":"shield", "target":"core", "value":gained})
	if enemy_hp <= 0:
		events.append({"type":"enemy_defeated", "target":"enemy"})
		return events
	events.append_array(advance_special_cycle() if current_enemy.tags.has("mini_boss") or is_boss() else advance_enemy_action())
	return events

func advance_special_cycle() -> Array[Dictionary]:
	if current_enemy.tags.has("heavy"):
		boss_cycle_step = boss_cycle_step % 3 + 1
		if boss_cycle_step == 2: boss_telegraph = "heavy_attack"; return [{"type":"boss_telegraph","ability":"heavy_attack"}]
		if boss_cycle_step == 3: boss_telegraph = ""; return special_damage("heavy_attack")
		return []
	if current_enemy.tags.has("frost_lock"):
		boss_cycle_step = boss_cycle_step % 3 + 1
		if boss_cycle_step == 2: boss_telegraph = "frost_attack"; return [{"type":"boss_telegraph","ability":"frost_attack"}]
		if boss_cycle_step == 3: boss_telegraph = ""; return [{"type":"lock_stack_request","target":"board"}]
		return []
	if current_enemy.tags.has("frost_witch"): return advance_frost_witch_cycle()
	return advance_boss_cycle()

func special_damage(effect:String)->Array[Dictionary]:
	var absorbed:=mini(core_shield,current_enemy.rock_throw_damage);core_shield-=absorbed
	var hp_damage:=current_enemy.rock_throw_damage-absorbed;core_hp=maxi(0,core_hp-hp_damage)
	var events:Array[Dictionary]=[{"type":effect,"target":"core","value":hp_damage,"absorbed":absorbed}]
	if core_hp<=0:events.append({"type":"defeat","target":"core"})
	return events

func advance_frost_witch_cycle()->Array[Dictionary]:
	boss_cycle_step=boss_cycle_step%6+1
	match boss_cycle_step:
		2:boss_telegraph="ice_bolt";return [{"type":"boss_telegraph","ability":"ice_bolt"}]
		3:boss_telegraph="";return special_damage("ice_bolt")
		5:boss_telegraph="frost_seal";return [{"type":"boss_telegraph","ability":"frost_seal"}]
		6:boss_telegraph="";return [{"type":"lock_stack_request","target":"board"}]
	return []

func advance_boss_cycle() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	boss_cycle_step = boss_cycle_step % 6 + 1
	match boss_cycle_step:
		2:
			boss_telegraph = "rock_throw"
			events.append({"type":"boss_telegraph", "ability":"rock_throw"})
		3:
			boss_telegraph = ""
			var absorbed := mini(core_shield, current_enemy.rock_throw_damage)
			core_shield -= absorbed
			var hp_damage := current_enemy.rock_throw_damage - absorbed
			core_hp = maxi(0, core_hp - hp_damage)
			events.append({"type":"rock_throw", "target":"core", "value":hp_damage, "absorbed":absorbed})
			if core_hp <= 0: events.append({"type":"defeat", "target":"core"})
		5:
			boss_telegraph = "stone_lock"
			events.append({"type":"boss_telegraph", "ability":"stone_lock"})
		6:
			boss_telegraph = ""
			events.append({"type":"lock_stack_request", "target":"board"})
	return events

func damage_enemy(amount: int, effect: String, events: Array[Dictionary]) -> void:
	enemy_hp = maxi(0, enemy_hp - amount)
	events.append({"type":"damage", "target":"enemy", "value":amount, "effect":effect})

func advance_enemy_action() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	enemy_action_counter -= 1
	if enemy_action_counter > 0: return events
	enemy_action_counter = current_enemy.attack_interval_triples
	if enemy_frozen:
		enemy_frozen = false; events.append({"type":"frozen_skip", "target":"enemy"}); return events
	var absorbed := mini(core_shield, current_enemy.attack_damage)
	core_shield -= absorbed
	var hp_damage := current_enemy.attack_damage - absorbed
	core_hp = maxi(0, core_hp - hp_damage)
	events.append({"type":"enemy_attack", "target":"core", "value":hp_damage, "absorbed":absorbed})
	if core_hp <= 0: events.append({"type":"defeat", "target":"core"})
	return events
