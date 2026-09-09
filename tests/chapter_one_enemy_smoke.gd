extends SceneTree

func _initialize() -> void:
	var catalog: RunDefinition = load("res://resources/runs/m4_run.tres")
	var normal := catalog.pool(0, "normal")
	var ids: Array[String] = []
	for encounter in normal: ids.append(encounter.enemy_id)
	var ok := catalog.validation_errors().is_empty() and ids == ["moss_slime", "cave_wisp", "stone_brute"]
	var game := GameController.new(); game.balance = BalanceConfig.new()
	var run := RunController.new(); run.definition = catalog; run.bind_game(game)
	ok = run.new_run() and ok
	run.run.acquired_relic_ids.assign(["crystal_prism"])
	ok = run.choose_encounter("chapter_1_cave_wisp", run.run.offer_id("encounter")) and ok
	var small := LevelDefinition.new(); var stack := StackDefinition.new()
	stack.tile_types.assign(["shield", "shield", "shield", "ice", "ice", "ice", "life"])
	small.stacks.append(stack); game.board = BoardModel.new(small)
	for index in 6: ok = game.select_stack_immediate(0) and ok
	ok = ok and game.battle.current_enemy.id == "cave_wisp" and game.battle.enemy_hp == 3
	ok = ok and game.battle.core_hp == 40 and game.battle.relic_state.total_triples == 2
	run.free(); game.free()
	print("M7A real combat smoke: 1 scenario — ", "PASS" if ok else "FAIL")
	# Tiny baseline validator proof, not a campaign/layout sweep. No relics.
	stack.tile_types.assign(["ice", "ice", "ice", "ice", "ice", "ice"])
	var solved := CombatValidator.solve(small, EnemyCatalog.by_id("cave_wisp"), BalanceConfig.new(), {"max_states":32})
	var baseline := EnemyCatalog.by_id("cave_wisp").duplicate(true) as EnemyDefinition
	baseline.mechanic = "NONE"
	var insufficient := CombatValidator.solve(small, baseline, BalanceConfig.new(), {"max_states":32})
	var validator_ok: bool = solved.status == CombatValidator.SOLVABLE and solved.replay_verified
	validator_ok = validator_ok and solved.witness.triples == ["ice", "ice"] and insufficient.status == CombatValidator.UNSOLVABLE
	print("M7A validator smoke: 1 scenario — ", "PASS" if validator_ok else "FAIL")
	quit(0 if ok and validator_ok else 1)
