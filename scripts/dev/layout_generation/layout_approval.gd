class_name LayoutApproval
extends RefCounted

const APPROVED := "APPROVED"
const REVIEW := "REVIEW"
const REJECT := "REJECT"
const INVALID_WITNESS := "INVALID_WITNESS"
const NOT_RUN := "NOT_RUN"

static func evaluate(recipe: LayoutRecipe, seed: String, enemy: EnemyDefinition,
		policy: LayoutApprovalPolicy, allow_slow := false) -> Dictionary:
	var result := _base_result(recipe, seed, enemy)
	var built := LayoutBuilder.build(recipe, seed)
	if not built.ok:
		result.stage = "BUILD_REJECT"; result.quality_status = REJECT
		result.reasons = built.errors; return result
	return evaluate_generated(built.layout, recipe, seed, enemy, policy, allow_slow)

static func evaluate_generated(layout: GeneratedLayout, recipe: LayoutRecipe, seed: String,
		enemy: EnemyDefinition, policy: LayoutApprovalPolicy, allow_slow := false) -> Dictionary:
	var result := _base_result(recipe, seed, enemy)
	result.layout_hash = layout.layout_hash
	result.mechanical_fingerprint = mechanical_fingerprint(layout)
	result.opening_fingerprint = opening_fingerprint(layout, recipe)
	var structural_errors := structural_errors(layout, recipe, seed)
	if not structural_errors.is_empty():
		result.stage = "STRUCTURAL_REJECT"; result.quality_status = REJECT
		result.reasons = structural_errors; return result
	result.structural_status = "PASS"
	var level := layout.to_level("candidate_" + layout.layout_hash.substr(0, 12))
	var limits := {"max_states":policy.fast_max_states, "time_budget_ms":policy.fast_time_budget_ms}
	var validation := CombatValidator.solve(level, enemy, BalanceConfig.new(), limits)
	result.fast_combat_status = validation.status
	result.combat_status = validation.status
	result.validator_states = validation.explored_states
	if validation.status == CombatValidator.UNSOLVABLE:
		result.stage = "COMBAT_REJECT"; result.quality_status = REJECT
		result.reasons.append("validator_unsolvable"); return result
	if validation.status == CombatValidator.UNKNOWN:
		result.slow_eligible = true
		if allow_slow:
			result.slow_attempted = true
			validation = CombatValidator.solve(level, enemy, BalanceConfig.new(),
				{"max_states":policy.slow_max_states, "time_budget_ms":policy.slow_time_budget_ms})
			result.combat_status = validation.status
			result.validator_states = validation.explored_states
		if validation.status == CombatValidator.UNSOLVABLE:
			result.stage = "COMBAT_REJECT"; result.quality_status = REJECT
			result.reasons.append("slow_validator_unsolvable"); return result
		if validation.status == CombatValidator.UNKNOWN:
			result.stage = "REVIEW_UNKNOWN"; result.quality_status = REVIEW
			result.flags.append("VALIDATION_UNKNOWN"); return result
	var replay := CombatValidator.replay(validation.witness)
	result.replay_status = classify_replay(replay)
	if result.replay_status == INVALID_WITNESS:
		result.stage = "TOOL_ERROR"; result.combat_status = INVALID_WITNESS
		result.quality_status = REJECT; result.reasons.append("validator_replay_mismatch"); return result
	var witnesses: Array[CombatWitness] = [validation.witness]
	var alternative := _find_alternative(level, enemy, validation.witness, policy)
	result.route_diversity = alternative.status
	result.alternative_searches = alternative.searches
	if alternative.witness != null: witnesses.append(alternative.witness)
	result.metrics = witness_metrics(validation.witness, level.tile_count())
	result.mechanic = mechanic_trace(enemy, witnesses)
	if result.route_diversity != "ROUTE_DIVERSITY_CONFIRMED": result.flags.append("ROUTE_DIVERSITY_UNVERIFIED")
	if not result.mechanic.confirmed: result.flags.append("MECHANIC_NOT_SEEN")
	if float(result.metrics.board_consumed) > policy.consumption_advisory_threshold: result.flags.append("HIGH_CONSUMPTION")
	if int(result.metrics.ending_core_hp) <= policy.low_hp_advisory_threshold: result.flags.append("LOW_HP")
	var row_fraction := float(result.metrics.turns_ending_at_row_6) / maxf(1.0, float(result.metrics.selected_runes))
	if row_fraction >= policy.row_pressure_turn_fraction \
		or int(result.metrics.longest_post_action_row_pressure) >= policy.row_pressure_streak:
		result.flags.append("HIGH_ROW_PRESSURE")
	result.stage = "QUALITY"
	result.quality_status = APPROVED if result.flags.is_empty() else REVIEW
	return result

