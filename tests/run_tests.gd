extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	if value: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)

func _init() -> void:
	var level: LevelDefinition = load("res://resources/levels/level_1.tres")
	check(level != null and level.id == "level_1", "Level 1 loads")
	check(level.placements.size() == 36 and level.placements.size() % 3 == 0, "Level 1 tile count is divisible by three")
	var counts := {}
	for tile in level.placements: counts[tile.type_id] = counts.get(tile.type_id, 0) + 1
	check(counts.size() == 6 and counts.values().all(func(count): return count % 3 == 0), "all six tile types occur in complete triples")

	var board := BoardModel.new(level)
	check(not board.is_available(0) and board.is_available(2), "higher overlapping tile blocks lower tile")
	check(board.remove_tile(0) == null and board.remaining_count() == 36, "blocked tile cannot be selected")
	check(board.remove_tile(2) != null and board.remaining_count() == 35, "available tile is removed from Board")
	check(board.is_available(1), "removing blocker reveals the tile below")

	var tray := TrayModel.new(7)
	tray.add_tile("fire"); tray.add_tile("ice"); tray.add_tile("fire")
	check(tray.tiles == ["fire", "fire", "ice"], "same-type tiles group together")
	var result := tray.add_tile("fire")
	check(result.removed.size() == 3 and tray.tiles == ["ice"], "third matching tile removes exactly one compacted Triple")
	for i in 6: tray.add_tile("wind")
	check(tray.tiles == ["ice"], "multiple possible Triples resolve safely")

	tray.tiles.assign(["ice", "lightning", "wind", "life", "shield", "fire"])
	tray.add_tile("fire"); check(tray.tiles.size() == 7, "Tray reaches 7/7 without a Triple")
	tray.reset(); tray.tiles.assign(["ice", "lightning", "wind", "life", "shield", "fire", "fire"])
	result = tray.add_tile("fire")
	check(result.removed.size() == 3 and not tray.is_full(), "Triple resolves before full-Tray loss check")

	var balance := BalanceConfig.new()
	var controller := GameController.new(); controller.level = level; controller.balance = balance; controller.restart()
	controller.tray.tiles.assign(["fire", "ice", "lightning", "wind", "life", "shield"])
	var open_id: int = controller.board.available_ids()[0]
	controller.select_tile_immediate(open_id)
	check(controller.state == "lost" and controller.tray.tiles.size() == 7, "resolved 7/7 Tray causes Lose")
	controller.restart()
	check(controller.state == "playing" and controller.board.remaining_count() == 36 and controller.tray.tiles.is_empty(), "Restart fully resets Level")
	var solution_valid := true
	for tile_id in level.known_solution:
		if not controller.select_tile_immediate(tile_id): solution_valid = false; break
	check(solution_valid and controller.state == "won" and controller.board.is_empty() and controller.tray.tiles.is_empty(), "known Level 1 solution reaches Win")
	var view := GameView.new()
	check(view.layout_mode_for_size(Vector2(720, 1280)) == "portrait" and view.layout_mode_for_size(Vector2(1280, 720)) == "wide", "portrait and wide responsive modes are deterministic")
	view.free()
	controller.free()

	print("\n", "ALL TESTS PASSED" if failures == 0 else "%d TESTS FAILED" % failures)
	quit(failures)
