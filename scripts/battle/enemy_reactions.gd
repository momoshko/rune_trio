class_name EnemyReactions
extends RefCounted

# Closed, stateless reaction phases. No enemy-ID branches or extra actions.
static func supported(enemy: EnemyDefinition) -> bool:
	return enemy.mechanic in ["NONE", "HEAL_ON_HP_HIT", "RUNE_VULNERABILITY",
		"SHIELD_AFTER_ATTACK", "SHIELD_ON_REPEAT", "HIT_UNSHIELDED",
		"BOOST_ATTACK_ON_REPEAT", "OPEN_ARMOR_ON_DEFENSE", "FAST_AT_HALF_HP",
		"EXTRA_TIMELINE_ON_REPEAT"]

static func uses_triple_history(enemy: EnemyDefinition) -> bool:
	return enemy.mechanic in ["SHIELD_ON_REPEAT", "BOOST_ATTACK_ON_REPEAT", "EXTRA_TIMELINE_ON_REPEAT"]

static func is_attacking_triple(type_id: String) -> bool:
	return type_id in ["fire", "ice", "lightning", "wind"]

static func ignores_armor(enemy: EnemyDefinition, state: Dictionary, type_id: String) -> bool:
	return enemy.mechanic == "OPEN_ARMOR_ON_DEFENSE" and state.get("armor_open", false) and is_attacking_triple(type_id)

static func breaks_enemy_shield(enemy: EnemyDefinition, type_id: String) -> bool:
	return not enemy.shield_break_rune.is_empty() and type_id == enemy.shield_break_rune

static func post_triple_timeline_penalty(enemy: EnemyDefinition, context: Dictionary) -> int:
	if enemy.mechanic == "EXTRA_TIMELINE_ON_REPEAT" and not context.previous_triple_type.is_empty() and context.previous_triple_type == context.triple_type:
		return maxi(0, enemy.mechanic_amount)
	return 0

static func post_spell(enemy: EnemyDefinition, state: Dictionary, context: Dictionary,
		hp_before: int, hp_after: int, attack: PreparedAttack) -> void:
	match enemy.mechanic:
		"BOOST_ATTACK_ON_REPEAT":
			if not context.previous_triple_type.is_empty() and context.previous_triple_type == context.triple_type:
				attack.temporary_damage_bonus = mini(maxi(0, enemy.mechanic_cap),
					attack.temporary_damage_bonus + maxi(0, enemy.mechanic_amount))
		"OPEN_ARMOR_ON_DEFENSE":
			if is_attacking_triple(context.triple_type):
				state.armor_open = false
			elif context.triple_type in ["life", "shield"]:
				state.armor_open = true
		"FAST_AT_HALF_HP":
			if not state.get("fast_attacks_enabled", false) and hp_before > enemy.mechanic_threshold and hp_after <= enemy.mechanic_threshold:
				state.fast_attacks_enabled = true

static func next_attack_interval(enemy: EnemyDefinition, state: Dictionary) -> int:
	if enemy.mechanic == "FAST_AT_HALF_HP" and state.get("fast_attacks_enabled", false):
		return maxi(1, enemy.mechanic_amount)
	return enemy.attack_interval_triples

static func post_triple_shield(enemy: EnemyDefinition, context: Dictionary) -> int:
	if enemy.mechanic == "SHIELD_ON_REPEAT" and not context.previous_triple_type.is_empty() and context.previous_triple_type == context.triple_type:
		return maxi(0, enemy.mechanic_amount)
	return 0

static func attack_damage(enemy: EnemyDefinition, base_damage: int, core_shield: int) -> int:
	# Live pre-attack Shield, AFTER the source Spell; not the pre-Spell snapshot.
	return base_damage + (maxi(0, enemy.mechanic_amount) if enemy.mechanic == "HIT_UNSHIELDED" and core_shield == 0 else 0)

static func post_attack_shield(enemy: EnemyDefinition) -> int:
	# Called only for an executed attack (including fully absorbed damage).
	return maxi(0, enemy.mechanic_amount) if enemy.mechanic == "SHIELD_AFTER_ATTACK" else 0

static func modify_spell(enemy: EnemyDefinition, context: Dictionary, spell: Dictionary) -> Dictionary:
	if enemy.mechanic != "RUNE_VULNERABILITY" or context.triple_type != enemy.vulnerable_rune:
		return spell
	var modified := spell.duplicate()
	var bonus := maxi(0, enemy.mechanic_amount)
	modified.ordinary_damage += bonus
	if not modified.direct: modified.damage += bonus # Legacy main-channel view.
	modified.make_read_only()
	return modified

static func post_attack_healing(enemy: EnemyDefinition, attack: Dictionary) -> int:
	if enemy.mechanic == "HEAL_ON_HP_HIT" and attack.get("hp_damage", 0) > 0:
		return maxi(0, enemy.mechanic_amount)
	return 0
