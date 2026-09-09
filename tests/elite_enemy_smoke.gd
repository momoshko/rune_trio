extends SceneTree

func _initialize() -> void:
	var catalog: RunDefinition = load("res://resources/runs/m4_run.tres")
	var elite_ids: Array[String] = []
	for chapter in 3: elite_ids.append(catalog.pool(chapter, "elite")[0].enemy_id)
	var ok := catalog.validation_errors().is_empty()
	ok = ok and elite_ids == ["stone_guard", "frost_beast", "storm_revenant"]
	var game := GameController.new(); game.balance = BalanceConfig.new()
	game.start_run_encounter(catalog.encounter_by_id("chapter_3_storm_revenant").battle_level(), 40,
		"smoke", "revenant", [])
	var small := LevelDefinition.new(); var stack := StackDefinition.new()
	stack.tile_types.assign(["fire", "fire", "fire", "fire", "fire", "fire"])
	small.stacks.append(stack); game.board = BoardModel.new(small)
	for index in 6: ok = game.select_stack_immediate(0) and ok
	ok = ok and game.battle.prepared_attack.sequence == 2 and game.battle.prepared_attack.countdown == 3
	game.free()
	print("M8 combat smoke: 1 scenario — ", "PASS" if ok else "FAIL")

	var guard := BattleModel.new(BalanceConfig.new(), EnemyCatalog.by_id("stone_guard"))
	var board := BoardModel.new(small); var tray := TrayModel.new(7)
	var first_key := CombatValidator.canonical_key(board, tray, guard)
	guard.prepared_attack.sequence = 3
	var validator_ok := first_key != CombatValidator.canonical_key(board, tray, guard)
	print("M8 validator sequence smoke: 1 scenario — ", "PASS" if validator_ok else "FAIL")
	quit(0 if ok and validator_ok else 1)
