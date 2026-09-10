extends SceneTree

var failures := 0
var catalog: RunDefinition = load("res://resources/runs/m4_run.tres")

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func offer(seed_value: int, slot: int) -> Array[String]:
	var game := GameController.new()
	game.balance = BalanceConfig.new()
	root.add_child(game)
	var controller := RunController.new()
	controller.definition = catalog
	controller.bind_game(game)
	root.add_child(controller)
	controller.new_run(seed_value)
	controller.run.current_slot_index = slot
	controller.run.selected_encounter_id = catalog.pool(catalog.chapter_index_for_slot(slot), "normal")[0].id
	controller._create_reward()
	var result := controller.run.reward_offer.duplicate()
	controller.queue_free(); game.queue_free()
	return result

func fresh_battle(ids: Array[String], enemy: EnemyDefinition = null) -> BattleModel:
	var owned: Array[RelicDefinition] = []
	for id in ids: owned.append(catalog.relic_by_id(id))
	if enemy == null:
		enemy = EnemyDefinition.new()
		enemy.max_hp = 200; enemy.attack_damage = 0; enemy.attack_interval_triples = 20
	return BattleModel.new(BalanceConfig.new(), enemy, owned)

func cast(battle: BattleModel, type_id: String) -> Dictionary:
	for event in battle.apply_triple(type_id, battle.capture_triple_context(type_id, 3)):
		if event.type == "spell_resolved": return event
	return {}

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var common_a := offer(101, 0)
	var common_b := offer(101, 0)
	var rare_a := offer(101, 2)
	var rare_b := offer(101, 2)
	check(common_a == common_b and rare_a == rare_b, "1 Seeded offers reproduce Common and Rare")

	var different := false
	for seed_value in range(102, 112):
		if offer(seed_value, 2) != rare_a: different = true; break
	check(different, "2 Different seeds can produce another order")

	var seen: Dictionary = {}
	for seed_value in 256:
		for id in offer(seed_value, 2): seen[id] = true
	check(seen.size() == 8 and seen.has("trinity_mark"), "3 Every Rare, including Triunity, can appear first")

	var game := GameController.new(); game.balance = BalanceConfig.new(); root.add_child(game)
	var controller := RunController.new(); controller.definition = catalog; controller.bind_game(game); root.add_child(controller)
	controller.new_run(404); controller.run.current_slot_index = 2
	controller.run.selected_encounter_id = catalog.pool(0, "normal")[0].id
	controller._create_reward(); var rejected := controller.run.reward_offer.duplicate()
	controller._create_reward(); var next_offer := controller.run.reward_offer.duplicate()
	var avoidance_ok := rejected.all(func(id): return not next_offer.has(id))
	controller.run.current_slot_index = 0
	controller._create_reward(); var rejected_common := controller.run.reward_offer.slice(0, 2)
	controller._create_reward(); var next_common := controller.run.reward_offer.slice(0, 2)
	avoidance_ok = avoidance_ok and rejected_common.all(func(id): return not next_common.has(id))
	check(avoidance_ok, "4 Immediate rejected Common/Rare offers are avoided")

	var heart := fresh_battle(["brazier_heart"])
	cast(heart, "shield"); cast(heart, "wind")
	check(cast(heart, "fire").hp_damage == 9 and cast(heart, "fire").hp_damage == 6,
		"5 Heart buffs first Fire, not first Triple")

	var weaver := fresh_battle(["echo_seal"], EnemyCatalog.by_id("eclipse_weaver"))
	cast(weaver, "shield"); cast(weaver, "life"); cast(weaver, "shield")
	weaver.current_vulnerability_index = 0; weaver.vulnerability_progress = 0
	var echoed_fire := cast(weaver, "fire")
	check(echoed_fire.hp_damage == 12 and echoed_fire.resolved_effect.ordinary_damage == 12,
		"6 Echo adds half of Rune base beside Weaver vulnerability")

	var scene: GameView = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.run_controller.new_run(505)
	scene.run_controller.choose_encounter(scene.run_controller.run.encounter_offer[0], scene.run_controller.run.offer_id("encounter"))
	scene.run_controller.run.acquired_relic_ids.assign(["echo_seal", "trinity_mark"])
	scene.game.battle.start_enemy(EnemyCatalog.by_id("frost_witch")); scene.update_view()
	var info_text: String = scene.get_node("Center/Content/HUD/Rows/EnemyMechanic").text
	var ux_ok: bool = info_text.contains("урона") and info_text.contains("До усиления") and info_text.contains("До проверки")
	ux_ok = ux_ok and scene.tr("M9C_ECLIPSE_WEAVER_PHASE_2").contains("Новые периоды")
	scene.run_controller.run.status = RunState.Status.VICTORY; scene.run_controller.run.completed_encounters = 12; scene.update_view()
	var build_button: Button = scene.get_node("ResultOverlay/Center/Panel/Build")
	build_button.pressed.emit()
	ux_ok = ux_ok and build_button.visible and scene.get_node("InfoOverlay").visible \
		and scene.get_node("InfoOverlay").all_text().contains(scene.tr("M4_RELIC_ECHO_SEAL"))
	scene.get_node("InfoOverlay").hide_modal()
	ux_ok = ux_ok and scene.get_node("ResultOverlay").visible
	check(ux_ok, "7 Counters, boss copy/preview and final Build UI")

	print("M9.5: 7 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
