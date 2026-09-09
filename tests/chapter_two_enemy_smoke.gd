extends SceneTree

func _initialize() -> void:
	var catalog: RunDefinition = load("res://resources/runs/m4_run.tres")
	var ids: Array[String] = []
	for encounter in catalog.pool(1, "normal"): ids.append(encounter.enemy_id)
	var ok := catalog.validation_errors().is_empty() and ids == ["crystal_shell", "ice_seer", "snow_leech"]
	var game := GameController.new(); game.balance = BalanceConfig.new()
	game.start_run_encounter(catalog.encounter_by_id("chapter_2_ice_seer").battle_level(), 40, "smoke", "seer",
		[catalog.relic_by_id("ember_crown")])
	var small := LevelDefinition.new(); var stack := StackDefinition.new()
	stack.tile_types.assign(["fire", "fire", "fire", "fire", "fire", "fire", "life"])
	small.stacks.append(stack); game.board = BoardModel.new(small)
	for index in 6: ok = game.select_stack_immediate(0) and ok
	ok = ok and game.battle.enemy_hp == 6 and game.battle.enemy_shield == 3 and game.battle.relic_state.total_triples == 2
	game.free()
	print("M7B combat smoke: 1 scenario — ", "PASS" if ok else "FAIL")
	# Identical puzzle/combat numbers but different previous types are NOT equivalent for Seer.
	var enemy := EnemyCatalog.by_id("ice_seer")
	var battle := BattleModel.new(BalanceConfig.new(), enemy)
	var board := BoardModel.new(small); var tray := TrayModel.new(7)
	battle.previous_triple_type = "fire"
	var key := CombatValidator.canonical_key(board, tray, battle)
	battle.previous_triple_type = "ice"
	var validator_ok := key != CombatValidator.canonical_key(board, tray, battle)
	stack.tile_types.assign(["fire", "fire", "fire", "fire", "fire", "fire", "fire", "fire", "fire", "fire", "fire", "fire"])
	var repeated := CombatValidator.solve(small, enemy, BalanceConfig.new(), {"max_states":32})
	var baseline := enemy.duplicate(true) as EnemyDefinition; baseline.mechanic = "NONE"
	var plain := CombatValidator.solve(small, baseline, BalanceConfig.new(), {"max_states":32})
	validator_ok = validator_ok and repeated.status == CombatValidator.UNSOLVABLE and plain.status == CombatValidator.SOLVABLE and plain.replay_verified
	print("M7B validator/history smoke: 1 scenario — ", "PASS" if validator_ok else "FAIL")
	quit(0 if ok and validator_ok else 1)
