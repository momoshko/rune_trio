extends SceneTree
# ART-03C visual-only resource, phase mapping, portrait and geometry checks.

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
	var expected_regions := {
		"moss_slime":Vector2(1056, 604),
		"cave_wisp":Vector2(900, 990),
		"stone_brute":Vector2(1064, 998),
		"stone_guard":Vector2(961, 1154),
		"stone_golem":Vector2(1209, 981),
	}
	var expected_heights := {
		"moss_slime":90.0, "cave_wisp":96.0, "stone_brute":104.0,
		"stone_guard":110.0, "stone_golem":114.0,
	}
	for enemy_id in expected_regions:
		var path: String = art.enemy_paths.get(enemy_id, "")
		var texture := art.enemy_texture(enemy_id)
		check(not path.is_empty() and FileAccess.file_exists(path), enemy_id + " production PNG path exists")
		check(texture is AtlasTexture and texture.get_size() == expected_regions[enemy_id],
			enemy_id + " loads through its transparent-padding region")

	var phase_one := art.enemy_texture("stone_golem", 0)
	var phase_two := art.enemy_texture("stone_golem", 1)
	check(phase_one != null and phase_two != null and phase_one != phase_two,
		"Stone Golem phases resolve to distinct production textures")
	check(phase_one.get_size() == phase_two.get_size(),
		"Stone Golem phases use an identical source region")
	check(art.enemy_texture("cave_wisp") != null
		and art.enemy_paths["cave_wisp"] == "res://assets/art/enemies/stone_ruins/cave_wisp.png",
		"Existing Cave Wisp mapping remains unchanged")

	var absent := VisualLibrary.new()
	absent.enemy_paths["moss_slime"] = "res://assets/art/enemies/stone_ruins/missing.png"
	check(absent.enemy_texture("moss_slime") == null and absent.enemy_texture("unmapped") == null,
		"Missing and unmapped enemy art safely return null")

	var scene: GameView = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	await settle()
	scene.game.save_enabled = false
	var enemy_center := Vector2(590, 300)
	for enemy_id in expected_heights:
		var texture := art.enemy_texture(enemy_id)
		var rect := scene.enemy_art_rect(texture, enemy_center, 1.0, false, art.enemy_target_size(enemy_id))
		check(absf(rect.size.y - expected_heights[enemy_id]) < 0.2,
			enemy_id + " uses its intended visible battle height")

	var golem_rect_one := scene.enemy_art_rect(phase_one, enemy_center, 1.0, false,
		art.enemy_target_size("stone_golem"))
	var golem_rect_two := scene.enemy_art_rect(phase_two, enemy_center, 1.0, false,
		art.enemy_target_size("stone_golem"))
	check(golem_rect_one == golem_rect_two,
		"Stone Golem phase swap keeps identical Control geometry")

	var golem := EnemyCatalog.by_id("stone_golem")
	var battle := BattleModel.new(scene.game.balance, golem)
	var selected_before := art.enemy_texture(golem.id, battle.current_phase_index)
	battle.enemy_hp = 18
	battle.prepared_attack.countdown = 2
	var transition := battle.apply_triple("fire")
	var selected_after := art.enemy_texture(golem.id, battle.current_phase_index)
	check(battle.current_phase_index == 1 and selected_before == phase_one and selected_after == phase_two
		and transition.any(func(event): return event.type == "phase_changed"),
		"Existing BattleModel phase state selects the Phase II texture")

	var definitions := {
		"moss_slime":[14, 0], "cave_wisp":[12, 0], "stone_brute":[18, 2],
		"stone_guard":[28, 0], "stone_golem":[32, 1],
	}
	for enemy_id in definitions:
		var enemy := EnemyCatalog.by_id(enemy_id)
		check(enemy.max_hp == definitions[enemy_id][0] and enemy.armor == definitions[enemy_id][1],
			enemy_id + " gameplay resource remains unchanged")

	check(scene.run_controller.new_run(37), "Stone Ruins Encounter Choice starts")
	var offers: RunOfferView = scene.get_node("OfferOverlay")
	scene.run_controller.run.encounter_offer.assign([
		"chapter_1_moss_slime", "chapter_1_stone_brute",
	])
	offers.rendered_offer_id = ""
	offers.refresh(scene.run_controller)
	await settle()
	var mapped_portraits := 0
	for card in offers.cards.get_children():
		var portrait_area := card.get_child(0).get_node("PortraitArea")
		if portrait_area.get_child_count() == 1 and portrait_area.get_child(0) is TextureRect:
			mapped_portraits += 1
	check(mapped_portraits == 2, "Encounter Choice reuses both mapped Normal enemy textures")

	if scene.run_controller.run.is_active():
		scene.run_controller.abandon_run(scene.run_controller.run.run_instance_id)
	if scene.audio.music_tween: scene.audio.music_tween.kill()
	scene.audio.music_player.stop()
	scene.audio.sfx_player.stop()
	await create_timer(0.3).timeout
	scene.queue_free()
	await process_frame
	print("ART-03C VISUAL TESTS: %d checks, %d failures" % [checks, failures])
	quit(failures)
