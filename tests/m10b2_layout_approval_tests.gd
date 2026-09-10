extends SceneTree

var failures := 0
var policy: LayoutApprovalPolicy = load("res://resources/layout_recipes/m10b2_pilot_policy.tres")
var wisp_recipe: LayoutRecipe = load("res://resources/layout_recipes/cave_wisp_pilot.tres")
var brute_recipe: LayoutRecipe = load("res://resources/layout_recipes/stone_brute_pilot.tres")
var wisp: EnemyDefinition = load("res://resources/enemies/cave_wisp.tres")
var brute: EnemyDefinition = load("res://resources/enemies/stone_brute.tres")

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func fixture(types: Array[String]) -> LevelDefinition:
	var level := LevelDefinition.new()
	for index in types.size():
		var stack := StackDefinition.new()
		stack.stack_id = index
		stack.tile_types = [types[index]]
		level.stacks.append(stack)
	return level

func _initialize() -> void:
	var built := LayoutBuilder.build(wisp_recipe, "structural-fixture")
	var tampered: GeneratedLayout = built.layout
	tampered.layout_hash = "tampered"
	var structural := LayoutApproval.evaluate_generated(tampered, wisp_recipe, "structural-fixture", wisp, policy)
	check(structural.stage == "STRUCTURAL_REJECT" and structural.fast_combat_status == LayoutApproval.NOT_RUN,
		"1 Structural reject catches invalid artifact before combat")

	var valid := CombatValidator.solve(fixture(["fire", "fire", "fire"]), _enemy("plain", 3), BalanceConfig.new())
	check(valid.status == CombatValidator.SOLVABLE and LayoutApproval.classify_replay(CombatValidator.replay(valid.witness)) == "REPLAYED",
		"2 SOLVABLE witness replays exactly")
	check(LayoutApproval.classify_replay({"valid":false, "reason":"fixture"}) == LayoutApproval.INVALID_WITNESS,
		"3 Invalid witness is a tool error classification")

	var tiny := policy.duplicate(true) as LayoutApprovalPolicy
	tiny.fast_max_states = 0; tiny.slow_max_states = 0
	var unknown := LayoutApproval.evaluate(wisp_recipe, "unknown-fixture", wisp, tiny, true)
	check(unknown.fast_combat_status == CombatValidator.UNKNOWN and unknown.slow_attempted
		and unknown.combat_status == CombatValidator.UNKNOWN and unknown.quality_status == LayoutApproval.REVIEW,
		"4 UNKNOWN enters one slow retry then REVIEW")

	var diverse_level := fixture(["fire", "fire", "fire", "ice", "ice", "ice"])
	var diverse_enemy := _enemy("plain", 3)
	var primary := CombatValidator.solve(diverse_level, diverse_enemy, BalanceConfig.new())
	var diverse := LayoutApproval._find_alternative(diverse_level, diverse_enemy, primary.witness, policy)
	check(primary.status == CombatValidator.SOLVABLE and diverse.status == "ROUTE_DIVERSITY_CONFIRMED",
		"5 Different first Triple confirms route diversity")
	var no_budget := policy.duplicate(true) as LayoutApprovalPolicy
	no_budget.alternative_max_states = 0
	check(LayoutApproval._find_alternative(diverse_level, diverse_enemy, primary.witness, no_budget).status == "ROUTE_DIVERSITY_UNVERIFIED",
		"6 Exhausted alternative budget stays unverified")

	var pressure := CombatValidator.solve(fixture(["fire", "ice", "wind", "fire", "ice", "wind", "fire"]),
		_enemy("plain", 3), BalanceConfig.new())
	check(pressure.status == CombatValidator.SOLVABLE and pressure.witness.max_row_occupancy == 7
		and pressure.witness.peak_row_after_clear == 6 and pressure.witness.turns_ending_at_row_6 >= 1,
		"7 Pre-clear and post-clear row metrics stay distinct")

	var wisp_fixture := wisp.duplicate(true) as EnemyDefinition
	wisp_fixture.max_hp = 6
	var wisp_trace := CombatValidator.solve(fixture(["ice", "ice", "ice"]), wisp_fixture, BalanceConfig.new())
	var brute_fixture := brute.duplicate(true) as EnemyDefinition
	brute_fixture.max_hp = 1
	var brute_trace := CombatValidator.solve(fixture(["lightning", "lightning", "lightning"]), brute_fixture, BalanceConfig.new())
	check(wisp_trace.status == CombatValidator.SOLVABLE
		and LayoutApproval.mechanic_trace(wisp_fixture, [wisp_trace.witness]).confirmed
		and brute_trace.status == CombatValidator.SOLVABLE
		and LayoutApproval.mechanic_trace(brute_fixture, [brute_trace.witness]).confirmed,
		"8 Wisp vulnerability and Brute armor-counter traces are confirmed")

	var one: GeneratedLayout = LayoutBuilder.build(wisp_recipe, "duplicate-fixture").layout
	var two := GeneratedLayout.new(); two.stacks = one.stacks.duplicate(true); two.stacks.reverse()
	check(LayoutApproval.mechanical_fingerprint(one) == LayoutApproval.mechanical_fingerprint(two)
		and _deterministic_shortlist(), "9 Duplicate fingerprint and shortlist are deterministic")
	print("M10B2: 9 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func _enemy(enemy_id: String, hp: int) -> EnemyDefinition:
	var enemy := EnemyDefinition.new()
	enemy.id = enemy_id; enemy.max_hp = hp; enemy.attack_damage = 1; enemy.attack_interval_triples = 10
	return enemy

func _deterministic_shortlist() -> bool:
	var a: Array[Dictionary] = []
	var b: Array[Dictionary] = []
	for seed in ["deterministic-001", "deterministic-002", "deterministic-003"]:
		var first: GeneratedLayout = LayoutBuilder.build(wisp_recipe, seed).layout
		var second: GeneratedLayout = LayoutBuilder.build(wisp_recipe, seed).layout
		a.append(_result(seed, LayoutApproval.mechanical_fingerprint(first), LayoutApproval.opening_fingerprint(first, wisp_recipe)))
		b.append(_result(seed, LayoutApproval.mechanical_fingerprint(second), LayoutApproval.opening_fingerprint(second, wisp_recipe)))
	LayoutApprovalBatch._apply_duplicate_policy(a); LayoutApprovalBatch._apply_duplicate_policy(b)
	return JSON.stringify(a) == JSON.stringify(b)

func _result(seed: String, mechanical: String, opening: String) -> Dictionary:
	return {"seed":seed, "mechanical_fingerprint":mechanical, "opening_fingerprint":opening,
		"quality_status":LayoutApproval.APPROVED, "stage":"QUALITY",
		"flags":PackedStringArray(), "reasons":PackedStringArray()}