static func structural_errors(layout: GeneratedLayout, recipe: LayoutRecipe, seed: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if layout.recipe_id != recipe.recipe_id or layout.recipe_version != recipe.recipe_version: errors.append("recipe identity mismatch")
	if layout.generator_version != LayoutBuilder.GENERATOR_VERSION: errors.append("generator version mismatch")
	if layout.layout_hash != LayoutBuilder.canonical_hash(layout.generator_version, layout.recipe_id,
		layout.recipe_version, layout.seed, layout.stacks): errors.append("layout hash mismatch")
	var rebuilt := LayoutBuilder.build(recipe, seed)
	if not rebuilt.ok or rebuilt.layout.layout_hash != layout.layout_hash: errors.append("deterministic rebuild mismatch")
	if layout.stacks.size() < recipe.min_stacks or layout.stacks.size() > recipe.max_stacks: errors.append("stack count out of bounds")
	var total := 0
	var counts := {}; for type_id in LayoutBuilder.RUNES: counts[type_id] = 0
	for stack in layout.stacks:
		total += stack.size()
		if stack.size() < recipe.min_stack_length or stack.size() > recipe.max_stack_length: errors.append("stack length out of bounds")
		var prior := ""; var streak := 0
		for type_id in stack:
			if type_id not in LayoutBuilder.RUNES: errors.append("invalid Rune type: " + str(type_id)); continue
			counts[type_id] += 1
			streak = streak + 1 if type_id == prior else 1; prior = type_id
			if streak > recipe.max_same_type_streak: errors.append("same-type streak exceeded")
	if total < recipe.min_total_runes or total > recipe.max_total_runes: errors.append("total Rune count out of bounds")
	for type_id in LayoutBuilder.RUNES:
		if int(counts[type_id]) < int(recipe.rune_minimums[type_id]) or int(counts[type_id]) > int(recipe.rune_maximums[type_id]):
			errors.append("Rune count out of bounds: " + type_id)
	for constraint in recipe.early_access:
		if _early_count(layout, str(constraint.rune), int(constraint.max_depth)) < int(constraint.required_count):
			errors.append("early access missing: " + str(constraint.rune))
	errors.append_array(_pilot_enemy_errors(layout, recipe, counts, total))
	return errors

static func witness_metrics(witness: CombatWitness, board_runes: int) -> Dictionary:
	return {"triple_count":witness.triples.size(), "selected_runes":witness.action_count,
		"ending_core_hp":witness.core_hp, "ending_core_shield":witness.core_shield,
		"remaining_board_runes":witness.remaining_board_runes,
		"board_consumed":float(witness.action_count) / maxf(1.0, float(board_runes)),
		"enemy_attacks_executed":witness.enemy_attacks_executed,
		"frozen_attacks_skipped":witness.frozen_attacks_skipped,
		"peak_row_before_clear":witness.max_row_occupancy,
		"peak_row_after_clear":witness.peak_row_after_clear,
		"turns_ending_at_row_6":witness.turns_ending_at_row_6,
		"longest_post_action_row_pressure":witness.longest_post_action_row_pressure}

static func mechanic_trace(enemy: EnemyDefinition, witnesses: Array[CombatWitness]) -> Dictionary:
	var trace := {"confirmed":false, "ice_triples":0, "ice_vulnerability_uses":0,
		"lightning_triples":0, "ordinary_attack_triples":0, "armor_reduction_uses":0,
		"enemy_attacks_executed":0, "frozen_attacks_skipped":0}
	for witness in witnesses:
		trace.ice_triples += int(witness.triple_counts.get("ice", 0))
		trace.lightning_triples += int(witness.triple_counts.get("lightning", 0))
		for type_id in ["fire", "ice", "wind"]: trace.ordinary_attack_triples += int(witness.triple_counts.get(type_id, 0))
		trace.ice_vulnerability_uses += witness.vulnerability_bonus_uses
		trace.armor_reduction_uses += witness.armor_reduction_uses
		trace.enemy_attacks_executed += witness.enemy_attacks_executed
		trace.frozen_attacks_skipped += witness.frozen_attacks_skipped
	if enemy.id == "cave_wisp": trace.confirmed = trace.ice_triples > 0 and trace.ice_vulnerability_uses > 0
	elif enemy.id == "stone_brute": trace.confirmed = trace.lightning_triples > 0
	return trace

static func low_hp_probe(recipe: LayoutRecipe, seed: String, enemy: EnemyDefinition,
		policy: LayoutApprovalPolicy) -> String:
	var built := LayoutBuilder.build(recipe, seed)
	if not built.ok: return "LOW_HP_NOT_RUN"
	var validation := CombatValidator.solve(built.layout.to_level(), enemy, BalanceConfig.new(),
		{"max_states":policy.fast_max_states, "time_budget_ms":policy.fast_time_budget_ms,
		"initial_core_hp":policy.low_hp_probe})
	return "LOW_HP_" + validation.status

static func classify_replay(replay: Dictionary) -> String:
	return "REPLAYED" if replay.get("valid", false) else INVALID_WITNESS

static func mechanical_fingerprint(layout: GeneratedLayout) -> String:
	var columns: Array[String] = []
	for stack in layout.stacks: columns.append(">".join(stack))
	columns.sort()
	return _sha("mechanical|" + "||".join(columns))

static func opening_fingerprint(layout: GeneratedLayout, recipe: LayoutRecipe) -> String:
	var lengths := layout.stack_lengths.duplicate(); lengths.sort()
	var openings: Array[String] = []
	for stack in layout.stacks: openings.append(">".join(stack.slice(0, mini(2, stack.size()))))
	openings.sort()
	var counts: Array[String] = []
	for type_id in LayoutBuilder.RUNES: counts.append(type_id + ":" + str(layout.rune_counts[type_id]))
	var early: Array[String] = []
	for constraint in recipe.early_access:
		early.append(str(constraint.rune) + ":" + str(_early_count(layout, str(constraint.rune), int(constraint.max_depth))))
	return _sha("opening|" + JSON.stringify([lengths, counts, openings, early]))

static func _find_alternative(level: LevelDefinition, enemy: EnemyDefinition, primary: CombatWitness,
		policy: LayoutApprovalPolicy) -> Dictionary:
	var base := {"max_states":policy.alternative_max_states, "time_budget_ms":policy.alternative_time_budget_ms}
	if primary.triples.is_empty(): return {"status":"ROUTE_DIVERSITY_UNVERIFIED", "searches":0, "witness":null}
	var search_a := base.duplicate(); search_a.first_triple_not = primary.triples[0]
	var alternative := CombatValidator.solve(level, enemy, BalanceConfig.new(), search_a)
	if alternative.status == CombatValidator.SOLVABLE:
		return {"status":"ROUTE_DIVERSITY_CONFIRMED", "searches":1, "witness":alternative.witness}
	if primary.triples.size() < 2: return {"status":"ROUTE_DIVERSITY_UNVERIFIED", "searches":1, "witness":null}
	var search_b := base.duplicate(); search_b.first_two_not = primary.triples.slice(0, 2)
	alternative = CombatValidator.solve(level, enemy, BalanceConfig.new(), search_b)
	if alternative.status == CombatValidator.SOLVABLE and alternative.witness.triples.slice(0, 2) != primary.triples.slice(0, 2):
		return {"status":"ROUTE_DIVERSITY_CONFIRMED", "searches":2, "witness":alternative.witness}
	return {"status":"ROUTE_DIVERSITY_UNVERIFIED", "searches":2, "witness":null}

static func _pilot_enemy_errors(layout: GeneratedLayout, recipe: LayoutRecipe, counts: Dictionary, total: int) -> PackedStringArray:
	var errors := PackedStringArray()
	var attack_triples := 0
	for type_id in ["fire", "ice", "lightning", "wind"]: attack_triples += int(counts[type_id]) / 3
	if attack_triples < 4: errors.append("insufficient attacking Triple stock")
	if recipe.recipe_id == "cave_wisp_pilot":
		if int(counts.fire) < 6: errors.append("insufficient Fire alternative")
		if int(counts.ice) * 2 >= total: errors.append("Ice dominates layout")
	elif recipe.recipe_id == "stone_brute_pilot":
		if int(counts.lightning) < 6: errors.append("insufficient Lightning stock")
		if int(counts.fire) < 6: errors.append("insufficient ordinary Fire stock")
		if int(counts.lightning) * 2 >= total: errors.append("Lightning dominates layout")
	return errors

static func _early_count(layout: GeneratedLayout, type_id: String, max_depth: int) -> int:
	var count := 0
	for stack in layout.stacks:
		for depth in mini(stack.size(), max_depth + 1):
			if stack[depth] == type_id: count += 1
	return count

static func _sha(value: String) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer()); return context.finish().hex_encode()

static func _base_result(recipe: LayoutRecipe, seed: String, enemy: EnemyDefinition) -> Dictionary:
	return {"enemy_id":enemy.id if enemy else "", "recipe_id":recipe.recipe_id if recipe else "",
		"recipe_version":recipe.recipe_version if recipe else 0,
		"generator_version":LayoutBuilder.GENERATOR_VERSION, "seed":seed, "layout_hash":"",
		"mechanical_fingerprint":"", "opening_fingerprint":"", "stage":"BUILD",
		"structural_status":"NOT_RUN", "fast_combat_status":NOT_RUN, "combat_status":NOT_RUN,
		"replay_status":"NOT_RUN", "quality_status":REJECT, "route_diversity":"NOT_RUN",
		"alternative_searches":0, "slow_eligible":false, "slow_attempted":false,
		"validator_states":0, "metrics":{}, "mechanic":{}, "low_hp_probe":"NOT_RUN",
		"flags":PackedStringArray(), "reasons":PackedStringArray()}
