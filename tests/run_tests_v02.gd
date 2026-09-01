extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	if value: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)

func type_counts(level: LevelDefinition) -> Dictionary:
	var counts := {}
	for stack in level.stacks:
		for type_id in stack.tile_types: counts[type_id] = counts.get(type_id, 0) + 1
	return counts

func stack_is_mixed(stack: StackDefinition) -> bool:
	var unique := {}
	for type_id in stack.tile_types: unique[type_id] = true
	return unique.size() > 1

func solve(controller: GameController, level: LevelDefinition) -> bool:
	for stack_id in level.known_solution:
		if not controller.select_stack_immediate(stack_id): return false
	return controller.board.is_empty() and controller.tray.tiles.is_empty()

func _init() -> void:
	var levels: Array[LevelDefinition] = []
	for path in ["res://resources/levels/level_1_mixed.tres", "res://resources/levels/level_2.tres", "res://resources/levels/level_3.tres"]:
		levels.append(load(path))
	for i in levels.size():
		var level := levels[i]
		check(level != null and level.id == "level_%d" % (i + 1), "Level %d loads" % (i + 1))
		var counts := type_counts(level)
		check(level.tile_count() % 3 == 0, "Level %d tile count is divisible by three" % (i + 1))
		check(counts.values().all(func(count): return count % 3 == 0), "Level %d type counts are divisible by three" % (i + 1))
		check(level.stacks.all(func(stack): return stack_is_mixed(stack)), "Level %d stacks are mixed" % (i + 1))

	var board := BoardModel.new(levels[0])
	var first_stack: StackDefinition = levels[0].stacks[0]
	var stack_tiles := board.stack_tiles(first_stack.stack_id)
	check(stack_tiles.size() > 1 and board.is_available(stack_tiles[0].tile_id), "only stack Top is available")
	check(not board.is_available(stack_tiles[1].tile_id) and board.placement(stack_tiles[1].tile_id) != null, "lower Tile remains visible in data but blocked")
	check(board.remove_tile(stack_tiles[1].tile_id) == null, "lower Tile cannot be selected")
	check(board.remove_tile(stack_tiles[0].tile_id) != null and board.is_available(stack_tiles[1].tile_id), "removing Top exposes selectable next Tile")

	var tray := TrayModel.new(7)
	tray.add_tile("fire"); tray.add_tile("ice"); tray.add_tile("fire")
	check(tray.tiles == ["fire","fire","ice"], "Tray still groups matching Tiles")
	var result := tray.add_tile("fire")
	check(result.removed.size() == 3 and tray.tiles == ["ice"], "Triple still removes exactly three Tiles")
	for type_id in ["lightning","wind","life","shield","fire","ice"]: tray.add_tile(type_id)
	check(tray.is_full(), "resolved unmatched 7/7 Tray still causes Lose")

	var controller := GameController.new(); controller.levels = levels; controller.balance = BalanceConfig.new(); controller.battle_enabled = false
	for i in levels.size():
		controller.start_level(i)
		check(solve(controller, levels[i]), "Level %d known solution reaches Win" % (i + 1))
		var expected_state := "won"
		check(controller.state == expected_state, "Level %d reaches correct completion state" % (i + 1))

	controller.start_level(1)
	var original_top_types := levels[1].stacks.map(func(stack): return stack.tile_types[0])
	controller.select_stack_immediate(0); controller.restart()
	check(controller.board.remaining_count() == levels[1].tile_count() and levels[1].stacks.map(func(stack): return stack.tile_types[0]) == original_top_types, "Restart recreates exact deterministic Level")
	controller.start_level(0); solve(controller, levels[0])
	check(controller.next_level() and controller.current_level == levels[1] and controller.current_level_index == 1, "Next Level loads correct definition")
	controller.start_level(2); solve(controller, levels[2])
	check(controller.state == "won" and not controller.next_level(), "configured test campaign stops after its final Level")
	controller.free()

	var view := GameView.new()
	check(view.layout_mode_for_size(Vector2(720,1280)) == "portrait" and view.layout_mode_for_size(Vector2(1280,720)) == "wide", "portrait and wide layout modes remain available")
	view.free()
	print("\n", "ALL TESTS PASSED" if failures == 0 else "%d TESTS FAILED" % failures)
	quit(failures)
