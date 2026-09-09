extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)

func _init() -> void:
	call_deferred("run_tests")

func settle() -> void:
	for frame in 5: await process_frame

func run_tests() -> void:
	root.content_scale_size = Vector2i.ZERO
	var scene: GameView = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene); await settle()
	scene.run_controller.new_run()
	scene.game.tray.tiles.assign(["fire", "lightning", "wind", "wind", "ice", "shield"])
	scene.game.battle.enemy_armor = 2; scene.game.battle.enemy_shield = 3; scene.game.battle.core_shield = 5
	scene.game.battle.enemy_action_counter = 1; scene.game.battle.enemy_frozen = true
	scene.update_view()
	var combat := scene.game.battle.hud_data()
	check(scene.prepared_attack_text(combat.attack).contains(scene.tr("UI_FROZEN")) and scene.prepared_attack_text(combat.attack).contains(str(combat.attack.damage)), "prepared attack HUD includes Frozen, countdown and damage")
	for viewport_size in [Vector2i(720,1280), Vector2i(540,960), Vector2i(1280,720)]:
		root.size = viewport_size; scene.size = viewport_size
		scene.request_layout_refresh(); await settle()
		check(scene.tray_label.text.contains("6/7") and scene.tray_label.text.count(scene.tr("UI_ONE_SLOT_LEFT")) == 1, "one Row Label owns occupancy and one-slot warning at %s" % viewport_size)
		var label_rect := Rect2(scene.tray_label.global_position, scene.tray_label.size)
		var font := scene.tray_label.get_theme_font("font")
		var text_width := font.get_string_size(scene.tray_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, scene.tray_label.get_theme_font_size("font_size")).x
		check(text_width <= label_rect.size.x, "combined Row caption fits without clipping at %s" % viewport_size)
		check(scene.tray_rect().grow(9.5).position.y >= label_rect.end.y and label_rect.position.y >= scene.board_rect().end.y, "caption stays between Board and Rune Row, not on slots at %s" % viewport_size)
		check(scene.tray_rect().grow(9.5).end.y <= viewport_size.y + 1, "Rune Row including border stays on screen at %s" % viewport_size)
		var args := OS.get_cmdline_user_args()
		if not args.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(args[0].path_join("m2-row-%dx%d.png" % [viewport_size.x, viewport_size.y]))
	scene.game.tray.tiles.pop_back(); scene.update_view()
	check(not scene.tray_label.text.contains(scene.tr("UI_ONE_SLOT_LEFT")) and scene.tray_label.text.contains("5/7"), "warning clears below six Rune")
	scene.run_controller.abandon_run(scene.run_controller.run.run_instance_id)
	scene.game.play(); scene.game.tray.tiles.assign(["fire", "lightning", "wind", "wind", "ice", "shield"]); scene.update_view()
	check(scene.tray_label.text.contains("6/7") and scene.tray_label.text.count(scene.tr("UI_ONE_SLOT_LEFT")) == 1, "legacy campaign uses the same overlap-free Row caption")
	scene.game.show_main_menu()
	await create_timer(0.8).timeout
	scene.audio.music_player.stop(); scene.audio.sfx_player.stop()
	await create_timer(0.1).timeout
	scene.queue_free(); await process_frame; await create_timer(0.1).timeout
	print("M2 RUNE UI: %d checks, %d failures" % [checks, failures])
	quit(failures)
