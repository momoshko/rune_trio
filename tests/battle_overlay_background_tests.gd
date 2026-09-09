extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func settle() -> void:
	for frame in 5: await process_frame

func inject_victory(scene: GameView, hp := 34) -> void:
	var run := scene.run_controller.run
	scene.game.encounter_finished.emit({"run_instance_id":run.run_instance_id,
		"encounter_instance_id":run.current_encounter_instance_id,
		"result_id":run.current_encounter_instance_id + ":overlay", "outcome":"victory", "core_hp":hp})

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	root.size = Vector2i(720, 1280)
	var scene: GameView = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene); await settle()
	scene.game.save_enabled = false
	scene.run_controller.new_run()
	var offers: RunOfferView = scene.get_node("OfferOverlay")
	offers.buttons[0].pressed.emit()
	await settle()
	var battle_board := scene.game.board
	var battle_level := scene.game.current_level

	inject_victory(scene)
	await settle()
	check(offers.visible and offers.color.a > 0.7 and offers.color.a < 1.0
		and scene.get_node("Center").is_visible_in_tree() and scene.game.board == battle_board
		and scene.game.current_level == battle_level,
		"1 Reward overlay keeps the real battle HUD, battlefield and Rune stacks visible")

	offers.buttons[0].pressed.emit()
	await settle()
	check(offers.visible and scene.run_controller.run.status == RunState.Status.ENCOUNTER_CHOICE
		and scene.get_node("Center").is_visible_in_tree() and scene.game.board == battle_board,
		"2 Encounter overlay keeps the previous battle context visible")

	offers.buttons[0].pressed.emit()
	await settle()
	var info: RunInfoView = scene.get_node("InfoOverlay")
	scene.show_current_build()
	await settle()
	check(info.visible and info.color.a > 0.7 and info.color.a < 1.0
		and scene.get_node("Center").is_visible_in_tree() and scene.game.board != null,
		"3 Current Build keeps the active battle screen visible beneath its dimmer")

	var remaining_before := scene.game.board.remaining_count()
	var top := scene.game.board.placement(scene.game.board.available_ids()[0])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	click.position = scene.tile_rect(top).get_center()
	scene._gui_input(click)
	await settle()
	var blocked := scene.game.board.remaining_count() == remaining_before
	info.close_button.pressed.emit()
	await settle()
	check(blocked and not info.visible and scene.get_node("Center").is_visible_in_tree(),
		"4 Modal blocks battle input and Close restores the normal battle presentation")

	scene.run_controller.abandon_run(scene.run_controller.run.run_instance_id)
	scene.audio.music_player.stop(); scene.audio.sfx_player.stop()
	await create_timer(0.3).timeout
	scene.queue_free(); await process_frame
	print("BATTLE OVERLAY BACKGROUND: 4 targeted checks — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
