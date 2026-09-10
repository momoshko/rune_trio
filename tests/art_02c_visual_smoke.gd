extends SceneTree
# ART-02C visual-only smoke: normal Cave Wisp encounters, approved runtime layouts,
# normal pointer input and real screenshots. No candidates, solver or gameplay overrides.

const RUNE_TYPES := ["fire", "ice", "lightning", "wind", "life", "shield"]

var failures := 0
var checks := 0
var captures := 0
var scene: GameView
var output_dir := "res://test-results/art-02c"

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

func start_wisp(seed_value: int) -> bool:
	root.size = Vector2i(720,1280)
	root.content_scale_size = Vector2i.ZERO
	scene = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	await settle()
	scene.game.save_enabled = false
	var controller := scene.run_controller
	var started := controller.new_run(seed_value)
	started = controller.choose_encounter("chapter_1_cave_wisp", controller.run.offer_id("encounter")) and started
	await settle()
	check(started and scene.game.state == "playing" and scene.game.battle.current_enemy.id == "cave_wisp",
		"Normal Cave Wisp battle starts through public run API")
	return started

func stop_scene() -> void:
	if scene == null: return
	if scene.run_controller.run.is_active():
		scene.run_controller.abandon_run(scene.run_controller.run.run_instance_id)
	if scene.audio.music_tween: scene.audio.music_tween.kill()
	scene.audio.music_player.stop()
	scene.audio.sfx_player.stop()
	await create_timer(0.3).timeout
	scene.queue_free()
	await process_frame
	scene = null

func click_stack(stack_id: int, expected_type: String) -> bool:
	var top := scene.game.board.top_tile(stack_id)
	if top == null or top.type_id != expected_type:
		check(false, "Expected top " + expected_type + " in stack " + str(stack_id))
		return false
	var position := scene.tile_rect(top).get_center()
	var before := scene.game.board.remaining_count()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
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

func board_types() -> Array[String]:
	var result: Array[String] = []
	for tile in scene.game.board.active.values():
		if tile.type_id not in result: result.append(tile.type_id)
	result.sort()
	return result

func tray_types() -> Array[String]:
	var result: Array[String] = []
	for type_id in scene.game.tray.tiles:
		if type_id not in result: result.append(type_id)
	result.sort()
	return result

func fill_distinct_row(target_count: int) -> void:
	for attempt in 12:
		if tray_types().size() >= target_count or scene.game.state != "playing": return
		var counts := {}
		for type_id in scene.game.tray.tiles: counts[type_id] = int(counts.get(type_id, 0)) + 1
		var candidate = null
		for tile_id in scene.game.board.available_ids():
			var tile = scene.game.board.placement(tile_id)
			if not counts.has(tile.type_id):
				candidate = tile
				break
		if candidate == null:
			for tile_id in scene.game.board.available_ids():
				var tile = scene.game.board.placement(tile_id)
				if int(counts.get(tile.type_id, 0)) < 2:
					candidate = tile
					break
		if candidate == null: return
		if not await click_stack(candidate.stack_id, candidate.type_id): return

func write_metrics(review_types: Array[String], row_types: Array[String]) -> void:
	var art := scene.visual_library
	var battle := scene.battle_rect()
	var core_pos := Vector2(battle.position.x + battle.size.x * .18, battle.position.y + 104.0)
	var core_target := Rect2(core_pos + Vector2(0,-4) - Vector2.ONE * 44.0, Vector2.ONE * 88.0)
	var first_top = scene.game.board.placement(scene.game.board.available_ids()[0])
	var stack_rect := scene.tile_rect(first_top)
	var row_bounds := scene.tray_slot_rect(0).grow(-5.0)
	row_bounds = Rect2(row_bounds.get_center() - row_bounds.size * 0.92 * 0.5, row_bounds.size * 0.92)
	var metrics := {
		"viewport":str(scene.size),
		"battle":str(battle),
		"layout_id":scene.run_controller.run.resolved_layouts["0"].layout_id,
		"board_rune_types":review_types,
		"row_rune_types":row_types,
		"stack_hitbox":str(stack_rect),
		"stack_texture_rect":str(GameView.fit_texture_rect(art.rune_tile_texture(first_top.type_id), stack_rect)),
		"row_texture_rect":str(GameView.fit_texture_rect(art.rune_tile_texture("fire"), row_bounds)),
		"core_texture_rect":str(GameView.fit_texture_rect(art.core_visual_texture(), core_target)),
		"core_visible_height_estimate":88.0 * 981.0 / 1007.0,
	}
	var file := FileAccess.open(output_dir.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "\t"))
	file.close()

func verify_rune_buttons() -> void:
	var bar: HBoxContainer = scene.get_node("Center/Content/HUD/Rows/RuneBar")
	check(bar.get_child_count() == 6 and bar.get_children().all(func(button): return not button.tooltip_text.is_empty()),
		"Existing six Rune info buttons remain visible and labelled")
	var first: Button = bar.get_child(0)
	first.pressed.emit()
	await settle()
	check(scene.get_node("InfoOverlay").visible, "Rune info button still opens its description")
	scene.get_node("InfoOverlay").close_button.pressed.emit()
	await settle()

func review_battle() -> void:
	if not await start_wisp(15): return
	var layout_id := str(scene.run_controller.run.resolved_layouts["0"].layout_id)
	var types := board_types()
	var expected_types: Array[String] = []
	expected_types.assign(RUNE_TYPES)
	expected_types.sort()
	for stack in scene.game.current_level.stacks:
		print("ART-02C REVIEW STACK ", stack.stack_id, ": ", stack.tile_types)
	check(layout_id == "cave_wisp_v1_001", "Review uses fixed approved layout cave_wisp_v1_001")
	check(types == expected_types, "All six painted Rune types coexist in the real Board")
	check(scene.visual_library.core_visual_texture() != null
		and scene.visual_library.enemy_texture("cave_wisp") != null, "Cave Wisp and production Core coexist")
	await capture("01-full-rune-family-core-wisp")
	await fill_distinct_row(4)
	var row_types := tray_types()
	check(row_types.size() >= 4, "Rune Row shows at least four different painted Rune types")
	await capture("02-mixed-painted-rune-row")
	await verify_rune_buttons()
	write_metrics(types, row_types)
	await stop_scene()

func reward_battle() -> void:
	if not await start_wisp(101): return
	check(scene.run_controller.run.resolved_layouts["0"].layout_id == "cave_wisp_v1_006",
		"Reward smoke uses unchanged approved Cave Wisp layout")
	for move in [[4,"fire"],[1,"ice"],[4,"ice"],[1,"fire"],[1,"fire"],[0,"wind"],[0,"ice"]]:
		if not await click_stack(move[0], move[1]): break
	await create_timer(0.9).timeout
	await settle()
	var offers: RunOfferView = scene.get_node("OfferOverlay")
	check(scene.game.battle.enemy_hp == 0 and scene.run_controller.run.status == RunState.Status.REWARD and offers.visible,
		"Normal combat victory opens Reward overlay over the new visual layer")
	await capture("03-reward-overlay-full-visual-layer")
	await stop_scene()

func run_smoke() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	root.size = Vector2i(720,1280)
	root.content_scale_size = Vector2i.ZERO
	await review_battle()
	await reward_battle()
	print("ART-02C VISUAL SMOKE: %d checks, %d failures, %d screenshots" % [checks, failures, captures])
	quit(failures)
