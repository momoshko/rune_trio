class_name CombatValidator
extends RefCounted

# Development-only, single ordinary enemy, base M2 rules. No runtime dependency.
# Prefix reconstruction deliberately trades speed for using the exact controller
# flow (and avoiding a second implementation of combat or mutable-state cloning).
const SOLVABLE := "SOLVABLE"
const UNSOLVABLE := "UNSOLVABLE"
const UNKNOWN := "UNKNOWN"

# limits: max_states=10000, max_depth=-1 (unlimited), time_budget_ms=0 (off).
# Uses only the layout's stacks; the explicit enemy replaces campaign encounters.
# Starts at full Core HP, zero Core Shield and empty Row. No mid-run saves.
static func solve(level: LevelDefinition, enemy: EnemyDefinition, balance: BalanceConfig,
		limits: Dictionary = {}) -> Dictionary:
	var reason := _unsupported(level, enemy, balance)
	if not reason.is_empty(): return _result(UNKNOWN, reason, 0)
	var initial := {"level":level.duplicate(true), "enemy":enemy.duplicate(true),
		"balance":balance.duplicate(true), "core_hp":balance.core_max_hp, "core_shield":0,
		"row":[], "model":"M2_BASE_SINGLE_ENEMY"}
	var max_states := maxi(0, int(limits.get("max_states", 10000)))
	var max_depth := int(limits.get("max_depth", -1))
	var time_ms := int(limits.get("time_budget_ms", 0))
	var deadline := Time.get_ticks_msec() + time_ms if time_ms > 0 else -1
	var frontier: Array[PackedInt32Array] = [PackedInt32Array()]
	var visited := {}
	var explored := 0
	var depth_cutoff := false
	while not frontier.is_empty():
		if _expired(deadline): return _result(UNKNOWN, "time_budget", explored)
		if explored >= max_states: return _result(UNKNOWN, "max_states", explored)
		var path: PackedInt32Array = frontier.pop_back()
		var state := _play(initial, path, deadline)
		if not state.error.is_empty(): return _result(UNKNOWN, state.error, explored)
		var key: String = state.witness.final_state_key
		if visited.has(key): continue
		visited[key] = true
		explored += 1
		if state.outcome == "victory":
			# Mandatory fresh replay, including all witness metrics and final state.
			var checked := replay(state.witness, deadline)
			if not checked.valid: return _result(UNKNOWN, checked.reason, explored)
			var result := _result(SOLVABLE, "replayed_victory", explored)
			result.witness = state.witness
			result.replay_verified = true
			return result
		if not state.outcome.is_empty(): continue
		if max_depth >= 0 and path.size() >= max_depth:
			depth_cutoff = true
			continue
		# Reverse push keeps ascending actual stack IDs as the deterministic DFS order.
		state.moves.reverse()
		for stack_id in state.moves:
			var next := path.duplicate()
			next.append(stack_id)
			frontier.append(next)
	return _result(UNKNOWN if depth_cutoff else UNSOLVABLE,
		"max_depth" if depth_cutoff else "state_space_exhausted", explored)

static func replay(witness: CombatWitness, deadline := -1) -> Dictionary:
	if witness == null or witness.initial_conditions.get("model") != "M2_BASE_SINGLE_ENEMY":
		return {"valid":false, "reason":"invalid_witness"}
	var initial := witness.initial_conditions
	var reason := _unsupported(initial.get("level"), initial.get("enemy"), initial.get("balance"))
	if not reason.is_empty(): return {"valid":false, "reason":reason}
	var result := _play(initial, witness.stack_ids, deadline)
	if not result.error.is_empty(): return {"valid":false, "reason":result.error}
	var valid: bool = result.outcome == "victory" and result.witness.summary() == witness.summary()
	return {"valid":valid, "reason":"replayed_victory" if valid else "replay_mismatch",
		"outcome":result.outcome}

