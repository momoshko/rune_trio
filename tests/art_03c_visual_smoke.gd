extends SceneTree
# ART-03C rendered smoke: real scene, existing battle state and screenshots only.

var checks := 0
var failures := 0
var captures := 0
var scene: GameView
var output_dir := "res://test-results/art-03c"

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run_smoke")

func settle() -> void:
	for frame in 8: await process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))
	check(error == OK, "Screenshot saved: " + name)
	if error == OK: captures += 1

func start_battle(encounter_id: String, slot: int) -> bool:
	root.size = Vector2i(720, 1280)
	root.content_scale_size = Vector2i.ZERO
	scene = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	await settle()
	scene.game.save_enabled = false
	var encounter := scene.run_controller.definition.encounter_by_id(encounter_id)
	scene.run_controller.run = RunState.new()
	scene.run_controller.run.run_instance_id = "art03c"
	scene.run_controller.run.seed = 303
	scene.run_controller.run.boundary_hp = scene.run_controller.definition.initial_hp
	scene.run_controller.run.current_slot_index = slot
	scene.run_controller.run.current_encounter_instance_id = "art03c:" + encounter_id
	scene.run_controller.run.selected_encounter_id = encounter_id
	scene.run_controller.run.status = RunState.Status.BATTLE
	scene.game.start_run_encounter(encounter.battle_level(), scene.run_controller.run.boundary_hp,
		"art03c", scene.run_controller.run.current_encounter_instance_id, [])
	await settle()
	scene.intro_time = 0.0
	scene.queue_redraw()
	await settle()
	var ok := scene.game.state == "playing" and scene.game.battle.current_enemy.id == encounter.enemy_id
	check(ok, encounter.enemy_id + " battle starts in the real main scene")
	return ok

func stop_scene() -> void:
	if scene == null: return
	if scene.audio.music_tween: scene.audio.music_tween.kill()
	scene.audio.music_player.stop()
	scene.audio.sfx_player.stop()
	await create_timer(0.25).timeout
	scene.queue_free()
	await process_frame
	scene = null

func capture_battle(encounter_id: String, slot: int, file_name: String) -> void:
	if await start_battle(encounter_id, slot):
		await capture(file_name)
	await stop_scene()

func capture_golem_phases() -> void:
	if not await start_battle("chapter_1_stone_golem", 3):
		await stop_scene()
		return
	var art := scene.visual_library
	var battle := scene.game.battle
	var enemy_center := Vector2(scene.battle_rect().position.x + scene.battle_rect().size.x * .82,
		scene.battle_rect().position.y + 104.0)
	var first_rect := scene.enemy_art_rect(art.enemy_texture("stone_golem", battle.current_phase_index),
		enemy_center, 1.0, false, art.enemy_target_size("stone_golem"))
	await capture("05-stone-golem-phase-1")
	battle.enemy_hp = 18
	battle.prepared_attack.countdown = 2
	var events := battle.apply_triple("fire")
	scene.update_view()
	await settle()
	var second_rect := scene.enemy_art_rect(art.enemy_texture("stone_golem", battle.current_phase_index),
		enemy_center, 1.0, false, art.enemy_target_size("stone_golem"))
	check(battle.current_phase_index == 1
		and events.any(func(event): return event.type == "phase_changed"),
		"Existing Stone Golem combat state reaches Phase II")
	check(first_rect == second_rect, "Golem texture swap keeps position and size")
	check(scene.get_node("Center/Content/HUD/Rows/EnemyMechanic").text.contains(
		tr("M9A_STONE_GOLEM_PHASE_2")), "HUD reports Phase II")
	await capture("06-stone-golem-phase-2")
	await stop_scene()

func capture_offer_portraits() -> void:
	root.size = Vector2i(720, 1280)
	root.content_scale_size = Vector2i.ZERO
	scene = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	await settle()
	scene.game.save_enabled = false
	check(scene.run_controller.new_run(37), "Encounter Choice starts for portrait smoke")
	scene.run_controller.run.encounter_offer.assign([
		"chapter_1_moss_slime", "chapter_1_stone_brute",
	])
	var offers: RunOfferView = scene.get_node("OfferOverlay")
	offers.rendered_offer_id = ""
	offers.refresh(scene.run_controller)
	await settle()
	check(offers.visible and offers.cards.get_child_count() == 2,
		"Two new Normal portraits render in the existing offer cards")
	await capture("07-encounter-choice-slime-brute")
	await stop_scene()

func run_smoke() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	await capture_battle("chapter_1_moss_slime", 0, "01-moss-slime-battle")
	await capture_battle("chapter_1_cave_wisp", 0, "02-cave-wisp-battle")
	await capture_battle("chapter_1_stone_brute", 0, "03-stone-brute-battle")
	await capture_battle("chapter_1_stone_guard", 2, "04-stone-guardian-elite")
	await capture_golem_phases()
	await capture_offer_portraits()
	print("ART-03C VISUAL SMOKE: %d checks, %d failures, %d screenshots" % [
		checks, failures, captures,
	])
	quit(failures)
