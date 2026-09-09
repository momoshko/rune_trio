extends SceneTree

func _initialize() -> void:
	var catalog: RunDefinition = load("res://resources/runs/m4_run.tres")
	var ids: Array[String] = []
	for encounter in catalog.pool(2, "normal"): ids.append(encounter.enemy_id)
	var ok := catalog.validation_errors().is_empty() and ids == ["ash_knight", "grave_sentinel", "eclipse_acolyte"]
	var game := GameController.new(); game.balance = BalanceConfig.new()
	game.start_run_encounter(catalog.encounter_by_id("chapter_3_ash_knight").battle_level(), 40,
		"smoke", "ash", [])
	var small := LevelDefinition.new(); var stack := StackDefinition.new()
	stack.tile_types.assign(["fire", "fire", "fire", "fire", "fire", "fire"])
	small.stacks.append(stack); game.board = BoardModel.new(small)
	for index in 6: ok = game.select_stack_immediate(0) and ok
	ok = ok and game.battle.prepared_attack.damage == 9 and game.battle.relic_state.total_triples == 2
	game.free()
	print("M7C combat smoke: 1 scenario — ", "PASS" if ok else "FAIL")

	var enemy := EnemyCatalog.by_id("grave_sentinel")
	var battle := BattleModel.new(BalanceConfig.new(), enemy)
	var board := BoardModel.new(small); var tray := TrayModel.new(7)
	var closed_key := CombatValidator.canonical_key(board, tray, battle)
	battle.enemy_mechanic_state.armor_open = true
	var validator_ok := closed_key != CombatValidator.canonical_key(board, tray, battle)
	enemy = EnemyCatalog.by_id("eclipse_acolyte"); battle = BattleModel.new(BalanceConfig.new(), enemy)
	var slow_key := CombatValidator.canonical_key(board, tray, battle)
	battle.enemy_mechanic_state.fast_attacks_enabled = true
	validator_ok = validator_ok and slow_key != CombatValidator.canonical_key(board, tray, battle)
	print("M7C validator state smoke: 1 scenario — ", "PASS" if validator_ok else "FAIL")
	quit(0 if ok and validator_ok else 1)
