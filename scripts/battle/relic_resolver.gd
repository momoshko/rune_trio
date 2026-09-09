class_name RelicResolver
extends RefCounted

# Only scalar rule data is copied. Rules never receive Battle/Board references,
# execute scripts, emit Triples, or mutate counters during condition evaluation.
var _rules: Array[Dictionary] = []

func _init(relics: Array[RelicDefinition] = []) -> void:
	var unique := {}
	for relic in relics:
		if relic != null and not relic.id.is_empty(): unique[relic.id] = relic
	var ids := unique.keys(); ids.sort()
	for id in ids:
		for rule in unique[id].rules:
			if rule == null: continue
			var copy := {"id":id, "rune":rule.rune, "condition":rule.condition,
				"previous_type":rule.previous_type, "effect":rule.effect, "amount":maxi(0, rule.amount),
				"hp_at_most":rule.hp_at_most, "occupancy_min":rule.occupancy_min,
				"occupancy_max":rule.occupancy_max, "every_n":rule.every_n}
			copy.make_read_only()
			_rules.append(copy)

func resolve(base: Dictionary, context: Dictionary) -> Dictionary:
	var damage_bonus := 0
	var ordinary_bonus := 0
	var healing_bonus := 0
	var shield_bonus := 0
	var timeline_bonus := 0
	var overflow := false
	var activated: Array[String] = []
	for rule in _rules:
		if not _matches(rule, context): continue
		match rule.effect:
			"DAMAGE": damage_bonus += rule.amount
			"ORDINARY_DAMAGE": ordinary_bonus += rule.amount
			"HEALING": healing_bonus += rule.amount
			"SHIELD": shield_bonus += rule.amount
			"ECHO_HALF_BASE":
				# Read BASE only; never echo modifiers, flags, reactions or the timeline.
				damage_bonus += floori(float(base.damage) * 0.5)
				healing_bonus += floori(float(base.healing) * 0.5)
				shield_bonus += floori(float(base.shield) * 0.5)
			"TIMELINE": timeline_bonus += rule.amount
			"OVERFLOW_SHIELD": overflow = true
			_: continue
		if not activated.has(rule.id): activated.append(rule.id)
	var effect := base.duplicate()
	effect.damage += damage_bonus
	# damage/direct remain the M5 main-channel view; apply explicit channels below.
	effect.direct_damage = effect.damage if effect.direct else 0
	effect.ordinary_damage = ordinary_bonus + (0 if effect.direct else effect.damage)
	effect.healing += healing_bonus
	effect.shield += shield_bonus
	effect.timeline_modifier += timeline_bonus
	if overflow:
		effect.shield += maxi(0, int(effect.healing) - maxi(0, int(context.core_max_hp) - int(context.core_hp)))
	effect.make_read_only()
	activated.make_read_only()
	return {"effect":effect, "activated":activated}

func _matches(rule: Dictionary, context: Dictionary) -> bool:
	if rule.rune == "attack":
		if context.triple_type not in ["fire", "ice", "lightning", "wind"]: return false
	elif rule.rune != "*" and rule.rune != context.triple_type: return false
	if rule.hp_at_most >= 0 and context.core_hp > rule.hp_at_most: return false
	if rule.occupancy_min >= 0 and context.row_occupancy < rule.occupancy_min: return false
	if rule.occupancy_max >= 0 and context.row_occupancy > rule.occupancy_max: return false
	if rule.every_n > 0 and (context.total_triples + 1) % rule.every_n != 0: return false
	match rule.condition:
		"ALWAYS": return true
		"SHIELD_EMPTY": return context.core_shield == 0
		"SHIELD_PRESENT": return context.core_shield > 0
		"FIRST_TRIPLE": return context.total_triples == 0
		"FIRST_ACTIVATION": return context.activation_counts.get(rule.id, 0) == 0
		"EVEN_STREAK":
			var streak: int = context.consecutive_count + 1 if context.previous_triple_type == context.triple_type else 1
			return streak % 2 == 0
		"AFTER_TYPE": return context.previous_triple_type == rule.previous_type
		"AFTER_OTHER": return not context.previous_triple_type.is_empty() and context.previous_triple_type != context.triple_type
	return false
