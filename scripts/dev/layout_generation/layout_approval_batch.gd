class_name LayoutApprovalBatch
extends RefCounted

static func run(recipe: LayoutRecipe, enemy: EnemyDefinition, policy: LayoutApprovalPolicy,
		candidate_count: int, seed_prefix: String) -> Dictionary:
	var results: Array[Dictionary] = []
	var slow_used := 0
	for index in candidate_count:
		var seed := "%s-%03d" % [seed_prefix, index + 1]
		var result := LayoutApproval.evaluate(recipe, seed, enemy, policy)
		if result.slow_eligible and slow_used < policy.max_slow_candidates_per_enemy:
			result = LayoutApproval.evaluate(recipe, seed, enemy, policy, true)
			slow_used += 1
		results.append(result)
	_apply_duplicate_policy(results)
	for result in results:
		if result.quality_status in [LayoutApproval.APPROVED, LayoutApproval.REVIEW]:
			result.low_hp_probe = LayoutApproval.low_hp_probe(recipe, result.seed, enemy, policy)
	return {"enemy_id":enemy.id, "recipe_id":recipe.recipe_id, "candidate_count":results.size(),
		"slow_queue_used":slow_used, "results":results, "summary":summarize(results)}

static func _apply_duplicate_policy(results: Array[Dictionary]) -> void:
	var exact_seen := {}
	var near_seen := {}
	for result in results:
		if result.quality_status not in [LayoutApproval.APPROVED, LayoutApproval.REVIEW]: continue
		var mechanical: String = result.mechanical_fingerprint
		if exact_seen.has(mechanical):
			result.quality_status = LayoutApproval.REJECT
			result.stage = "DUPLICATE_REJECT"
			result.reasons.append("EXACT_DUPLICATE")
			continue
		exact_seen[mechanical] = result.seed
		var opening: String = result.opening_fingerprint
		if near_seen.has(opening):
			result.quality_status = LayoutApproval.REVIEW
			if "NEAR_DUPLICATE" not in result.flags: result.flags.append("NEAR_DUPLICATE")
		else:
			near_seen[opening] = result.seed

static func summarize(results: Array[Dictionary]) -> Dictionary:
	var summary := {"generated":results.size(), "build_rejected":0, "structural_rejected":0,
		"structural_pass":0, "fast_solvable":0,
		"fast_unsolvable":0, "fast_unknown":0, "slow_attempted":0, "slow_solvable":0,
		"slow_unsolvable":0, "slow_unknown":0, "replayed":0, "approved":0, "review":0,
		"replay_failures":0, "rejected":0, "exact_duplicates":0, "near_duplicates":0,
		"mechanic_confirmed":0, "route_diversity_confirmed":0}
	for result in results:
		if result.stage == "BUILD_REJECT": summary.build_rejected += 1
		if result.stage == "STRUCTURAL_REJECT": summary.structural_rejected += 1
		if result.structural_status == "PASS": summary.structural_pass += 1
		match result.fast_combat_status:
			CombatValidator.SOLVABLE: summary.fast_solvable += 1
			CombatValidator.UNSOLVABLE: summary.fast_unsolvable += 1
			CombatValidator.UNKNOWN: summary.fast_unknown += 1
		if result.slow_attempted:
			summary.slow_attempted += 1
			match result.combat_status:
				CombatValidator.SOLVABLE: summary.slow_solvable += 1
				CombatValidator.UNSOLVABLE: summary.slow_unsolvable += 1
				CombatValidator.UNKNOWN: summary.slow_unknown += 1
		if result.replay_status == "REPLAYED": summary.replayed += 1
		if result.replay_status == LayoutApproval.INVALID_WITNESS: summary.replay_failures += 1
		match result.quality_status:
			LayoutApproval.APPROVED: summary.approved += 1
			LayoutApproval.REVIEW: summary.review += 1
			_: summary.rejected += 1
		if "EXACT_DUPLICATE" in result.reasons: summary.exact_duplicates += 1
		if "NEAR_DUPLICATE" in result.flags: summary.near_duplicates += 1
		if result.mechanic.get("confirmed", false): summary.mechanic_confirmed += 1
		if result.route_diversity == "ROUTE_DIVERSITY_CONFIRMED": summary.route_diversity_confirmed += 1
	return summary
