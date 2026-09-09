extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func settle() -> void:
	for frame in 5: await process_frame

func labels(node: Node) -> String:
	var result := ""
	for child in node.get_children():
		if child is Label: result += child.text + "\n"
		result += labels(child)
	return result

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	root.size = Vector2i(720, 1280)
	var scene: GameView = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	await settle()
	scene.game.save_enabled = false
	scene.run_controller.new_run()
	await settle()
	var offers: RunOfferView = scene.get_node("OfferOverlay")
	var initial_copy := labels(offers.cards)
	check(offers.visible and offers.color.a < 1.0 and offers.foreground_panel.is_visible_in_tree()
		and scene.background_location() == "stone_ruins" and offers.mouse_filter == Control.MOUSE_FILTER_STOP
		and offers.cards.get_child_count() == 2
		and offers.cards.get_child(0).find_child("PortraitArea", true, false) != null,
		"1 Encounter choice is a compact blocking overlay over biome background")

	offers.buttons[0].pressed.emit()
	var run := scene.run_controller.run
	scene.game.encounter_finished.emit({"run_instance_id":run.run_instance_id,
		"encounter_instance_id":run.current_encounter_instance_id,
		"result_id":run.current_encounter_instance_id + ":m8ux", "outcome":"victory", "core_hp":34})
	await settle()
	var reward_ok := offers.visible and offers.victory_heading.visible and offers.heading.text == "Выберите награду"
	reward_ok = reward_ok and offers.foreground_panel.size.y < root.size.y * 0.8 and offers.cards.get_child_count() == 3
	reward_ok = reward_ok and labels(offers.cards).contains("+6 HP") and scene.get_node("Center").is_visible_in_tree()
	for viewport_size in [Vector2i(720, 1280), Vector2i(1280, 720)]:
		root.size = viewport_size; scene.size = viewport_size
		await settle()
		var panel_rect := Rect2(offers.foreground_panel.global_position, offers.foreground_panel.size)
		reward_ok = reward_ok and panel_rect.position.y >= 0 and panel_rect.end.y <= viewport_size.y + 1 and panel_rect.size.x <= 520
	check(reward_ok, "2 Reward uses the same compact biome overlay and actual restore amount")

	var claimed_id := str(offers.buttons[0].get_meta("offer_item_id"))
	offers.buttons[0].pressed.emit()
	await settle()
	offers.build_button.pressed.emit()
	await settle()
	var info: RunInfoView = scene.get_node("InfoOverlay")
	var relic := scene.run_controller.definition.relic_by_id(claimed_id)
	check(info.visible and info.mouse_filter == Control.MOUSE_FILTER_STOP
		and info.subtitle_label.text == "РЕЛИКВИИ 1" and info.all_text().contains(scene.tr(relic.name_key))
		and info.all_text().contains(scene.tr(relic.description_key)),
		"3 Current Build lists acquired Relic and its effect")

	info.close_button.pressed.emit()
	offers.buttons[0].pressed.emit()
	await settle()
	var rune_bar: HBoxContainer = scene.get_node("Center/Content/HUD/Rows/RuneBar")
	var fire_button: Button = rune_bar.get_node("Fire")
	fire_button.pressed.emit()
	await settle()
	check(scene.get_node("BuildButton").visible and scene.get_node("BuildButton").text == "РЕЛИКВИИ 1"
		and rune_bar.get_child_count() == 6 and info.visible and info.subtitle_label.text == "ОГОНЬ"
		and info.all_text().contains("Тройка наносит 6 урона."),
		"4 Rune button opens the correct base-effect reference")

	var copy_ok := initial_copy.contains("Получает +3 урона от Льда.")
	var expected := {
		"M7A_MOSS_SLIME_MECHANIC":"Если ранит Ядро — лечится на 3 HP.",
		"M7A_CAVE_WISP_MECHANIC":"Получает +3 урона от Льда.",
		"M7A_STONE_BRUTE_MECHANIC":"Броня 1. Молния её игнорирует.",
		"M7B_CRYSTAL_SHELL_MECHANIC":"После своей атаки получает 4 Щита.",
		"M7B_ICE_SEER_MECHANIC":"Две одинаковые Тройки подряд дают ему 3 Щита.",
		"M7B_SNOW_LEECH_MECHANIC":"Если у Ядра нет Щита — наносит +2 урона.",
		"M7C_ASH_KNIGHT_MECHANIC":"Повтор одного типа Тройки усиливает следующий удар на 2.",
		"M7C_GRAVE_SENTINEL_MECHANIC":"После Жизни или Щита следующая атакующая Тройка игнорирует Броню.",
		"M7C_ECLIPSE_ACOLYTE_MECHANIC":"При 50% HP начинает атаковать чаще.",
		"M8_STONE_GUARD_MECHANIC":"Чередует удары на 8 и 12.",
		"M8_ICE_BEAST_MECHANIC":"После своей атаки получает 6 Щита. Лёд разбивает его.",
		"M8_STORM_REVENANT_MECHANIC":"Повтор Тройки приближает его атаку ещё на 1."
	}
	for key in expected: copy_ok = copy_ok and scene.tr(key) == expected[key]
	check(copy_ok, "5 All 12 Normal/Elite mechanic descriptions are explicit player-facing copy")

	info.hide_modal()
	scene.run_controller.abandon_run(scene.run_controller.run.run_instance_id)
	scene.audio.music_player.stop(); scene.audio.sfx_player.stop()
	await create_timer(0.3).timeout
	scene.queue_free(); await process_frame
	print("M8-UX: 5 targeted UI scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
