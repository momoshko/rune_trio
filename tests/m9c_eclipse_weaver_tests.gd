extends SceneTree

var failures := 0
var run_definition: RunDefinition = load("res://resources/runs/m4_run.tres")

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func fresh(relics: Array[RelicDefinition] = []) -> BattleModel:
	return BattleModel.new(BalanceConfig.new(), EnemyCatalog.by_id("eclipse_weaver"), relics)

func spell(events: Array[Dictionary]) -> Dictionary:
	for event in events:
		if event.type == "spell_resolved": return event
	return {}

func events_of(events: Array[Dictionary], type_id: String) -> Array:
	return events.filter(func(event): return event.type == type_id)

func result(controller: RunController, hp: int) -> Dictionary:
	return {"run_instance_id":controller.run.run_instance_id,
		"encounter_instance_id":controller.run.current_encounter_instance_id,
		"result_id":controller.run.current_encounter_instance_id + ":m9c",
		"outcome":"victory", "core_hp":hp}

func finish_slot(controller: RunController, hp := 30) -> void:
	controller.accept_encounter_result(result(controller, hp))
	controller.claim_reward(controller.run.reward_offer[0], controller.run.offer_id("reward"))
	if controller.run.status == RunState.Status.ENCOUNTER_CHOICE:
		controller.choose_encounter(controller.run.encounter_offer[0], controller.run.offer_id("encounter"))

func _initialize() -> void:
	var weaver := fresh()
	var hud: Dictionary = weaver.hud_data()
	check(weaver.enemy_hp == 42 and weaver.current_phase_index == 0 and weaver.prepared_attack.damage == 8
		and weaver.prepared_attack.base_interval == 3 and hud.vulnerability.current == "fire"
		and hud.vulnerability.remaining == 3 and hud.vulnerability.next == "ice",
		"1 Start: HP 42, phase I attack 8/3, Fire vulnerability for 3 Triples")

	var fire := spell(fresh().apply_triple("fire"))
	var ice := spell(fresh().apply_triple("ice"))
	var heart := fresh([run_definition.relic_by_id("brazier_heart")])
	var combined := spell(heart.apply_triple("fire"))
	check(fire.base_effect.damage == 9 and fire.hp_damage == 9 and ice.base_effect.damage == 3
		and ice.hp_damage == 3 and combined.resolved_effect.ordinary_damage == 12 and combined.hp_damage == 12,
		"2 Fire gets one +3 bonus; other Rune remains useful; relic bonus stays in one Spell")

	weaver = fresh(); weaver.current_vulnerability_index = 2
	weaver.enemy_armor = 20; weaver.enemy_shield = 30
	var lightning := spell(weaver.apply_triple("lightning"))
	check(lightning.base_effect.damage == 8 and lightning.resolved_effect.direct_damage == 8
		and lightning.hp_damage == 8 and weaver.enemy_shield == 30,
		"3 Lightning vulnerability gives 8 direct damage through Armor and Shield")

	weaver = fresh()
	weaver.apply_triple("life"); weaver.apply_triple("shield")
	var third := spell(weaver.apply_triple("fire"))
	var shifted: Dictionary = weaver.hud_data().vulnerability
	var next_ice := spell(weaver.apply_triple("ice"))
	check(third.base_effect.damage == 9 and shifted.current == "ice" and shifted.remaining == 3
		and next_ice.base_effect.damage == 6,
		"4 Third Triple uses old Fire vulnerability, then shifts Fire to Ice")

	weaver = fresh(); weaver.enemy_hp = 27; weaver.prepared_attack.countdown = 3
	weaver.apply_triple("fire")
	var old_attack_ok := weaver.current_phase_index == 1 and weaver.enemy_hp == 18
	old_attack_ok = old_attack_ok and weaver.prepared_attack.damage == 8 and weaver.prepared_attack.countdown == 2
	weaver.prepared_attack.countdown = 1
	var old_attack := weaver.advance_enemy_action()
	check(old_attack_ok and events_of(old_attack, "enemy_attack")[0].incoming == 8
		and weaver.prepared_attack.damage == 10 and weaver.prepared_attack.base_interval == 2,
		"5 Phase II preserves current attack; next prepared attack is 10/2")

	weaver = fresh(); weaver.apply_triple("life")
	weaver.enemy_hp = 27; weaver.apply_triple("fire")
	var middle: Dictionary = weaver.hud_data().vulnerability
	weaver.apply_triple("shield")
	var new_period: Dictionary = weaver.hud_data().vulnerability
	weaver.apply_triple("life")
	var after_one: Dictionary = weaver.hud_data().vulnerability
	var level: LevelDefinition = load("res://resources/levels/level_20.tres")
	var key_before := CombatValidator.canonical_key(BoardModel.new(level), TrayModel.new(7), weaver)
	weaver.apply_triple("shield")
	var key_after := CombatValidator.canonical_key(BoardModel.new(level), TrayModel.new(7), weaver)
	var after_two: Dictionary = weaver.hud_data().vulnerability
	var validator := CombatValidator.solve(level, EnemyCatalog.by_id("eclipse_weaver"), BalanceConfig.new(), {"max_states":1})
	check(middle.current == "fire" and middle.remaining == 1 and middle.period == 3
		and new_period.current == "ice" and new_period.period == 2 and new_period.remaining == 2
		and after_one.remaining == 1 and after_two.current == "lightning" and key_before != key_after
		and validator.reason == "max_states",
		"6 Phase change preserves current period; following full periods use length 2; validator keys state")

	var game := GameController.new(); game.balance = BalanceConfig.new()
	var controller := RunController.new(); controller.definition = run_definition; controller.bind_game(game)
	controller.new_run(); controller.choose_encounter(controller.run.encounter_offer[0], controller.run.offer_id("encounter"))
	for slot in 11: finish_slot(controller)
	var final_auto: bool = controller.run.current_slot_index == 11 and controller.run.status == RunState.Status.BATTLE \
		and game.battle.current_enemy.id == "eclipse_weaver"
	controller.accept_encounter_result(result(controller, 7))
	check(final_auto and controller.run.status == RunState.Status.VICTORY
		and controller.run.completed_encounters == 12 and controller.run.boundary_hp == 7
		and controller.run.reward_offer.is_empty(),
		"7 Eclipse Weaver victory ends run at 12/12 without reward or chapter recovery")
	controller.free(); game.free()

	print("M9C: 7 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
