extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func layout(columns: Array, id := "fixture") -> LevelDefinition:
	var level := LevelDefinition.new(); level.id = id
	for index in columns.size():
		var stack := StackDefinition.new(); stack.stack_id = index
		stack.tile_types.assign(columns[index]); level.stacks.append(stack)
	return level

func enemy(hp: int) -> EnemyDefinition:
	var value := EnemyDefinition.new(); value.id = "fixture_enemy"
	value.max_hp = hp; value.attack_damage = 0; value.attack_interval_triples = 3
	return value

func _initialize() -> void:
	var balance := BalanceConfig.new()
	var solvable := RunLayoutValidation.validate_pair(enemy(6), layout([["fire", "fire", "fire"]]), balance)
	check(solvable.status == CombatValidator.SOLVABLE, "1 Known solvable fixture")
	var impossible := RunLayoutValidation.validate_pair(enemy(7), layout([["fire", "fire", "fire"]]), balance)
	check(impossible.status == CombatValidator.UNSOLVABLE, "2 Known impossible fixture")
	var limited := RunLayoutValidation.validate_pair(enemy(6), layout([["fire", "fire", "fire"]]), balance, {"max_states":0})
	check(limited.status == CombatValidator.UNKNOWN and limited.reason == "max_states", "3 Exhausted budget is UNKNOWN")
	check(solvable.replay_verified and solvable.reason == "replayed_victory",
		"4 SOLVABLE witness replays through BattleModel")
	var definition: RunDefinition = load("res://resources/runs/m4_run.tres")
	var batch := RunLayoutValidation.validate_runtime_pairs(definition, balance, {"max_states":1})
	var mapped := {}
	for result in batch: mapped[result.enemy_id] = result.layout_id
	check(batch.size() == 15 and mapped.storm_revenant == "level_5" and mapped.eclipse_weaver == "level_20",
		"5 Runtime enemy/layout mapping uses reusable batch path")
	print("M10A runner: 5 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
