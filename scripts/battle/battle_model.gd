class_name BattleModel
extends RefCounted

var config: BalanceConfig
var core_hp: int
var core_shield := 0
var enemy_hp: int
var enemy_shield := 0
var enemy_armor := 0
var current_enemy: EnemyDefinition
var prepared_attack: PreparedAttack
var enemy_mechanic_state: Dictionary = {}
var current_phase_index := 0
var current_vulnerability_index := 0
var vulnerability_progress := 0
var vulnerability_period_length := 1
var relic_state := EncounterRelicState.new()
var relic_resolver: RelicResolver
var previous_triple_type: String:
	get: return relic_state.previous_type
	set(value): relic_state.previous_type = value
var last_triple_context: Dictionary = {}
var _triple_sequence: int:
	get: return relic_state.total_triples
# Compatibility/debug fields. Only prepared_attack drives combat.
var boss_cycle_step := 0
var boss_telegraph := ""

var enemy_frozen: bool:
	get: return prepared_attack.frozen
	set(value): prepared_attack.frozen = value
var enemy_action_counter: int:
	get: return prepared_attack.countdown
	set(value): prepared_attack.countdown = value

func _init(balance: BalanceConfig, enemy: EnemyDefinition = null, relics: Array[RelicDefinition] = []) -> void:
	config = balance
	relic_resolver = RelicResolver.new(relics)
	reset(enemy)

func reset(enemy: EnemyDefinition = null) -> void:
	core_hp = config.core_max_hp
	core_shield = 0
	relic_state = EncounterRelicState.new()
	last_triple_context = {}
	start_enemy(enemy if enemy else EnemyDefinition.legacy(config))

func start_enemy(definition: EnemyDefinition) -> void:
	current_enemy = definition
	enemy_hp = maxi(0, definition.max_hp)
	current_phase_index = 0
	current_vulnerability_index = 0
	vulnerability_progress = 0
	vulnerability_period_length = definition.vulnerability_period(current_phase_index)
	enemy_armor = maxi(0, definition.phase_armor(current_phase_index))
	enemy_shield = maxi(0, definition.shield)
	enemy_mechanic_state = {"armor_open":false, "fast_attacks_enabled":false}
	prepared_attack = definition.prepare_attack(1, 0, current_phase_index)
	boss_cycle_step = 0
	boss_telegraph = ""

func is_boss() -> bool:
	return current_enemy != null and current_enemy.tags.has("boss")

func is_large_enemy() -> bool:
	return is_boss() or (current_enemy != null and current_enemy.tags.has("mini_boss"))

func capture_triple_context(type_id: String, row_occupancy: int) -> Dictionary:
	# Scalar-only snapshot: no mutable Battle/Row/Attack references escape.
	var context := {"triple_type": type_id, "previous_triple_type": previous_triple_type,
		"triple_sequence": _triple_sequence + 1, "core_hp": core_hp, "core_shield": core_shield,
		"enemy_hp": enemy_hp, "enemy_shield": enemy_shield, "enemy_armor": enemy_armor,
		"row_occupancy": row_occupancy, "attack_countdown": prepared_attack.countdown,
		"attack_frozen": prepared_attack.frozen, "attack_sequence": prepared_attack.sequence,
		"core_max_hp":config.core_max_hp, "consecutive_count":relic_state.consecutive_count,
		"total_triples":relic_state.total_triples, "activation_counts":relic_state.activation_snapshot()}
	context.make_read_only()
	return context

func base_spell_effect(type_id: String) -> Dictionary:
	var effect := {"rune": type_id, "damage": 0, "direct": false, "healing": 0,
		"shield": 0, "freeze": false, "timeline_modifier": 0}
	match type_id:
		"fire": effect.damage = config.fire_damage
		"ice": effect.damage = config.ice_damage; effect.freeze = true
		"lightning": effect.damage = config.lightning_damage; effect.direct = true
		"wind": effect.damage = config.wind_damage; effect.timeline_modifier = 1
		"life": effect.healing = config.life_heal
		"shield": effect.shield = config.shield_gain
		_: return {}
	effect.make_read_only()
	return effect

