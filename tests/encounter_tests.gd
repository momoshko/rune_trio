extends SceneTree

var failures := 0
var config := BalanceConfig.new()

func check(value: bool, label: String) -> void:
	if value: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)

func load_levels() -> Array[LevelDefinition]:
	var result: Array[LevelDefinition] = []
	for path in ["res://resources/levels/level_1_mixed.tres", "res://resources/levels/level_2.tres", "res://resources/levels/level_3.tres"]: result.append(load(path))
	return result

func defeat_current(controller: GameController) -> void:
	controller.battle.enemy_hp = config.fire_damage
	controller.resolve_triples(["fire","fire","fire"])

func play_known_route(controller: GameController, level: LevelDefinition) -> void:
	for stack_id in level.known_solution:
		if controller.state != "playing": break
		controller.select_stack_immediate(stack_id)

func _init() -> void:
	var levels := load_levels()
	check(levels[0].encounter_enemy_ids == ["training_dummy"], "Level 1 contains one Training Dummy")
	check(levels[1].encounter_enemy_ids == ["slime","brute"], "Level 2 contains Slime then Brute")
	check(levels[2].encounter_enemy_ids == ["slime","wisp","brute"], "Level 3 contains Slime, Wisp, and Brute")
	var balance_controller := GameController.new(); balance_controller.levels = levels; balance_controller.balance = config
	for i in levels.size():
		balance_controller.start_level(i); play_known_route(balance_controller, levels[i])
		var expected := "won"
		check(balance_controller.state == expected and balance_controller.board.remaining_count() > 0, "Level %d encounter is solvable with Board margin" % (i + 1))
	balance_controller.free()

	var controller := GameController.new(); controller.levels = levels; controller.balance = config; controller.start_level(1)
	var board_ref := controller.board; var tray_ref := controller.tray
	controller.tray.tiles.assign(["ice","wind"]); controller.battle.core_hp = 31; controller.battle.core_shield = 4; controller.battle.enemy_frozen = true
	defeat_current(controller)
	check(controller.current_enemy_number == 2 and controller.battle.current_enemy.id == "brute", "enemy death spawns next queued Enemy")
	check(controller.battle.enemy_action_counter == controller.battle.current_enemy.attack_interval_triples, "new Enemy countdown resets to its definition")
	check(controller.board == board_ref and controller.tray == tray_ref and controller.tray.tiles == ["ice","wind"], "Board and Tray persist between Enemies")
	check(controller.battle.core_hp == 31 and controller.battle.core_shield == 4, "Core HP and Shield persist between Enemies")
	check(not controller.battle.enemy_frozen, "Enemy statuses do not persist to next Enemy")
	var remaining_before := controller.board.remaining_count(); defeat_current(controller)
	check(controller.state == "won" and controller.board.remaining_count() == remaining_before, "last Enemy death immediately completes Level with Board remaining")
	check(controller.next_level() and controller.current_level_index == 2 and controller.current_level.encounter_enemy_ids.size() == 3, "Level 2 completion loads Level 3 encounter through Next Level")

	controller.start_level(0); defeat_current(controller)
	check(controller.state == "won", "Level 1 Victory offers completed state for Next Level")
	check(controller.next_level() and controller.current_level_index == 1 and controller.current_enemy_number == 1 and controller.encounter_total == 2, "Next Level loads Level 2 and its encounter")

	controller.start_level(2); defeat_current(controller); defeat_current(controller); defeat_current(controller)
	check(controller.state == "won", "final configured legacy Level Enemy completes its Level")
	controller.restart_action()
	check(controller.current_level_index == 2 and controller.state == "playing", "Level-complete Restart replays the current Level")

	controller.start_level(1); controller.select_stack_immediate(0); controller.battle.core_hp = 7; controller.restart()
	check(controller.current_level_index == 1 and controller.board.remaining_count() == levels[1].tile_count() and controller.battle.core_hp == config.core_max_hp and controller.current_enemy_number == 1, "Restart restores current Level Board, Core, and encounter")
	controller.board.active.clear(); controller.finish_selection()
	check(controller.state == "exhausted", "empty Board with living Encounter causes insufficient-power Defeat")
	controller.restart(); controller.battle.core_hp = 1; controller.battle.enemy_action_counter = 1; controller.resolve_triples(["fire","fire","fire"])
	check(controller.state == "lost", "Core death remains Defeat")
	controller.restart(); controller.tray.tiles.assign(["fire","ice","lightning","wind","life","shield"]); controller.select_stack_immediate(0)
	check(controller.state == "lost" and controller.tray.is_full(), "full Tray remains Defeat")
	controller.free()

	print("\n", "ALL ENCOUNTER TESTS PASSED" if failures == 0 else "%d ENCOUNTER TESTS FAILED" % failures)
	quit(failures)