static func _play(initial: Dictionary, path: PackedInt32Array, deadline: int) -> Dictionary:
	var game := GameController.new()
	# Not added to SceneTree: no _ready, save loading, animations, UI or file writes.
	# One isolated encounter, explicit models, no catalog/rewards/progression.
	game.run_mode = true
	game.balance = initial.balance
	game.board = BoardModel.new(initial.level)
	game.tray = TrayModel.new(initial.balance.tray_capacity)
	game.battle = BattleModel.new(initial.balance, initial.enemy)
	game.battle.core_hp = initial.core_hp
	game.battle.core_shield = initial.core_shield
	game.tray.tiles.assign(initial.row)
	game.encounter_total = 1
	game.current_enemy_number = 1
	game.state = "playing"
	var witness := CombatWitness.new()
	witness.initial_conditions = initial
	game.triple_resolved.connect(func(type_id: String): witness.triples.append(type_id))
	game.combat_feedback.connect(func(event: Dictionary):
		if event.get("target", "") == "core":
			witness.hp_damage_received += int(event.get("hp_damage", 0)))
	var error := ""
	game.finish_selection()
	for stack_id in path:
		if _expired(deadline):
			error = "time_budget"
			break
		if game.state != "playing":
			error = "route_after_terminal"
			break
		witness.max_row_occupancy = maxi(witness.max_row_occupancy, game.tray.tiles.size() + 1)
		if not game.select_stack_immediate(stack_id):
			error = "illegal_route"
			break
		witness.stack_ids.append(stack_id)
		witness.action_count += 1
	witness.core_hp = game.battle.core_hp
	witness.enemy_hp = game.battle.enemy_hp
	witness.final_state_key = canonical_key(game.board, game.tray, game.battle)
	var moves: Array[int] = []
	for tile_id in game.board.available_ids(): moves.append(game.board.placement(tile_id).stack_id)
	var outcome := game.battle.action_outcome(game.tray.tiles.size(), game.tray.capacity, not moves.is_empty())
	var result := {"error":error, "outcome":outcome, "moves":moves, "witness":witness}
	game.free()
	return result

static func canonical_key(board: BoardModel, tray: TrayModel, battle: BattleModel) -> String:
	var stacks: Array = []
	for stack in board.level.stacks:
		stacks.append(board.stack_tiles(stack.stack_id).size())
	var row := tray.tiles.duplicate()
	row.sort() # Group order has no effect on M2: only per-type multiplicities matter.
	var attack := battle.prepared_attack
	# Enemy/config/layout are fixed. Relics remain off; only persistent mechanics survive.
	var history := battle.previous_triple_type if EnemyReactions.uses_triple_history(battle.current_enemy) else ""
	return JSON.stringify([stacks, row, battle.core_hp, battle.core_shield,
		battle.enemy_hp, battle.enemy_shield, battle.enemy_armor,
		attack.countdown, attack.frozen, attack.base_interval, attack.base_damage,
		attack.temporary_damage_bonus, attack.kind, attack.sequence, history,
		battle.enemy_mechanic_state.get("armor_open", false),
		battle.enemy_mechanic_state.get("fast_attacks_enabled", false), battle.current_phase_index,
		battle.current_vulnerability_index, battle.vulnerability_progress, battle.vulnerability_period_length])

static func _unsupported(level: LevelDefinition, enemy: EnemyDefinition, balance: BalanceConfig) -> String:
	if level == null or enemy == null or balance == null: return "missing_input"
	if enemy.get_script() != preload("res://scripts/battle/enemy_definition.gd"): return "unsupported_enemy_script"
	# Supported enemy reactions use the keyed combat state/history. Relics stay off.
	if not EnemyReactions.supported(enemy): return "unsupported_enemy_mechanic"
	if not enemy.phases_valid(): return "invalid_enemy_phases"
	# Data-driven phased bosses share the normal combat model; legacy bosses stay unsupported.
	for tag in enemy.tags:
		if tag not in ["tutorial", "mini_boss"] and not (tag == "boss" and enemy.has_phases()): return "unsupported_enemy_tags"
	if balance.tray_capacity <= 0 or balance.core_max_hp <= 0 or enemy.max_hp <= 0:
		return "invalid_initial_conditions"
	var ids := {}
	var probe := BattleModel.new(balance, enemy)
	for stack in level.stacks:
		if stack == null or stack.stack_id < 0 or ids.has(stack.stack_id): return "invalid_stack_ids"
		ids[stack.stack_id] = true
		for rune in stack.tile_types:
			if probe.base_spell_effect(rune).is_empty(): return "unsupported_rune"
	return ""

static func _expired(deadline: int) -> bool:
	return deadline >= 0 and Time.get_ticks_msec() >= deadline

static func _result(status: String, reason: String, explored: int) -> Dictionary:
	return {"status":status, "reason":reason, "explored_states":explored,
		"witness":null, "replay_verified":false}