func apply_triple(type_id: String, before_removal: Dictionary = {}) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not combat_outcome().is_empty(): return events
	var rune_base := base_spell_effect(type_id)
	var base := _apply_cyclic_vulnerability(rune_base, type_id)
	if base.is_empty(): return events
	if not before_removal.is_empty() and (before_removal.get("triple_type", "") != type_id or before_removal.get("triple_sequence", -1) != _triple_sequence + 1):
		return events
	# GameController supplies this snapshot BEFORE removing the matched Rune.
	# Direct battle-only callers have no Row and use occupancy 0.
	last_triple_context = capture_triple_context(type_id, 0) if before_removal.is_empty() else before_removal.duplicate()
	last_triple_context.make_read_only()
	var resolution := relic_resolver.resolve(rune_base, last_triple_context)
	var with_vulnerability := _add_vulnerability_bonus(resolution.effect, type_id)
	var effect := EnemyReactions.modify_spell(current_enemy, last_triple_context, with_vulnerability)
	var hp_before := enemy_hp
	var shield_before := enemy_shield
	var core_before := core_hp
	var core_shield_before := core_shield
	var control := ""
	var ignore_armor := EnemyReactions.ignores_armor(current_enemy, enemy_mechanic_state, type_id)
	if EnemyReactions.breaks_enemy_shield(current_enemy, type_id) and enemy_shield > 0:
		var broken_shield := enemy_shield
		enemy_shield = 0
		events.append({"type":"shield_break", "target":"enemy", "value":broken_shield, "effect":type_id})
	# One aggregate per channel. Direct first; Armor is applied once to ordinary.
	if effect.direct_damage > 0:
		damage_enemy(effect.direct_damage, type_id, events, true)
	if effect.ordinary_damage > 0 and enemy_hp > 0:
		damage_enemy(effect.ordinary_damage, type_id, events, false, ignore_armor)
	if effect.healing > 0:
		var healed := maxi(0, mini(effect.healing, config.core_max_hp - core_hp))
		core_hp += healed
		events.append({"type":"heal", "target":"core", "value":healed, "base_value":effect.healing})
	if effect.shield > 0:
		var gained := maxi(0, mini(effect.shield, config.shield_max - core_shield))
		core_shield += gained
		events.append({"type":"shield", "target":"core", "value":gained, "base_value":effect.shield})
	if effect.freeze and last_triple_context.attack_countdown in [1, 2]:
		if not prepared_attack.frozen:
			prepared_attack.frozen = true
			control = "freeze"
			events.append({"type":"status", "target":"enemy", "effect":"freeze", "attack_sequence":prepared_attack.sequence})
		else: control = "already_frozen"
	elif effect.freeze: control = "outside_freeze_window"
	elif effect.timeline_modifier > 0: control = "delay"
	events.append({"type":"spell_resolved", "rune":type_id, "context":last_triple_context,
		"base_effect":base, "resolved_effect":effect, "activated_relics":resolution.activated,
		"hp_damage":hp_before - enemy_hp, "shield_damage":shield_before - enemy_shield,
		"healing":core_hp - core_before, "shield_gained":core_shield - core_shield_before, "control":control})
	if enemy_hp <= 0:
		events.append({"type":"enemy_defeated", "target":"enemy", "outcome":"victory"})
		relic_state.finish(type_id, resolution.activated)
		return events
	_update_enemy_phase(events)
	_advance_cyclic_vulnerability(events)
	EnemyReactions.post_spell(current_enemy, enemy_mechanic_state, last_triple_context,
		hp_before, enemy_hp, prepared_attack)
	_apply_enemy_reactions(last_triple_context, events)
	var timeline_penalty := EnemyReactions.post_triple_timeline_penalty(current_enemy, last_triple_context)
	events.append_array(advance_enemy_action(effect.timeline_modifier, timeline_penalty))
	relic_state.finish(type_id, resolution.activated)
	return events

func _apply_enemy_reactions(context: Dictionary, events: Array[Dictionary]) -> void:
	_gain_enemy_shield(EnemyReactions.post_triple_shield(current_enemy, context), events)

