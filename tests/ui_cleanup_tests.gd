extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func labels(root_node: Node) -> String:
	var text := ""
	for child in root_node.get_children():
		if child is Label: text += child.text + "\n"
		text += labels(child)
	return text

func _initialize() -> void:
	call_deferred("smoke")

func smoke() -> void:
	root.size = Vector2i(540, 960)
	var scene: GameView = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	for frame in 4: await process_frame
	scene.game.save_enabled = false
	check(scene.get_node("MainMenu").visible and not scene.get_node("Center").is_visible_in_tree()
		and not scene.level_label.is_visible_in_tree() and not scene.tray_label.is_visible_in_tree(), "1 Main menu has no gameplay HUD behind it")

	var visible_items: Array[String] = []
	for child in scene.get_node("MainMenu/Center/Panel").get_children():
		if child is Control and child.is_visible_in_tree(): visible_items.append(str(child.name))
	check(visible_items == ["Title", "Play", "Settings"] and scene.get_node("MainMenu/Center/Panel/Levels").disabled,
		"2 Menu contains only title, New Run and Settings")

	scene.get_node("MainMenu/Center/Panel/Play").pressed.emit()
	var offers: RunOfferView = scene.get_node("OfferOverlay")
	var encounter_copy := offers.buttons.size() == 2 and offers.buttons[0].text == "Сразиться"
	encounter_copy = encounter_copy and labels(offers.cards).contains("Угроза: Средняя · Награда: Атака")
	var leave: Button = offers.find_child("LeaveRun", true, false)
	encounter_copy = encounter_copy and leave.flat and scene.tr(leave.text) == "Покинуть забег"
	leave.pressed.emit()
	encounter_copy = encounter_copy and scene.get_node("AbandonOverlay").visible
	encounter_copy = encounter_copy and scene.tr(scene.get_node("AbandonOverlay/Center/Panel/Confirm").text) == "Покинуть"
	scene.get_node("AbandonOverlay/Center/Panel/Cancel").pressed.emit()
	offers.buttons[0].pressed.emit()
	for frame in 4: await process_frame
	check(scene.get_node("Center").is_visible_in_tree() and not scene.get_node("Center/Content/HUD/Rows/CoreHint").is_visible_in_tree()
		and not scene.get_node("Center/Content/HUD/Rows/RuneHint").is_visible_in_tree()
		and scene.get_node("Center/Content/HUD/Rows/EnemyMechanic").text == "Ранит Ядро → восстанавливает 3 HP", "3 Battle keeps mechanic line, not persistent tutorial")

	scene.game.tray.tiles.assign(["fire", "fire", "ice", "ice", "wind", "wind"])
	scene.update_view()
	var row := scene.tray_label
	var text_width := row.get_theme_font("font").get_string_size(row.text, HORIZONTAL_ALIGNMENT_LEFT, -1, row.get_theme_font_size("font_size")).x
	check(row.text.begins_with("РУННЫЙ РЯД 6/7") and not row.text.contains("\n") and text_width <= row.size.x
		and scene.row_caption(6, 7, 1000).contains("ОСТАЛОСЬ 1 МЕСТО")
		and scene.row_caption(6, 7, 250) == "РУННЫЙ РЯД 6/7", "4 Rune Row terminology; width-safe last-place warning")

	var defenses := scene.enemy_defense_text(scene.game.battle.hud_data())
	var stats_ok: bool = defenses.armor.is_empty() and defenses.shield.is_empty()
	scene.game.battle.enemy_armor = 1; scene.game.battle.enemy_shield = 8
	defenses = scene.enemy_defense_text(scene.game.battle.hud_data())
	check(stats_ok and defenses.armor == "Броня врага: 1" and defenses.shield == "Щит врага: 8", "5 Drawn enemy stat captions omit zero values")

	var run := scene.run_controller.run
	scene.game.encounter_finished.emit({"run_instance_id":run.run_instance_id, "encounter_instance_id":run.current_encounter_instance_id,
		"result_id":run.current_encounter_instance_id + ":ui", "outcome":"victory", "core_hp":40})
	var reward_copy := offers.visible and offers.heading.text.contains("Выберите награду") and offers.buttons.size() == 3
	reward_copy = reward_copy and offers.buttons[2].disabled and offers.buttons[2].text == "Ядро уже восстановлено"
	reward_copy = reward_copy and labels(offers.cards).contains("+12 HP") and scene.tr(offers.buttons[0].text) == "Забрать"
	var catalog := scene.run_controller.definition
	for relic in catalog.relics:
		var description := scene.tr(relic.description_key)
		reward_copy = reward_copy and description != relic.description_key and description.length() < 120
		reward_copy = reward_copy and not description.contains("до брони") and not description.contains("resolution")
	reward_copy = reward_copy and scene.tr(catalog.relic_by_id("brazier_heart").description_key) == "Первая Тройка Огня в бою наносит +3 урона."
	check(encounter_copy and reward_copy, "6 Encounter, reward, confirmation and all 20 relic descriptions")
	scene.menu_command(); scene.confirm_abandon()
	scene.audio.music_player.stop(); scene.audio.sfx_player.stop()
	await create_timer(0.3).timeout
	scene.queue_free(); await process_frame
	print("M7-UI: 6 targeted UI scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
