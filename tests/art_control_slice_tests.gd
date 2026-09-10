extends SceneTree
# ART-02C only: production Rune/Core resource integration and presentation geometry.

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run_tests")

func settle() -> void:
	for frame in 6: await process_frame

func run_tests() -> void:
	root.size = Vector2i(720, 1280)
	root.content_scale_size = Vector2i.ZERO
	var art: VisualLibrary = load("res://resources/visuals/visual_library.tres")
	var background := art.background_texture("stone_ruins")
	var wisp := art.enemy_texture("cave_wisp")
	var fire := art.rune_tile_texture("fire")
	var rune_types := ["fire", "ice", "lightning", "wind", "life", "shield"]
	check(background != null and background.get_size() == Vector2(941, 1672), "Stone Ruins background imports")
	check(wisp != null and wisp is AtlasTexture, "Cave Wisp mapping loads with transparent-padding region")
	check(fire != null and fire.get_width() == fire.get_height(), "Fire full-tile mapping remains square")
	check(art.background_texture("frozen_grove") == null and art.background_texture("eclipse_lands") == null,
		"Other biomes do not inherit Stone Ruins art")
	var all_runes_mapped := true
	var all_rune_paths_exist := true
	for type_id in rune_types:
		var path: String = art.rune_tile_paths.get(type_id, "")
		var texture := art.rune_tile_texture(type_id)
		all_rune_paths_exist = all_rune_paths_exist and not path.is_empty() and FileAccess.file_exists(path)
		all_runes_mapped = all_runes_mapped and texture is AtlasTexture and texture.get_size() == Vector2(1096, 1096)
	check(all_rune_paths_exist, "All six production Rune PNG paths exist")
	check(all_runes_mapped, "All six Rune mappings load the common painted-tile region")
	var core_path_exists := not art.core_path.is_empty() and FileAccess.file_exists(art.core_path)
	var core := art.core_visual_texture()
	check(core_path_exists and core is AtlasTexture and core.get_size() == Vector2(1007, 1007),
		"Production Core path exists and loads with its alpha crop")
	check(art.enemy_texture("moss_slime") != null and art.enemy_texture("stone_brute") != null
		and EnemyCatalog.by_id("moss_slime").texture == null and EnemyCatalog.by_id("stone_brute").texture == null,
		"Stone Ruins enemies use optional VisualLibrary mappings without changing combat resources")

	var absent := VisualLibrary.new()
	absent.background_paths["stone_ruins"] = "res://assets/art/missing-background.png"
	absent.enemy_paths["cave_wisp"] = "res://assets/art/missing-enemy.png"
	absent.rune_tile_paths["fire"] = "res://assets/art/missing-rune.png"
	absent.core_path = "res://assets/art/missing-core.png"
	check(absent.background_texture("stone_ruins") == null and absent.enemy_texture("cave_wisp") == null
		and absent.rune_tile_texture("fire") == null and absent.core_visual_texture() == null,
		"Broken optional Rune/Core paths return null without required-resource failure")

	for viewport_size in [Vector2(720,1280), Vector2(540,960), Vector2(1280,720)]:
		var crop := GameView.cover_source_rect(background.get_size(), viewport_size)
		check(Rect2(Vector2.ZERO, background.get_size()).encloses(crop)
			and is_equal_approx(crop.size.aspect(), viewport_size.aspect()),
			"Cover preserves aspect and stays inside source at %s" % viewport_size)

	var scene: GameView = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene); await settle()
	scene.game.save_enabled = false
	check(scene.game.state == "menu" and scene.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"Main scene starts normally with linear filtering")
	check(scene.run_controller.new_run(101)
		and scene.run_controller.choose_encounter("chapter_1_cave_wisp", scene.run_controller.run.offer_id("encounter")),
		"Normal run API starts Cave Wisp encounter")
	await settle()
	check(scene.game.state == "playing" and scene.game.battle.current_enemy.id == "cave_wisp"
		and not scene.game.battle.is_large_enemy(), "Cave Wisp keeps normal-enemy classification")
	check(scene.has_battle_art() and scene.background_texture() == background,
		"Live Stone Ruins battle resolves the new background")
	check(art.battle_panel_opacity < 1.0 and art.board_panel_opacity < 1.0,
		"Battle and Board backplates expose art")

	var before: Array[Rect2] = []
	for id in scene.game.board.active: before.append(scene.tile_rect(scene.game.board.placement(id)))
	var row_before := scene.tray_slot_rect(0)
	scene.visual_library = absent
	scene.queue_redraw(); await settle()
	var geometry_unchanged := true
	var index := 0
	for id in scene.game.board.active:
		geometry_unchanged = geometry_unchanged and before[index] == scene.tile_rect(scene.game.board.placement(id))
		index += 1
	check(not scene.has_battle_art() and scene.background_texture() == null and scene.game.state == "playing",
		"Missing-art scene renders placeholder path and remains playable")
	check(geometry_unchanged and scene.tray_slot_rect(0) == row_before,
		"Art has no effect on stack hitboxes or Rune Row geometry")
	scene.visual_library = null
	scene.queue_redraw(); await settle()
	check(scene.background_texture() == null and scene.game.state == "playing", "Null visual library also falls back")
	scene.visual_library = art
	var row_tile := scene.tray_slot_rect(0).grow(-5.0)
	row_tile = Rect2(row_tile.get_center() - row_tile.size * 0.92 * 0.5, row_tile.size * 0.92)
	var fitted := GameView.fit_texture_rect(fire, row_tile)
	var family_fits_row := row_tile.encloses(fitted) and is_equal_approx(fitted.size.x, fitted.size.y)
	for type_id in rune_types:
		family_fits_row = family_fits_row and GameView.fit_texture_rect(art.rune_tile_texture(type_id), row_tile) == fitted
	check(family_fits_row, "All six Runes share the existing Row geometry without stretching")
	print("ART-02C METRICS: battle=", scene.battle_rect(), " board=", scene.board_rect(),
		" row_tile=", fitted, " viewport=", scene.size)
	for stack in scene.game.current_level.stacks: print("SMOKE STACK ", stack.stack_id, ": ", stack.tile_types)
	scene.run_controller.abandon_run(scene.run_controller.run.run_instance_id)
	scene.audio.music_player.stop(); scene.audio.sfx_player.stop()
	await create_timer(0.3).timeout
	scene.queue_free(); await process_frame
	print("ART-02C RESOURCES: %d checks, %d failures" % [checks, failures])
	quit(failures)