func _update_enemy_phase(events: Array[Dictionary]) -> void:
	var next := current_enemy.next_phase(current_phase_index, enemy_hp)
	if next == current_phase_index: return
	var previous := current_phase_index
	current_phase_index = next
	enemy_armor = maxi(0, current_enemy.phase_armor(current_phase_index))
	events.append({"type":"phase_changed", "target":"enemy", "from":previous,
		"phase":current_phase_index, "enemy_armor":enemy_armor})

func _apply_cyclic_vulnerability(base: Dictionary, type_id: String) -> Dictionary:
	if base.is_empty() or not current_enemy.has_cyclic_vulnerability(): return base
	if type_id != current_enemy.vulnerability_cycle[current_vulnerability_index]: return base
	var modified := base.duplicate()
	modified.damage += current_enemy.vulnerability_bonus
	modified.make_read_only()
	return modified

func _add_vulnerability_bonus(effect: Dictionary, type_id: String) -> Dictionary:
	if not current_enemy.has_cyclic_vulnerability() or type_id != current_enemy.vulnerability_cycle[current_vulnerability_index]: return effect
	var modified := effect.duplicate()
	modified.damage += current_enemy.vulnerability_bonus
	if modified.direct: modified.direct_damage += current_enemy.vulnerability_bonus
	else: modified.ordinary_damage += current_enemy.vulnerability_bonus
	modified.make_read_only()
	return modified

func _advance_cyclic_vulnerability(events: Array[Dictionary]) -> void:
	if not current_enemy.has_cyclic_vulnerability(): return
	vulnerability_progress += 1
	if vulnerability_progress < vulnerability_period_length: return
	var previous := current_vulnerability_index
	current_vulnerability_index = (current_vulnerability_index + 1) % current_enemy.vulnerability_cycle.size()
	vulnerability_progress = 0
	# A phase change affects only the next full period, never the period in progress.
	vulnerability_period_length = current_enemy.vulnerability_period(current_phase_index)
	events.append({"type":"vulnerability_changed", "target":"enemy", "from":previous,
		"vulnerability":current_vulnerability_index, "period":vulnerability_period_length})

func _gain_enemy_shield(amount: int, events: Array[Dictionary]) -> void:
	if enemy_hp <= 0 or amount <= 0: return
	var cap := maxi(current_enemy.shield, current_enemy.shield_max)
	var gained := maxi(0, mini(amount, cap - enemy_shield))
	enemy_shield += gained
	if gained > 0: events.append({"type":"shield", "target":"enemy", "value":gained, "base_value":amount})

func damage_enemy(amount: int, effect: String, events: Array[Dictionary], direct := false, ignore_armor := false) -> void:
	# One aggregated numeric damage effect, Armor applied exactly once.
	var incoming := maxi(0, amount)
	var armor_blocked := 0 if direct or ignore_armor else mini(incoming, maxi(0, enemy_armor))
	var remaining := incoming - armor_blocked
	var absorbed := 0 if direct else mini(enemy_shield, remaining)
	enemy_shield -= absorbed
	var hp_damage := mini(enemy_hp, remaining - absorbed)
	enemy_hp -= hp_damage
	events.append({"type":"damage", "target":"enemy", "effect":effect, "value":hp_damage,
		"incoming":incoming, "armor_blocked":armor_blocked, "shield_absorbed":absorbed,
		"hp_damage":hp_damage, "direct":direct})

func delay_prepared_attack(amount: int) -> int:
	prepared_attack.countdown = mini(prepared_attack.base_interval + 1, prepared_attack.countdown + maxi(0, amount))
	return prepared_attack.countdown

