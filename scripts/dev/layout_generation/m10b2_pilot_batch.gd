extends SceneTree

const CANDIDATES_PER_ENEMY := 12
const JSON_PATH := "res://M10B2_APPROVED_CANDIDATES.json"
const REPORT_PATH := "res://M10B2_APPROVAL_REPORT.md"

func _initialize() -> void:
	var policy: LayoutApprovalPolicy = load("res://resources/layout_recipes/m10b2_pilot_policy.tres")
	var wisp := LayoutApprovalBatch.run(load("res://resources/layout_recipes/cave_wisp_pilot.tres"),
		load("res://resources/enemies/cave_wisp.tres"), policy, CANDIDATES_PER_ENEMY, "m10b2:cave_wisp")
	var brute := LayoutApprovalBatch.run(load("res://resources/layout_recipes/stone_brute_pilot.tres"),
		load("res://resources/enemies/stone_brute.tres"), policy, CANDIDATES_PER_ENEMY, "m10b2:stone_brute")
	var approved: Array[Dictionary] = []
	for batch in [wisp, brute]:
		for result in batch.results:
			if result.quality_status == LayoutApproval.APPROVED:
				approved.append(_short_candidate(result))
	_write(JSON_PATH, JSON.stringify({"artifact":"M10B2_OFFLINE_SHORTLIST", "runtime_bank":false,
		"candidate_limit_per_enemy":CANDIDATES_PER_ENEMY, "candidates":approved}, "  "))
	_write(REPORT_PATH, _report(wisp, brute, policy))
	print("M10B2 Wisp summary: ", wisp.summary)
	print("M10B2 Brute summary: ", brute.summary)
	print("M10B2 approved shortlist: ", approved.size())
	quit(0)

func _short_candidate(result: Dictionary) -> Dictionary:
	return {"enemy_id":result.enemy_id, "recipe_id":result.recipe_id,
		"recipe_version":result.recipe_version, "generator_version":result.generator_version,
		"seed":result.seed, "layout_hash":result.layout_hash,
		"mechanical_fingerprint":result.mechanical_fingerprint,
		"quality_metrics":result.metrics, "low_hp_probe":result.low_hp_probe}

func _report(wisp: Dictionary, brute: Dictionary, policy: LayoutApprovalPolicy) -> String:
	var lines: Array[String] = ["# Executive Summary", "",
		"One deterministic offline pilot batch processed %d Cave Wisp and %d Stone Brute candidates. This artifact is not a runtime bank." % [wisp.candidate_count, brute.candidate_count], "",
		"Yield: Wisp 1 APPROVED per %.1f generated, Brute 1 per %.1f, overall 1 per %.1f. Most frequent hold reason is reported under Main Rejection Reasons." % [float(wisp.candidate_count) / maxf(1.0, wisp.summary.approved), float(brute.candidate_count) / maxf(1.0, brute.summary.approved), float(wisp.candidate_count + brute.candidate_count) / maxf(1.0, wisp.summary.approved + brute.summary.approved)], "",
		"# Approval Policy", "",
		"Construction remains in LayoutRecipe/LayoutBuilder. Approval uses independent hard gates plus advisory flags; there is no aggregate difficulty score.", "",
		"# Validator Budgets", "",
		"Fast: %d states / %d ms. Slow: %d states / %d ms, one retry, at most %d candidates per enemy. Alternative routes: at most two searches, each %d states / %d ms." % [policy.fast_max_states, policy.fast_time_budget_ms, policy.slow_max_states, policy.slow_time_budget_ms, policy.max_slow_candidates_per_enemy, policy.alternative_max_states, policy.alternative_time_budget_ms], "",
		"# Cave Wisp Batch", "", _summary_line(wisp), "",
		"# Stone Brute Batch", "", _summary_line(brute), "",
		"# Structural Rejections", "", _structural_text(wisp, brute), "",
		"# Solvability Results", "", _solvability_text(wisp, brute), "",
		"# Witness Quality", "", _quality_text(wisp, brute), "",
		"# Route Diversity", "", _route_text(wisp, brute), "",
		"# Row Pressure Findings", "", _row_text(wisp, brute), "",
		"# Mechanic Participation", "", _mechanic_text(wisp, brute), "",
		"# Low-HP Probe", "", "Advisory Core HP 24 results: " + _probe_text(wisp, brute) + ". No candidate is required to win this probe.", "",
		"# Duplicate / Diversity Filtering", "", _duplicate_text(wisp, brute), "",
		"# Approved Wisp Seeds", "", _seed_text(wisp, LayoutApproval.APPROVED), "",
		"# Approved Brute Seeds", "", _seed_text(brute, LayoutApproval.APPROVED), "",
		"# Review Candidates", "", "Wisp: " + _seed_text(wisp, LayoutApproval.REVIEW) + "\n\nBrute: " + _seed_text(brute, LayoutApproval.REVIEW), "",
		"# Main Rejection Reasons", "", _reason_text(wisp, brute), "",
		"# Recipe Problems Found", "", _recipe_text(wisp, brute), "",
		"# Recommendations for M10B3", "",
		"Do not integrate REVIEW/UNKNOWN candidates. Preserve recipe and generator versions in any future bank. Review the pilot yield and mechanic/diversity flags before deciding whether recipe tuning is warranted.", ""]
	return "\n".join(lines)

func _summary_line(batch: Dictionary) -> String:
	var s: Dictionary = batch.summary
	return "Generated %d; build rejected %d; structural rejected %d; fast solvable/unknown/unsolvable %d/%d/%d; slow queue %d; replay failures %d; approved/review/rejected %d/%d/%d; exact/near duplicates %d/%d." % [s.generated, s.build_rejected, s.structural_rejected, s.fast_solvable, s.fast_unknown, s.fast_unsolvable, s.slow_attempted, s.replay_failures, s.approved, s.review, s.rejected, s.exact_duplicates, s.near_duplicates]

