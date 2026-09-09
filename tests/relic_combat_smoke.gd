extends SceneTree

func _initialize() -> void:
	var definition: RunDefinition = load("res://resources/runs/m4_run.tres")
	var results: Array = []
	var ok := true
	for ids in [["brazier_heart", "ember_crown"], ["ember_crown", "brazier_heart"]]:
		var game := GameController.new(); game.balance = BalanceConfig.new()
		var controller := RunController.new(); controller.definition = definition; controller.bind_game(game)
		ok = controller.new_run() and ok
		controller.run.acquired_relic_ids.assign(ids)
		ok = controller.choose_encounter(controller.run.encounter_offer[0], controller.run.offer_id("encounter")) and ok
		# Actual controller/tray flow: two original Fire Triples, with one Rune left.
		var level := LevelDefinition.new(); var stack := StackDefinition.new()
		stack.tile_types.assign(["fire", "fire", "fire", "fire", "fire", "fire", "life"])
		level.stacks.append(stack); game.board = BoardModel.new(level)
		game.battle.enemy_hp = 100
		for index in 6: ok = game.select_stack_immediate(0) and ok
		results.append([game.battle.enemy_hp, game.battle.core_hp, game.battle.prepared_attack.countdown,
			game.battle.relic_state.activation_counts.duplicate()])
		ok = ok and game.battle.enemy_hp == 81 and game.battle.relic_state.total_triples == 2
		# Re-entering an encounter resets counters but carries only owned relics.
		game.start_run_encounter(level, 40, "smoke", "next", [definition.relic_by_id("brazier_heart")])
		ok = ok and game.battle.relic_state.activation_counts.is_empty() and game.battle.previous_triple_type.is_empty()
		game.battle.enemy_hp = 1
		var killing := game.battle.apply_triple("fire")
		ok = ok and game.battle.relic_state.total_triples == 1 and game.battle.previous_triple_type == "fire"
		ok = ok and killing.filter(func(event): return event.type == "timeline").is_empty()
		# Campaign and default BattleModel API used by M3 remain relic-free.
		game.show_main_menu(); game.level = level; game.restart()
		var before := game.battle.enemy_hp
		game.battle.apply_triple("fire")
		ok = ok and before - game.battle.enemy_hp == 6
		controller.free(); game.free()
	ok = ok and results[0] == results[1]
	print("M5 combat/ownership/determinism smoke: 1 scenario — ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
