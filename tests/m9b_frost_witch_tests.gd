extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func fresh() -> BattleModel:
	return BattleModel.new(BalanceConfig.new(), EnemyCatalog.by_id("frost_witch"))

func events_of(events: Array[Dictionary], type_id: String) -> Array:
	return events.filter(func(event): return event.type == type_id)

func consume(battle: BattleModel) -> Array[Dictionary]:
	battle.prepared_attack.countdown = 1
	return battle.advance_enemy_action()

func result(controller: RunController, hp: int) -> Dictionary:
	return {"run_instance_id":controller.run.run_instance_id,
		"encounter_instance_id":controller.run.current_encounter_instance_id,
		"result_id":controller.run.current_encounter_instance_id + ":m9b",
		"outcome":"victory", "core_hp":hp}

func finish_slot(controller: RunController, hp := 30) -> void:
	controller.accept_encounter_result(result(controller, hp))
	controller.claim_reward(controller.run.reward_offer[0], controller.run.offer_id("reward"))
	if controller.run.status == RunState.Status.ENCOUNTER_CHOICE:
		controller.choose_encounter(controller.run.encounter_offer[0], controller.run.offer_id("encounter"))

func _initialize() -> void:
	var witch := fresh()
	var start_ok := witch.enemy_hp == 34 and witch.enemy_shield == 4 and witch.prepared_attack.name_key == "M9B_ICE_ARROW" \
		and witch.prepared_attack.damage == 6 and witch.prepared_attack.base_interval == 3
	consume(witch)
	var spear_ok := witch.prepared_attack.name_key == "M9B_ICE_SPEAR" and witch.prepared_attack.damage == 10 \
		and witch.prepared_attack.base_interval == 4
	consume(witch)
	check(start_ok and spear_ok and witch.prepared_attack.name_key == "M9B_ICE_ARROW"
		and witch.prepared_attack.damage == 6 and witch.prepared_attack.base_interval == 3,
		"1 Phase I: Shield 4; Arrow 6/3, Spear 10/4, Arrow 6/3")

	witch = fresh(); consume(witch) # Spear is now current.
	witch.enemy_shield = 0; witch.enemy_hp = 19; witch.prepared_attack.countdown = 2
	witch.apply_triple("fire")
	check(witch.current_phase_index == 1 and witch.prepared_attack.sequence == 2
		and witch.prepared_attack.name_key == "M9B_ICE_SPEAR" and witch.prepared_attack.damage == 10
		and witch.prepared_attack.base_interval == 4 and witch.prepared_attack.countdown == 1,
		"2 Phase II transition preserves current phase-I Spear and sequence position")

	var old_spear := consume(witch)
	check(events_of(old_spear, "enemy_attack")[0].incoming == 10 and witch.prepared_attack.sequence == 3
		and witch.prepared_attack.name_key == "M9B_ICE_ARROW" and witch.prepared_attack.damage == 8
		and witch.prepared_attack.base_interval == 2,
		"3 Future sequence continues with phase-II Arrow 8/2")

	consume(witch) # Phase-II Spear 12/3.
	witch.prepared_attack.frozen = true
	var frozen := consume(witch)
	var sequence_after_frozen := witch.prepared_attack.sequence
	witch.prepared_attack.countdown = 1
	var before_wind := witch.prepared_attack.sequence
	var wind := witch.apply_triple("wind")
	check(events_of(frozen, "frozen_skip").size() == 1 and events_of(frozen, "enemy_attack").is_empty()
		and sequence_after_frozen == 5 and witch.prepared_attack.name_key == "M9B_ICE_ARROW"
		and witch.prepared_attack.damage == 8 and before_wind == witch.prepared_attack.sequence
		and events_of(wind, "timeline").size() == 1 and events_of(wind, "enemy_attack").is_empty(),
		"4 Frozen consumes Spear; Wind delays current Arrow without changing sequence")

	var ordinary := fresh()
	var ordinary_hp := ordinary.enemy_hp
	ordinary.apply_triple("fire")
	var lightning := fresh()
	var lightning_hp := lightning.enemy_hp
	lightning.apply_triple("lightning")
	check(ordinary.enemy_shield == 0 and ordinary.enemy_hp == ordinary_hp - 2
		and lightning.enemy_shield == 4 and lightning.enemy_hp == lightning_hp - 5,
		"5 Starting Shield 4 absorbs ordinary damage; Lightning bypasses and preserves it")

	witch = fresh()
	var kinds: Array[String] = []
	for index in 4:
		for event in consume(witch): kinds.append(event.type)
	var level: LevelDefinition = load("res://resources/levels/level_20.tres")
	var validator := CombatValidator.solve(level, EnemyCatalog.by_id("frost_witch"), BalanceConfig.new(), {"max_states":1})
	var game := GameController.new(); game.balance = BalanceConfig.new()
	var controller := RunController.new(); controller.definition = load("res://resources/runs/m4_run.tres"); controller.bind_game(game)
	controller.new_run(); controller.choose_encounter(controller.run.encounter_offer[0], controller.run.offer_id("encounter"))
	for slot in 7: finish_slot(controller)
	var boss_auto: bool = controller.run.current_slot_index == 7 and controller.run.status == RunState.Status.BATTLE \
		and game.battle.current_enemy.id == "frost_witch"
	controller.accept_encounter_result(result(controller, 10))
	var reward_ok: bool = controller.run.status == RunState.Status.REWARD and controller.run.boundary_hp == 32 \
		and controller.run.reward_offer.size() == 3
	controller.claim_reward(controller.run.reward_offer[0], controller.run.offer_id("reward"))
	var chapter_ok: bool = controller.run.current_slot_index == 8 and controller.chapter().id == "eclipse_lands" \
		and controller.run.status == RunState.Status.ENCOUNTER_CHOICE
	check(not kinds.has("lock_stack_request") and validator.reason == "max_states"
		and boss_auto and reward_ok and chapter_ok,
		"6 No lock; validator accepts sequence boss; Chapter 2 recovery, Rare reward and Eclipse flow remain")
	controller.free(); game.free()

	print("M9B: 6 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
