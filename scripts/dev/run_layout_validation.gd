class_name RunLayoutValidation
extends RefCounted

const DEFAULT_LIMITS := {"max_states":2000, "time_budget_ms":2000}
const RUNES := ["fire", "ice", "lightning", "wind", "life", "shield"]

static func validate_pair(enemy: EnemyDefinition, level: LevelDefinition,
		balance: BalanceConfig, limits: Dictionary = DEFAULT_LIMITS) -> Dictionary:
	var solved := CombatValidator.solve(level, enemy, balance, limits)
	var result := layout_metrics(level)
	result.enemy_id = enemy.id if enemy else ""
	result.layout_id = layout_id(level)
	result.status = solved.status
	result.reason = solved.reason
	result.explored_states = solved.explored_states
	result.replay_verified = solved.replay_verified
	if solved.status == CombatValidator.SOLVABLE:
		var witness: CombatWitness = solved.witness
		result.witness_triples = witness.triples.size()
		result.selected_runes = witness.action_count
		result.ending_core_hp = witness.core_hp
		result.ending_core_shield = witness.core_shield
		result.max_row_occupancy = witness.max_row_occupancy
		result.remaining_board_runes = witness.remaining_board_runes
		result.enemy_attacks_executed = witness.enemy_attacks_executed
		result.frozen_attacks_skipped = witness.frozen_attacks_skipped
		result.first_attacking_triple = _first_attacking_triple(witness.triples)
	else:
		for key in ["witness_triples", "selected_runes", "ending_core_hp", "ending_core_shield",
			"max_row_occupancy", "remaining_board_runes", "enemy_attacks_executed",
			"frozen_attacks_skipped", "first_attacking_triple"]: result[key] = null
	return result

static func validate_runtime_pairs(definition: RunDefinition, balance: BalanceConfig,
		limits: Dictionary = DEFAULT_LIMITS) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for encounter in definition.encounters:
		results.append(validate_pair(EnemyCatalog.by_id(encounter.enemy_id), encounter.level, balance, limits))
	return results

static func layout_metrics(level: LevelDefinition) -> Dictionary:
	var distribution := {}
	var first_depth := {}
	var possible_triples := {}
	for type_id in RUNES:
		distribution[type_id] = 0
		first_depth[type_id] = -1
	var top_runes: Array[String] = []
	var longest_stack_repeat := 0
	for stack in level.stacks:
		if not stack.tile_types.is_empty(): top_runes.append(stack.tile_types[0])
		var prior := ""
		var repeat := 0
		for depth in stack.tile_types.size():
			var type_id: String = stack.tile_types[depth]
			distribution[type_id] = int(distribution.get(type_id, 0)) + 1
			if int(first_depth.get(type_id, -1)) < 0 or depth < int(first_depth[type_id]): first_depth[type_id] = depth
			repeat = repeat + 1 if type_id == prior else 1
			longest_stack_repeat = maxi(longest_stack_repeat, repeat)
			prior = type_id
	for type_id in RUNES: possible_triples[type_id] = int(distribution[type_id]) / 3
	return {"stack_count":level.stacks.size(), "rune_count":level.tile_count(),
		"rune_distribution":distribution, "first_depth":first_depth,
		"possible_triples":possible_triples, "initial_top_runes":top_runes,
		"longest_same_rune_stack_run":longest_stack_repeat}

static func layout_id(level: LevelDefinition) -> String:
	if level == null: return ""
	if not level.id.is_empty(): return level.id
	return level.resource_path.get_file().get_basename()

static func _first_attacking_triple(triples: Array[String]):
	for index in triples.size():
		if triples[index] in ["fire", "ice", "lightning", "wind"]: return index + 1
	return null
