extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	if value: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var scene: GameView = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene); await process_frame
	check(scene.game.state == "menu" and scene.game.board == null and scene.get_node("MainMenu").visible, "application starts at Main Menu")
	scene.game.play(); await process_frame
	var expected_level := mini(scene.game.progress.highest_unlocked_level - 1, scene.game.levels.size() - 1)
	check(scene.game.state == "playing" and scene.game.current_level_index == expected_level and scene.game.can_select(scene.game.board.available_ids()[0]), "Play resumes the highest unlocked Level")
	scene.game.pause_game(); await process_frame
	check(paused and scene.game.state == "paused" and not scene.game.can_select(scene.game.board.available_ids()[0]) and scene.get_node("PauseOverlay").visible, "Pause blocks gameplay while overlay remains active")
	scene.game.continue_game(); await process_frame
	check(not paused and scene.game.state == "playing", "Continue restores gameplay")
	scene.game.start_level(4); var original_count := scene.game.board.remaining_count(); scene.game.select_stack_immediate(scene.game.board.placement(scene.game.board.available_ids()[0]).stack_id)
	scene.game.pause_game(); scene.game.restart(); await process_frame
	check(not paused and scene.game.current_level_index == 4 and scene.game.board.remaining_count() == original_count, "Pause Restart resets current Level")
	scene.game.show_main_menu(); await process_frame
	check(scene.game.state == "menu" and scene.game.board == null and scene.game.battle == null, "Main Menu clears gameplay state")
	scene.game.play(); scene.game.current_level_index = 19; scene.game.state = "campaign_complete"; scene.game.replay_chapter()
	check(scene.game.current_level_index == 0 and scene.game.state == "playing", "Chapter Complete replay starts Level 1")
	scene.queue_free()
	print("\n", "ALL MENU PAUSE TESTS PASSED" if failures == 0 else "%d MENU PAUSE TESTS FAILED" % failures)
	quit(failures)
