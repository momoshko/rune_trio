extends SceneTree

# Lifecycle fixtures only: no solver, no campaign combat sweep.
var failures := 0
var controller: RunController
var game: GameController

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func result(hp: int) -> Dictionary:
	var run := controller.run
	return {"run_instance_id":run.run_instance_id, "encounter_instance_id":run.current_encounter_instance_id,
		"result_id":run.current_encounter_instance_id + ":test", "outcome":"victory", "core_hp":hp}

func choose_first() -> bool:
	return controller.choose_encounter(controller.run.encounter_offer[0], controller.run.offer_id("encounter"))

func claim_first() -> bool:
	return controller.claim_reward(controller.run.reward_offer[0], controller.run.offer_id("reward"))

func rare_offer_valid() -> bool:
	var run := controller.run
	if run.status != RunState.Status.REWARD or run.reward_offer.size() != 3: return false
	var unique := {}
	for id in run.reward_offer:
		if id == "restore_core" or run.acquired_relic_ids.has(id): return false
		if controller.definition.relic_by_id(id).rarity != "RARE": return false
		unique[id] = true
	return unique.size() == 3

func _initialize() -> void:
	game = GameController.new(); game.balance = BalanceConfig.new()
	controller = RunController.new()
	controller.definition = load("res://resources/runs/m4_run.tres")
	controller.bind_game(game)
	var definition := controller.definition
	var valid := definition.validation_errors().is_empty()
	var invalid := definition.duplicate(true) as RunDefinition
	invalid.encounters.remove_at(0)
	valid = valid and not invalid.validation_errors().is_empty() and controller.new_run()
	var run := controller.run
	valid = valid and run.status == RunState.Status.ENCOUNTER_CHOICE and run.encounter_offer.size() == 2
	for id in run.encounter_offer:
		var encounter := definition.encounter_by_id(id)
		valid = valid and encounter.chapter == 0 and encounter.role == "normal"
	check(valid and run.encounter_offer[0] != run.encounter_offer[1], "1 Encounter offer + upfront config validation")

	var offer := run.encounter_offer.duplicate()
	var token := run.offer_id("encounter")
	var stable := not controller.new_run() and offer == run.encounter_offer
	var selected := definition.encounter_by_id(offer[0])
	stable = stable and choose_first() and not controller.choose_encounter(offer[1], token)
	check(stable and game.battle.current_enemy.id == selected.enemy_id and game.encounter_total == 1
		and game.current_level.id == selected.level.id, "2 Stable offer, one selection, authored enemy/layout")

	controller.accept_encounter_result(result(23))
	var rewards := run.reward_offer.duplicate()
	var common: bool = rewards.size() == 3 and rewards[2] == "restore_core" and rewards[0] != rewards[1]
	for id in rewards.slice(0, 2): common = common and definition.relic_by_id(id).rarity == "COMMON"
	common = common and definition.relic_by_id(rewards[0]).category == selected.reward_category
	controller.state_changed.emit() # Reopening is a read, never a new offer.
	check(common and run.reward_offer == rewards and run.status == RunState.Status.REWARD, "3 Normal reward and category preference")

	var reward_token := run.offer_id("reward")
	var claimed := claim_first()
	check(claimed and not controller.claim_reward("restore_core", reward_token)
		and not controller.claim_reward(rewards[1], reward_token) and run.acquired_relic_ids == [rewards[0]]
		and run.boundary_hp == 23 and not controller.continue_run(), "4 Exactly one reward, stale callbacks rejected")

	var no_repeat := run.status == RunState.Status.ENCOUNTER_CHOICE and run.encounter_offer.size() == 2
	for id in run.encounter_offer: no_repeat = no_repeat and definition.encounter_by_id(id).enemy_id != selected.enemy_id
	check(no_repeat and not controller.choose_encounter(run.encounter_offer[0], token) and choose_first(), "5 No defeated normal archetype repeats")

	controller.accept_encounter_result(result(35))
	var no_duplicate := not run.reward_offer.has(rewards[0])
	var restored := controller.claim_reward("restore_core", run.offer_id("reward"))
	check(no_duplicate and restored and run.boundary_hp == 40 and game.battle.core_hp == 40
		and run.acquired_relic_ids.size() == 1 and controller.role() == "elite"
		and run.status == RunState.Status.BATTLE, "6 No acquired relic offered; Restore cap; automatic Elite")

	controller.accept_encounter_result(result(17))
	var rare := rare_offer_valid() and claim_first() and controller.role() == "boss"
	var boss_result := result(1)
	controller.accept_encounter_result(boss_result)
	rare = rare and rare_offer_valid() and run.boundary_hp == 32
	rare = rare and not controller.accept_encounter_result(boss_result) and run.boundary_hp == 32
	rare = rare and claim_first() and run.status == RunState.Status.ENCOUNTER_CHOICE and run.current_slot_index == 4
	check(rare, "7 Elite/Boss Rare offers; recovery before reward exactly once")

	var finish := true
	# Remaining slots use injected outcomes solely to verify the terminal flow.
	for slot in range(4, 12):
		if run.status == RunState.Status.ENCOUNTER_CHOICE: finish = choose_first() and finish
		finish = finish and run.current_slot_index == slot and run.status == RunState.Status.BATTLE
		controller.accept_encounter_result(result(20))
		if slot == 11: break
		if controller.role() in ["elite", "boss"]: finish = rare_offer_valid() and finish
		finish = claim_first() and finish
	check(finish and run.status == RunState.Status.VICTORY and run.reward_offer.is_empty()
		and run.completed_encounters == 12 and not controller.claim_reward("restore_core", run.offer_id("reward")),
		"8 Final Boss -> Victory without reward")
	controller.free(); game.free()
	print("M4: 8 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
