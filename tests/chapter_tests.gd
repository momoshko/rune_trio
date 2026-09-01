extends SceneTree

var failures := 0
var config := BalanceConfig.new()

func check(value: bool, label: String) -> void:
	if value: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)

func load_chapter() -> Array[LevelDefinition]:
	var result: Array[LevelDefinition] = []
	for number in range(1, 11):
		var suffix := "1_mixed" if number == 1 else str(number)
		result.append(load("res://resources/levels/level_%s.tres" % suffix))
	return result

func _init() -> void:
	var levels := load_chapter()
	check(levels.size() == 10 and levels.all(func(level): return level != null), "Chapter 1 contains exactly ten loadable Levels")
	check(levels[0].id == "level_1" and levels[1].id == "level_2" and levels[2].id == "level_3", "Levels 1-3 remain the established resources")
	for i in levels.size():
		var level := levels[i]
		check(level.tile_count() > 0 and level.tile_count() % 3 == 0, "Level %d has a valid Tile count" % (i + 1))
		check(not level.encounter_enemy_ids.is_empty() and level.encounter_enemy_ids.all(func(id): return EnemyCatalog.by_id(id) != null), "Level %d has a valid ordered encounter" % (i + 1))
		var counts := {}
		for stack in level.stacks:
			for type_id in stack.tile_types: counts[type_id] = counts.get(type_id, 0) + 1
		check(counts.values().all(func(count): return count % 3 == 0), "Level %d Tile type counts form intended Triples" % (i + 1))
		var controller := GameController.new(); controller.levels = [level]; controller.balance = config; controller.battle_enabled = false; controller.restart()
		var route_valid := true
		for stack_id in level.known_solution: route_valid = controller.select_stack_immediate(stack_id) and route_valid
		check(route_valid and controller.tray.tiles.is_empty(), "Level %d deterministic known route resolves cleanly" % (i + 1))
		if i < 9: check(controller.board.is_empty() and controller.state == "won", "Level %d known route clears its puzzle" % (i + 1))
		controller.free()
	check(levels[9].boss_id == "stone_golem" and levels[9].encounter_enemy_ids == ["stone_golem"], "Level 10 is the Stone Golem boss Level")
	for i in range(3, 9):
		var combat_route := GameController.new(); combat_route.levels = levels; combat_route.balance = config; combat_route.start_level(i)
		for stack_id in levels[i].known_solution:
			if combat_route.state != "playing": break
			combat_route.select_stack_immediate(stack_id)
		var expected_combat_state := "milestone" if i == 9 else "won"
		check(combat_route.state == expected_combat_state and combat_route.battle.core_hp > 0, "Level %d known route wins its real encounter" % (i + 1))
		combat_route.free()

	var controller := GameController.new(); controller.levels = levels; controller.balance = config
	for i in range(9):
		controller.start_level(i)
		while controller.state == "playing": controller.battle.enemy_hp = 1; controller.resolve_triples(["fire","fire","fire"])
		check(controller.state == "won" and controller.next_level() and controller.current_level_index == i + 1, "Next Level progresses %d to %d" % [i + 1, i + 2])
	controller.start_level(5); controller.select_stack_immediate(controller.board.available_ids()[0]); controller.restart()
	check(controller.current_level_index == 5 and controller.board.remaining_count() == levels[5].tile_count(), "Restart reloads the current Level")
	controller.start_level(9); controller.battle.enemy_hp = 1; controller.resolve_triples(["fire","fire","fire"])
	check(controller.state == "milestone", "Level 10 boss death produces campaign milestone")
	controller.replay_chapter()
	check(controller.current_level_index == 0 and controller.state == "playing", "Chapter replay starts Level 1")
	controller.free()
	print("\n", "ALL CHAPTER TESTS PASSED" if failures == 0 else "%d CHAPTER TESTS FAILED" % failures)
	quit(failures)
