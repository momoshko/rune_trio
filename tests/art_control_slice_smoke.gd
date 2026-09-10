extends SceneTree
# One fixed ART-01C Cave Wisp visual smoke. Uses normal input and the approved runtime layout.
# No generated candidates, solver, CombatValidator, injected combat outcome or gameplay overrides.

var failures := 0
var checks := 0
var captures := 0
var scene: GameView
var output_dir := "res://test-results/art-01c"

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run_smoke")

func settle() -> void:
	for frame in 6: await process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))
	check(error == OK, "Screenshot saved: " + name)
	if error == OK: captures += 1

func click_stack(stack_id: int, expected_type: String) -> bool:
	var top := scene.game.board.top_tile(stack_id)
	if top == null or top.type_id != expected_type:
		check(false, "Expected top " + expected_type + " in stack " + str(stack_id))
		return false
	var position := scene.tile_rect(top).get_center()
	var before := scene.game.board.remaining_count()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position; event.global_position = position
	event.pressed = true
	root.push_input(event, true)
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)
	for tick in 250:
		await create_timer(0.01).timeout
		if not scene.game.busy or scene.game.state != "playing": break
	var ok := scene.game.board.remaining_count() == before - 1
	check(ok, "Normal pointer input selects Top " + expected_type + " from stack " + str(stack_id))
	return ok

func run_smoke() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	root.size = Vector2i(720,1280)
	root.content_scale_size = Vector2i.ZERO
	scene = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene); await settle()
	scene.game.save_enabled = false
	var controller := scene.run_controller
	check(controller.new_run(101)
		and controller.choose_encounter("chapter_1_cave_wisp", controller.run.offer_id("encounter")),
		"Start normal Cave Wisp through public run API")
	await settle()
	check(scene.game.state == "playing" and scene.game.battle.current_enemy.id == "cave_wisp"
		and controller.run.resolved_layouts["0"].layout_id == "cave_wisp_v1_006",
		"Normal Cave Wisp uses the unchanged approved layout")
	var background := scene.background_texture()
	var battle_board := scene.game.board
	await capture("01-cave-wisp-start")

	var moved := await click_stack(4, "fire")
	moved = (await click_stack(1, "ice")) and moved
	await settle()
	check(moved and scene.game.tray.tiles.has("fire") and scene.game.board.top_tile(1).type_id == "fire",
		"Painted Fire is simultaneously visible in stack and Rune Row")
	await capture("02-fire-stack-and-row")

	var art := scene.visual_library
	var enemy_center := Vector2(scene.battle_rect().position.x + scene.battle_rect().size.x * 0.82,
		scene.battle_rect().position.y + 104.0)
	var row_bounds := scene.tray_slot_rect(scene.game.tray.tiles.find("fire")).grow(-5.0)
	row_bounds = Rect2(row_bounds.get_center() - row_bounds.size * 0.92 * 0.5, row_bounds.size * 0.92)
	var metrics := {
		"viewport":str(scene.size), "battle":str(scene.battle_rect()),
		"wisp_texture_rect":str(scene.enemy_art_rect(art.enemy_texture("cave_wisp"), enemy_center, 1.0, false)),
		"fire_stack_hitbox":str(scene.tile_rect(scene.game.board.top_tile(1))),
		"fire_stack_texture_rect":str(GameView.fit_texture_rect(art.rune_tile_texture("fire"), scene.tile_rect(scene.game.board.top_tile(1)))),
		"fire_row_texture_rect":str(GameView.fit_texture_rect(art.rune_tile_texture("fire"), row_bounds)),
		"layout_id":controller.run.resolved_layouts["0"].layout_id,
	}
	var file := FileAccess.open(output_dir.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "\t")); file.close()

	# These five further Top selections complete Fire then Ice triples against this normal enemy.
	for move in [[4,"ice"],[1,"fire"],[1,"fire"],[0,"wind"],[0,"ice"]]:
		if not await click_stack(move[0], move[1]): break
	await create_timer(0.9).timeout
	await settle()
	var offers: RunOfferView = scene.get_node("OfferOverlay")
	check(scene.game.battle.enemy_hp == 0 and controller.run.status == RunState.Status.REWARD and offers.visible,
		"Normal combat victory opens the real reward overlay")
	check(scene.background_texture() == background and scene.game.board == battle_board
		and scene.get_node("Center").is_visible_in_tree(), "Reward keeps the same battle and background")
	await capture("03-stone-ruins-reward")

	# Verify modal input shielding without consuming an offer or changing gameplay.
	var remaining := scene.game.board.remaining_count()
	var candidate := scene.game.board.placement(scene.game.board.available_ids()[0])
	var blocked_click := InputEventMouseButton.new()
	blocked_click.button_index = MOUSE_BUTTON_LEFT; blocked_click.pressed = true
	blocked_click.position = scene.tile_rect(candidate).get_center()
	scene._gui_input(blocked_click)
	check(scene.game.board.remaining_count() == remaining, "Reward overlay blocks board input")
	offers.build_button.pressed.emit(); await settle()
	check(scene.get_node("InfoOverlay").visible and scene.background_texture() == background,
		"Current Build reuses the same Stone Ruins background")
	scene.get_node("InfoOverlay").close_button.pressed.emit(); await settle()

	print("ART-01C VISUAL SMOKE: %d checks, %d failures, %d screenshots; HP=%d, row=%s" %
		[checks, failures, captures, scene.game.battle.core_hp, scene.game.tray.tiles])
	controller.abandon_run(controller.run.run_instance_id)
	# A pending menu crossfade must not restart audio after the test stops its players.
	if scene.audio.music_tween: scene.audio.music_tween.kill()
	scene.audio.music_player.stop(); scene.audio.sfx_player.stop()
	await create_timer(0.3).timeout
	scene.queue_free(); await process_frame
	quit(failures)
