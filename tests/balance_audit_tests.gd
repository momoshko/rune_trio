extends SceneTree

const LEVELS := [15, 16, 17, 18, 19, 20]
const DAMAGE := {"fire":6, "ice":3, "lightning":5, "wind":3, "life":0, "shield":0}
var special_routes := {
	15: PackedInt32Array([0,0,0,0,0,0,2,0,4,0,1,0,0,1,3,1,1,4,1,1,2,1,1,3,3,3,1,1,2,2,3,3,2,2,2,2,2,3,3,3]),
	20: PackedInt32Array([0,0,0,0,0,0,2,0,4,0,1,0,0,1,3,1,1,4,1,1,2,1,1,3,3,3,2,2,3,2,2,2,2,2,4,4,4,4,4,2,3,3,3,1,3]),
}

var failures := 0
var balance: BalanceConfig = load("res://resources/balance/default_balance.tres")

func check(value: bool, label: String) -> void:
	if value: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)

func load_level(number: int) -> LevelDefinition:
	return load("res://resources/levels/level_%d.tres" % number)

func counts(level: LevelDefinition) -> Dictionary:
	var result := {}
	for type_id in DAMAGE: result[type_id] = 0
	for stack in level.stacks:
		for type_id in stack.tile_types: result[type_id] += 1
	return result

func potential_damage(level: LevelDefinition) -> int:
	var total := 0
	var type_counts := counts(level)
	for type_id in DAMAGE: total += int(type_counts[type_id] / 3) * DAMAGE[type_id]
	return total

func encounter_hp(level: LevelDefinition) -> int:
	var total := 0
	for enemy_id in level.encounter_enemy_ids: total += EnemyCatalog.by_id(enemy_id).max_hp
	return total

func play(level: LevelDefinition, route: PackedInt32Array) -> Dictionary:
	var controller := GameController.new()
	controller.levels = [level]; controller.balance = balance; controller.save_enabled = false
	controller.start_level(0)
	var valid := true
	for stack_id in route:
		if controller.state != "playing": break
		valid = controller.select_stack_immediate(stack_id) and valid
	var result := {"valid":valid, "state":controller.state, "remaining":controller.board.remaining_count(), "core_hp":controller.battle.core_hp}
	controller.free()
	return result

func _init() -> void:
	for number in LEVELS:
		var level := load_level(number)
		var type_counts := counts(level)
		check(level.tile_count() == 48, "Level %d keeps 48 Tiles" % number)
		check(type_counts.values().all(func(value): return value % 3 == 0), "Level %d type counts form complete Triples" % number)
		check(PuzzleSolver.solve(level).solvable, "Level %d remains puzzle-solvable" % number)
		check(potential_damage(level) >= encounter_hp(level), "Level %d has enough theoretical damage (%d/%d)" % [number, potential_damage(level), encounter_hp(level)])
		var route: PackedInt32Array = special_routes.get(number, level.known_solution)
		var result := play(level, route)
		check(result.valid and result.state in ["won", "campaign_complete"] and result.core_hp > 0, "Level %d has a verified combat-winning route" % number)
		print("AUDIT Level %d counts=%s max_damage=%d enemies_hp=%d route_remaining=%d" % [number, type_counts, potential_damage(level), encounter_hp(level), result.remaining])
	print("\n", "ALL BALANCE AUDIT TESTS PASSED" if failures == 0 else "%d BALANCE AUDIT TESTS FAILED" % failures)
	quit(failures)
