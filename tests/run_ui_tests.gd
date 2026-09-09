extends SceneTree

var failures := 0
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)

func _init() -> void:
	call_deferred("run_tests")

func press(scene: GameView, path: String) -> void:
	scene.get_node(path).pressed.emit()

func settle() -> void:
	for frame in 4: await process_frame

func inject(scene: GameView, outcome := "victory", hp := 22) -> void:
	var run := scene.run_controller.run
	scene.game.encounter_finished.emit({"run_instance_id": run.run_instance_id,
		"encounter_instance_id": run.current_encounter_instance_id,
		"result_id": run.current_encounter_instance_id + ":ui_test", "outcome": outcome, "core_hp": hp})

func capture(name: String) -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0].path_join(name + ".png"))

func run_tests() -> void:
	root.content_scale_size = Vector2i.ZERO
	var scene: GameView = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene); await settle()
	var controller := scene.run_controller
	check(scene.game.state == "menu" and scene.get_node("MainMenu/Center/Panel/Play").text == "UI_NEW_RUN", "main menu offers New Run")
	await capture("m1-menu")
	press(scene, "MainMenu/Center/Panel/Play"); press(scene, "MainMenu/Center/Panel/Play")
	await settle()
	check(controller.run.status == RunState.Status.BATTLE and controller.run.current_slot_index == 0, "New Run button starts one attempt")
	check(scene.level_label.text.contains("1/12") and scene.level_label.text.contains(scene.tr("LOCATION_STONE_RUINS")) and scene.level_label.text.contains(scene.tr("UI_RUN_ROLE_NORMAL")), "run HUD displays chapter, battle and role")
	for viewport_size in [Vector2i(720,1280), Vector2i(540,960), Vector2i(1280,720)]:
		root.size = viewport_size; scene.size = viewport_size
		scene.request_layout_refresh(); await settle()
		var battle := scene.battle_rect()
		var board := scene.board_rect()
		var tray := scene.tray_rect()
		check(scene.level_label.global_position.y + scene.level_label.size.y <= battle.position.y and board.position.y >= battle.end.y, "run HUD and board do not overlap battle at %s" % viewport_size)
		check(tray.position.y >= board.end.y and tray.grow(9.5).end.y <= viewport_size.y + 1 and tray.position.x >= 0, "run Tray including border fits viewport at %s" % viewport_size)
		await capture("m1-battle-%dx%d" % [viewport_size.x, viewport_size.y])
	root.size = Vector2i(540,960); scene.size = Vector2(540,960); scene.request_layout_refresh(); await settle()
	press(scene, "PauseButton"); await settle()
	check(paused and controller.run.status == RunState.Status.BATTLE and scene.get_node("PauseOverlay").visible and not scene.get_node("PauseOverlay/Center/Panel/Restart").visible, "run pause has no encounter Restart")
	press(scene, "PauseOverlay/Center/Panel/Menu")
	check(scene.get_node("AbandonOverlay").visible and controller.run.is_active(), "Finish Run asks confirmation")
	await capture("m1-confirm-abandon")
	press(scene, "AbandonOverlay/Center/Panel/Cancel")
	check(paused and not scene.get_node("AbandonOverlay").visible and controller.run.is_active(), "cancel preserves paused run")
	press(scene, "PauseOverlay/Center/Panel/Continue")
	check(not paused and scene.game.state == "playing", "pause Continue resumes same battle")
	var ids: Array[String] = []
	for slot in 12:
		check(controller.run.current_slot_index == slot and not ids.has(controller.run.current_encounter_instance_id), "UI sequence enters unique encounter %d" % (slot + 1))
		ids.append(controller.run.current_encounter_instance_id)
		scene.flights.append({"age":0.0, "slot":0, "type_id":"fire", "from":Vector2.ZERO})
		inject(scene)
		check(scene.overlay.visible and not scene.result_subtitle.text.contains(scene.tr("UI_GOLEM_REWARD")), "run result has no campaign trophy reward")
		if slot < 11:
			check(scene.get_node("ResultOverlay/Center/Panel/Next").visible and not scene.get_node("ResultOverlay/Center/Panel/Restart").visible, "between results offer Continue, no Restart")
			if slot in [3, 7]:
				check(scene.result_subtitle.text.contains(scene.tr("UI_RUN_CHAPTER_COMPLETE").split(":")[0]), "chapter-complete message")
				await capture("m1-chapter-%d-complete" % (slot + 1))
			press(scene, "ResultOverlay/Center/Panel/Next"); press(scene, "ResultOverlay/Center/Panel/Next")
			check(controller.run.current_slot_index == slot + 1 and scene.flights.is_empty() and scene.combat_events.is_empty(), "Continue is idempotent and clears old encounter visuals")
	check(controller.run.status == RunState.Status.VICTORY and scene.result_title.text == scene.tr("UI_RUN_COMPLETE") and scene.result_subtitle.text.contains("12/12"), "final run summary displayed")
	check(not scene.get_node("ResultOverlay/Center/Panel/Next").visible and scene.get_node("ResultOverlay/Center/Panel/Restart").visible, "final screen offers New Run and menu")
	await capture("m1-victory")
	press(scene, "ResultOverlay/Center/Panel/Menu")
	check(scene.game.state == "menu" and not scene.get_node("AbandonOverlay").visible, "terminal menu does not ask abandon")
	for reason in ["ROW_FULL", "CORE_DESTROYED", "BOARD_EXHAUSTED"]:
		press(scene, "MainMenu/Center/Panel/Play")
		inject(scene, reason, 0 if reason == "CORE_DESTROYED" else 12)
		check(controller.run.status == RunState.Status.DEFEAT and scene.result_subtitle.text.contains(scene.tr("UI_RUN_" + reason)), "defeat screen reason " + reason)
		await capture("m1-defeat-" + reason.to_lower())
		var old_id := controller.run.run_instance_id
		press(scene, "ResultOverlay/Center/Panel/Restart")
		check(controller.run.run_instance_id != old_id and scene.game.battle.core_hp == 40, "result New Run starts fresh attempt")
		press(scene, "PauseButton"); press(scene, "PauseOverlay/Center/Panel/Menu")
		press(scene, "AbandonOverlay/Center/Panel/Confirm")
		check(controller.run.status == RunState.Status.ABANDONED and scene.get_node("MainMenu").visible and not paused, "confirmed exit returns to menu")
	press(scene, "MainMenu/Center/Panel/Play"); inject(scene)
	press(scene, "ResultOverlay/Center/Panel/Menu")
	check(scene.get_node("AbandonOverlay").visible, "between-encounter exit also needs confirmation")
	press(scene, "AbandonOverlay/Center/Panel/Confirm")
	scene.game.play(); scene.game.pause_game()
	check(scene.get_node("PauseOverlay/Center/Panel/Restart").visible, "legacy campaign still has Restart")
	scene.game.show_main_menu()
	await create_timer(0.8).timeout
	scene.audio.music_player.stop(); scene.audio.sfx_player.stop()
	await create_timer(0.1).timeout
	scene.queue_free(); await process_frame
	await create_timer(0.1).timeout
	print("RUN UI: %d checks, %d failures" % [checks, failures])
	quit(failures)
