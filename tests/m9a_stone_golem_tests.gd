extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func fresh() -> BattleModel:
	return BattleModel.new(BalanceConfig.new(), EnemyCatalog.by_id("stone_golem"))

func events_of(events: Array[Dictionary], type_id: String) -> Array:
	return events.filter(func(event): return event.type == type_id)

func result(controller: RunController, hp: int) -> Dictionary:
	return {"run_instance_id":controller.run.run_instance_id,
		"encounter_instance_id":controller.run.current_encounter_instance_id,
		"result_id":controller.run.current_encounter_instance_id + ":m9a",
		"outcome":"victory", "core_hp":hp}

func finish_slot(controller: RunController, hp := 30) -> void:
	controller.accept_encounter_result(result(controller, hp))
	controller.claim_reward(controller.run.reward_offer[0], controller.run.offer_id("reward"))
	if controller.run.status == RunState.Status.ENCOUNTER_CHOICE:
		controller.choose_encounter(controller.run.encounter_offer[0], controller.run.offer_id("encounter"))

func _initialize() -> void:
	var battle := fresh()
	check(battle.enemy_hp == 32 and battle.enemy_armor == 1 and battle.current_phase_index == 0
		and battle.prepared_attack.damage == 8 and battle.prepared_attack.base_interval == 3,
		"1 Phase 1 starts at HP 32, Armor 1, attack 8 / interval 3")

	battle.enemy_hp = 18
	battle.prepared_attack.countdown = 2
	var transition := battle.apply_triple("fire")
	check(battle.enemy_hp == 13 and battle.current_phase_index == 1 and battle.enemy_armor == 0
		and battle.prepared_attack.damage == 8 and battle.prepared_attack.countdown == 1
		and events_of(transition, "phase_changed").size() == 1,
		"2 Transition drops Armor immediately and preserves old prepared attack")

	var old_attack := battle.advance_enemy_action()
	check(events_of(old_attack, "enemy_attack")[0].incoming == 8
		and battle.prepared_attack.damage == 10 and battle.prepared_attack.base_interval == 3
		and battle.prepared_attack.countdown == 3,
		"3 After old attack resolves, next attack is phase 2 damage 10 / interval 3")

	battle = fresh()
	battle.enemy_hp = 18
	battle.prepared_attack.countdown = 2
	battle.apply_triple("ice")
	var frozen_skip := battle.advance_enemy_action()
	check(battle.current_phase_index == 1 and events_of(frozen_skip, "frozen_skip").size() == 1
		and events_of(frozen_skip, "enemy_attack").is_empty() and battle.prepared_attack.damage == 10
		and battle.prepared_attack.countdown == 3,
		"4 Frozen consumes old phase 1 attack; next attack uses phase 2")

	battle = fresh()
	var kinds: Array[String] = []
	for attack_index in 2:
		battle.prepared_attack.countdown = 1
		for event in battle.advance_enemy_action(): kinds.append(event.type)
	var level: LevelDefinition = load("res://resources/levels/level_10.tres")
	var phase_zero_key := CombatValidator.canonical_key(BoardModel.new(level), TrayModel.new(7), fresh())
	var phase_two := fresh(); phase_two.enemy_hp = 18; phase_two.apply_triple("fire")
	var phase_one_key := CombatValidator.canonical_key(BoardModel.new(level), TrayModel.new(7), phase_two)
	var validator_smoke := CombatValidator.solve(level, EnemyCatalog.by_id("stone_golem"), BalanceConfig.new(), {"max_states":1})
	var game := GameController.new(); game.balance = BalanceConfig.new()
	var controller := RunController.new(); controller.definition = load("res://resources/runs/m4_run.tres"); controller.bind_game(game)
	controller.new_run()
	controller.choose_encounter(controller.run.encounter_offer[0], controller.run.offer_id("encounter"))
	for slot in 3: finish_slot(controller)
	var boss_auto: bool = controller.run.current_slot_index == 3 and controller.run.status == RunState.Status.BATTLE \
		and game.battle.current_enemy.id == "stone_golem"
	controller.accept_encounter_result(result(controller, 12))
	var reward_ok: bool = controller.run.status == RunState.Status.REWARD and controller.run.boundary_hp == 32 \
		and controller.run.reward_offer.size() == 3
	controller.claim_reward(controller.run.reward_offer[0], controller.run.offer_id("reward"))
	var chapter_ok: bool = controller.run.current_slot_index == 4 and controller.chapter().id == "frozen_grove" \
		and controller.run.status == RunState.Status.ENCOUNTER_CHOICE
	check(not kinds.has("lock_stack_request") and phase_zero_key != phase_one_key
		and validator_smoke.reason == "max_states" and boss_auto and reward_ok and chapter_ok,
		"5 No lock; validator keys phase; boss auto-flow, recovery, Rare reward and Frozen Grove remain")
	controller.free(); game.free()

	print("M9A: 5 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