func _structural_text(wisp: Dictionary, brute: Dictionary) -> String:
	return "All generated candidates were checked for identity/version, canonical hash, deterministic rebuild, Rune IDs, stack/total/count bounds, streaks, early access, and pilot enemy stock constraints. Rejections: Wisp %d, Brute %d." % [wisp.summary.structural_rejected, brute.summary.structural_rejected]

func _solvability_text(wisp: Dictionary, brute: Dictionary) -> String:
	return "Wisp fast S/U/X: %d/%d/%d. Brute fast S/U/X: %d/%d/%d. Solver state count is tooling diagnostics, not human difficulty." % [wisp.summary.fast_solvable, wisp.summary.fast_unknown, wisp.summary.fast_unsolvable, brute.summary.fast_solvable, brute.summary.fast_unknown, brute.summary.fast_unsolvable]

func _quality_text(wisp: Dictionary, brute: Dictionary) -> String:
	return "Solvable candidates require exact BattleModel witness replay. Quality is expressed as independent consumption, HP, row-pressure, mechanic, and route-diversity flags. Solved-but-filtered candidates: %d." % _solved_filtered(wisp, brute)

func _route_text(wisp: Dictionary, brute: Dictionary) -> String:
	var total: int = wisp.summary.fast_solvable + wisp.summary.slow_solvable + brute.summary.fast_solvable + brute.summary.slow_solvable
	var confirmed: int = wisp.summary.route_diversity_confirmed + brute.summary.route_diversity_confirmed
	return "Confirmed for %d/%d solved candidates (%.1f%%). Budget exhaustion is reported only as ROUTE_DIVERSITY_UNVERIFIED, never as a forced-solution claim." % [confirmed, total, 100.0 * confirmed / maxf(1.0, total)]

func _row_text(wisp: Dictionary, brute: Dictionary) -> String:
	var solved := _solved_results(wisp, brute); var transient_seven := 0; var dangerous := 0
	for result in solved:
		if int(result.metrics.peak_row_before_clear) == 7: transient_seven += 1
		if int(result.metrics.turns_ending_at_row_6) > 0: dangerous += 1
	return "%d/%d replayed wins reached transient pre-clear occupancy 7; %d ended at occupancy 6 at least once. The new post-clear metrics separate normal Triple-clearing transients from sustained danger." % [transient_seven, solved.size(), dangerous]

func _mechanic_text(wisp: Dictionary, brute: Dictionary) -> String:
	return "Cave Wisp special Ice interaction confirmed in %d candidates. Stone Brute Lightning counter access confirmed in %d candidates. Early key-Rune guarantees provided the intended access structurally; confirmation still depends on a winning route." % [wisp.summary.mechanic_confirmed, brute.summary.mechanic_confirmed]

func _probe_text(wisp: Dictionary, brute: Dictionary) -> String:
	var counts := {}
	for result in wisp.results + brute.results:
		if result.low_hp_probe != "NOT_RUN": counts[result.low_hp_probe] = int(counts.get(result.low_hp_probe, 0)) + 1
	return JSON.stringify(counts)

func _duplicate_text(wisp: Dictionary, brute: Dictionary) -> String:
	return "Mechanical exact fingerprints rejected %d column-permutation duplicates; opening fingerprints flagged %d near duplicates deterministically." % [wisp.summary.exact_duplicates + brute.summary.exact_duplicates, wisp.summary.near_duplicates + brute.summary.near_duplicates]

func _seed_text(batch: Dictionary, status: String) -> String:
	var seeds: Array[String] = []
	for result in batch.results:
		if result.quality_status == status: seeds.append("`%s`" % result.seed)
	return ", ".join(seeds) if not seeds.is_empty() else "None in this pilot batch."

func _reason_text(wisp: Dictionary, brute: Dictionary) -> String:
	var counts := {}
	for result in wisp.results + brute.results:
		for reason in result.reasons: counts[reason] = int(counts.get(reason, 0)) + 1
		if result.quality_status == LayoutApproval.REVIEW:
			for flag in result.flags: counts[flag] = int(counts.get(flag, 0)) + 1
	var pairs: Array[String] = []
	for key in counts: pairs.append("%s=%d" % [key, counts[key]])
	pairs.sort()
	return ", ".join(pairs) if not pairs.is_empty() else "No rejection or review reasons."

func _recipe_text(wisp: Dictionary, brute: Dictionary) -> String:
	return "Wisp yield is %s; Brute yield is %s. A recipe is treated as too narrow only when structural/build rejection dominates, and too broad when many structurally valid candidates fail combat or quality; this small pilot does not auto-tune either recipe." % [_recipe_shape(wisp), _recipe_shape(brute)]

func _recipe_shape(batch: Dictionary) -> String:
	var s: Dictionary = batch.summary
	if s.build_rejected + s.structural_rejected > s.generated / 2.0: return "narrow"
	if s.fast_unsolvable + s.fast_unknown + s.review > s.generated / 2.0: return "broad/noisy"
	return "normal for this pilot"

func _solved_filtered(wisp: Dictionary, brute: Dictionary) -> int:
	var count := 0
	for result in wisp.results + brute.results:
		if result.replay_status == "REPLAYED" and result.quality_status != LayoutApproval.APPROVED: count += 1
	return count

func _solved_results(wisp: Dictionary, brute: Dictionary) -> Array[Dictionary]:
	var solved: Array[Dictionary] = []
	for result in wisp.results + brute.results:
		if result.replay_status == "REPLAYED": solved.append(result)
	return solved

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
