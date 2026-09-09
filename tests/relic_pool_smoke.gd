extends SceneTree

func _initialize() -> void:
	var catalog: RunDefinition = load("res://resources/runs/m4_run.tres")
	var ok := catalog.relics.size() == 20
	for relic in catalog.relics: ok = ok and not relic.rules.is_empty() and relic.description_key != "M4_RELIC_DESCRIPTION"
	var results: Array = []
	for ids in [["storm_needle", "storm_front", "trinity_mark", "fragile_focus"],
		["fragile_focus", "trinity_mark", "storm_front", "storm_needle"]]:
		var game := GameController.new(); game.balance = BalanceConfig.new()
		var controller := RunController.new(); controller.definition = catalog; controller.bind_game(game)
		ok = controller.new_run() and ok
		controller.run.acquired_relic_ids.assign(ids)
		ok = controller.choose_encounter(controller.run.encounter_offer[0], controller.run.offer_id("encounter")) and ok
		game.battle.enemy_hp = 200; game.battle.enemy_armor = 2; game.battle.enemy_shield = 5
		game.battle.apply_triple("life"); game.battle.apply_triple("wind")
		game.battle.enemy_shield = 5
		var hp_before := game.battle.enemy_hp
		# Pre-removal occupancy 6 must come from the real GameController snapshot.
		var level := LevelDefinition.new(); var stack := StackDefinition.new()
		stack.tile_types.assign(["lightning", "life"]); level.stacks.append(stack)
		game.board = BoardModel.new(level)
		game.tray.tiles.assign(["lightning", "lightning", "fire", "fire", "life"])
		var events: Array[Dictionary] = []
		game.combat_feedback.connect(func(event: Dictionary): events.append(event))
		ok = game.select_stack_immediate(0) and ok
		ok = ok and hp_before - game.battle.enemy_hp == 15 and game.battle.enemy_shield == 3
		ok = ok and game.battle.last_triple_context.row_occupancy == 6 and game.tray.tiles.size() == 3
		ok = ok and events.filter(func(event): return event.type == "timeline").size() == 1
		results.append([game.battle.enemy_hp, game.battle.enemy_shield, game.battle.core_shield,
			game.battle.relic_state.activation_counts.duplicate(), events])
		controller.free(); game.free()
	ok = ok and results[0] == results[1]
	# Constructor/default API shared by campaign and M3 still has no owned relics.
	var baseline := BattleModel.new(BalanceConfig.new())
	var hp := baseline.enemy_hp; baseline.apply_triple("fire")
	ok = ok and hp - baseline.enemy_hp == 6 and baseline.relic_state.activation_counts.is_empty()
	print("M6 four-relic combat smoke: 1 scenario — ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