func advance_enemy_action(timeline_modifier := 0, reaction_penalty := 0) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not combat_outcome().is_empty(): return events
	var before := prepared_attack.countdown
	prepared_attack.countdown -= 1
	# Apply Wind compensation BEFORE checking zero (including 1 -> 0 -> 1).
	if timeline_modifier > 0:
		delay_prepared_attack(timeline_modifier)
		events.append({"type":"delay", "target":"enemy", "value":prepared_attack.countdown})
	# One combined timeline resolution. Reaction cannot create a second attack or carry debt.
	prepared_attack.countdown = maxi(0, prepared_attack.countdown - maxi(0, reaction_penalty))
	if prepared_attack.countdown < before:
		boss_cycle_step = boss_cycle_step % (6 if is_boss() else 3) + 1
	events.append({"type":"timeline", "attack_sequence":prepared_attack.sequence,
		"before":before, "after":prepared_attack.countdown})
	if prepared_attack.countdown > 0:
		boss_telegraph = prepared_attack.telegraph if prepared_attack.countdown == 1 else ""
		if not boss_telegraph.is_empty() and before != prepared_attack.countdown:
			events.append({"type":"boss_telegraph", "ability":boss_telegraph})
		return events
	# No loop: at most one execution/skip; no negative-countdown carry.
	if prepared_attack.frozen:
		events.append({"type":"frozen_skip", "target":"enemy", "attack_sequence":prepared_attack.sequence})
	elif prepared_attack.kind == "lock_stack_request":
		events.append({"type":"lock_stack_request", "target":"board", "attack_sequence":prepared_attack.sequence})
	else:
		var damage := EnemyReactions.attack_damage(current_enemy, prepared_attack.damage, core_shield)
		var attack := apply_core_damage(damage, prepared_attack.kind)
		events.append(attack)
		var healing := EnemyReactions.post_attack_healing(current_enemy, attack)
		if enemy_hp > 0 and healing > 0:
			var gained := maxi(0, mini(healing, current_enemy.max_hp - enemy_hp))
			enemy_hp += gained
			if gained > 0:
				events.append({"type":"heal", "target":"enemy", "value":gained, "base_value":healing})
		_gain_enemy_shield(EnemyReactions.post_attack_shield(current_enemy), events)
	var next_interval := 0 if current_enemy.has_phases() else EnemyReactions.next_attack_interval(current_enemy, enemy_mechanic_state)
	prepared_attack = current_enemy.prepare_attack(prepared_attack.sequence + 1, next_interval, current_phase_index)
	boss_telegraph = ""
	if core_hp <= 0:
		events.append({"type":"defeat", "target":"core", "outcome":"CORE_DESTROYED"})
	return events

func apply_core_damage(amount: int, event_type := "enemy_attack") -> Dictionary:
	var incoming := maxi(0, amount)
	var absorbed := mini(core_shield, incoming)
	core_shield -= absorbed
	var hp_damage := mini(core_hp, incoming - absorbed)
	core_hp -= hp_damage
	return {"type":event_type, "target":"core", "value":hp_damage, "incoming":incoming,
		"absorbed":absorbed, "shield_absorbed":absorbed, "hp_damage":hp_damage,
		"attack_sequence":prepared_attack.sequence}

func combat_outcome() -> String:
	if enemy_hp <= 0: return "victory"
	if core_hp <= 0: return "CORE_DESTROYED"
	return ""

func action_outcome(row_occupancy: int, row_capacity: int, board_has_runes: bool) -> String:
	# Called only after the Row has consumed all automatic matches for this action.
	var outcome := combat_outcome()
	if not outcome.is_empty(): return outcome
	if row_occupancy >= row_capacity: return "ROW_FULL"
	if not board_has_runes: return "BOARD_EXHAUSTED"
	return ""

func hud_data() -> Dictionary:
	var next_attack := current_enemy.attack_entry(current_phase_index, prepared_attack.sequence + 1)
	var vulnerability := {}
	if current_enemy.has_cyclic_vulnerability():
		vulnerability = {"current":current_enemy.vulnerability_cycle[current_vulnerability_index],
			"next":current_enemy.vulnerability_cycle[(current_vulnerability_index + 1) % current_enemy.vulnerability_cycle.size()],
			"bonus":current_enemy.vulnerability_bonus,
			"remaining":vulnerability_period_length - vulnerability_progress,
			"progress":vulnerability_progress, "period":vulnerability_period_length}
	return {"core_hp":core_hp, "core_max_hp":config.core_max_hp, "core_shield":core_shield,
		"core_max_shield":config.shield_max, "enemy_hp":enemy_hp, "enemy_max_hp":current_enemy.max_hp,
		"enemy_shield":enemy_shield, "enemy_armor":enemy_armor, "attack":prepared_attack.snapshot(),
		"phase_index":current_phase_index, "phase_count":current_enemy.phase_count(),
		"phase_mechanic_key":current_enemy.phase_mechanic_key(current_phase_index),
		"next_attack":next_attack, "vulnerability":vulnerability}
