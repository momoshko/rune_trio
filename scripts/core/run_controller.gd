class_name RunController
extends Node

signal state_changed

@export var definition: RunDefinition
@export var game_path: NodePath
var game: GameController
var run := RunState.new()
var validation_errors := PackedStringArray()
var layout_provider := RuntimeLayoutProvider.new()

func _ready() -> void:
	if not game_path.is_empty(): bind_game(get_node(game_path))

func bind_game(controller: GameController) -> void:
	if game != null and game.encounter_finished.is_connected(accept_encounter_result):
		game.encounter_finished.disconnect(accept_encounter_result)
	game = controller
	game.encounter_finished.connect(accept_encounter_result)

func new_run(seed_override := -1) -> bool:
	if run.is_active(): return false
	validation_errors = definition.validation_errors() if definition else PackedStringArray(["Missing RunDefinition"])
	if game == null or game.balance == null: validation_errors.append("Missing battle controller/balance")
	elif definition and game.balance.core_max_hp != definition.maximum_hp: validation_errors.append("Core HP limits disagree")
	if not validation_errors.is_empty(): return false
	run = RunState.new()
	run.run_instance_id = Crypto.new().generate_random_bytes(16).hex_encode()
	run.seed = seed_override if seed_override >= 0 else absi(run.run_instance_id.hash())
	var rng := RandomNumberGenerator.new()
	rng.seed = run.seed
	run.rng_state = rng.state
	run.boundary_hp = definition.initial_hp
	game.show_main_menu()
	game.run_mode = true
	_prepare_slot()
	return true

func _prepare_slot() -> void:
	run.encounter_offer.clear(); run.reward_offer.clear()
	run.reward_claimed = false; run.selected_encounter_id = ""
	var chapter_index := definition.chapter_index_for_slot(run.current_slot_index)
	if role() == "normal":
		var seen: Array = run.defeated_normal_archetypes.get(chapter_index, [])
		var offered_archetypes: Array[String] = []
		for encounter in definition.pool(chapter_index, "normal"):
			if seen.has(encounter.enemy_id) or offered_archetypes.has(encounter.enemy_id): continue
			run.encounter_offer.append(encounter.id)
			offered_archetypes.append(encounter.enemy_id)
			if run.encounter_offer.size() == 2: break
		if run.encounter_offer.size() != 2:
			validation_errors.append("Cannot create two distinct normal offers")
			run.status = RunState.Status.ENCOUNTER_CHOICE
		else: run.status = RunState.Status.ENCOUNTER_CHOICE
		game.state = "encounter_choice"; game.busy = true
		state_changed.emit()
	else:
		run.selected_encounter_id = definition.pool(chapter_index, "boss" if role() == "final_boss" else role())[0].id
		_start_encounter()

func choose_encounter(encounter_id: String, expected_offer_id: String) -> bool:
	if run.status != RunState.Status.ENCOUNTER_CHOICE or expected_offer_id != run.offer_id("encounter"): return false
	if not run.encounter_offer.has(encounter_id) or not run.selected_encounter_id.is_empty(): return false
	run.selected_encounter_id = encounter_id
	_start_encounter()
	return true

func _start_encounter() -> void:
	run.status = RunState.Status.BATTLE
	run.current_encounter_instance_id = "%s:%d" % [run.run_instance_id, run.current_slot_index]
	var encounter := definition.encounter_by_id(run.selected_encounter_id)
	var slot_key := str(run.current_slot_index)
	var resolution := layout_provider.resolve(run.seed, run.current_slot_index, encounter.enemy_id,
		run.resolved_layouts.get(slot_key, {}), encounter.battle_level())
	if resolution.persist:
		var resolved_state: Dictionary = resolution.state.duplicate(true)
		resolved_state.slot = run.current_slot_index
		run.resolved_layouts[slot_key] = resolved_state
		if OS.is_debug_build():
			print("[layout] run_seed=%s enemy=%s layout_id=%s hash=%s source=%s" % [run.seed,
				encounter.enemy_id, resolution.layout_id, resolution.layout_hash, resolution.source])
	var owned: Array[RelicDefinition] = []
	for id in run.acquired_relic_ids:
		var relic := definition.relic_by_id(id)
		if relic != null: owned.append(relic)
	game.start_run_encounter(resolution.level, run.boundary_hp,
		run.run_instance_id, run.current_encounter_instance_id, owned)
	state_changed.emit()

func continue_run() -> bool:
	# M4 never permits bypassing a mandatory reward via the old Continue button.
	return false

func _create_reward() -> void:
	run.reward_offer.clear()
	var rarity := "COMMON" if role() == "normal" else "RARE"
	var available: Array[RelicDefinition] = []
	for relic in definition.relics:
		if relic.rarity == rarity and not run.acquired_relic_ids.has(relic.id): available.append(relic)
	var needed := 2 if rarity == "COMMON" else 3
	var previous: Array[String] = run.previous_common_offer if rarity == "COMMON" else run.previous_rare_offer
	var candidates: Array[String] = []
	for relic in available:
		if not previous.has(relic.id): candidates.append(relic.id)
	if candidates.size() < needed:
		candidates.clear()
		for relic in available: candidates.append(relic.id)
	_shuffle_with_run_rng(candidates)
	for id in candidates.slice(0, needed): run.reward_offer.append(id)
	if run.reward_offer.size() != needed: validation_errors.append("Insufficient unowned relics for reward")
	if rarity == "COMMON": run.previous_common_offer.assign(run.reward_offer)
	else: run.previous_rare_offer.assign(run.reward_offer)
	if rarity == "COMMON": run.reward_offer.append("restore_core")
	run.status = RunState.Status.REWARD

func _shuffle_with_run_rng(values: Array[String]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.state = run.rng_state
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value := values[index]
		values[index] = values[swap_index]
		values[swap_index] = value
	run.rng_state = rng.state

func claim_reward(reward_id: String, expected_offer_id: String) -> bool:
	if run.status != RunState.Status.REWARD or run.reward_claimed or expected_offer_id != run.offer_id("reward"): return false
	if not run.reward_offer.has(reward_id): return false
	if reward_id == "restore_core":
		if run.boundary_hp >= definition.maximum_hp: return false
	else:
		if definition.relic_by_id(reward_id) == null or run.acquired_relic_ids.has(reward_id): return false
	# Consume before advancing/emitting signals: stale callbacks cannot claim twice.
	run.reward_claimed = true
	if reward_id == "restore_core": run.boundary_hp = mini(definition.maximum_hp, run.boundary_hp + definition.restore_amount)
	else: run.acquired_relic_ids.append(reward_id)
	run.current_slot_index += 1
	_prepare_slot()
	return true

# Public injection seam for lifecycle tests; real play supplies the same result signal.
func accept_encounter_result(result: Dictionary) -> bool:
	if run.status != RunState.Status.BATTLE: return false
	if result.get("run_instance_id", "") != run.run_instance_id: return false
	if result.get("encounter_instance_id", "") != run.current_encounter_instance_id: return false
	var result_id := str(result.get("result_id", ""))
	if result_id.is_empty() or result_id == run.last_processed_result_id: return false
	var outcome := str(result.get("outcome", ""))
	if outcome not in ["victory", "ROW_FULL", "CORE_DESTROYED", "BOARD_EXHAUSTED"]: return false
	var hp: int = result.get("core_hp", -1)
	if hp < 0 or hp > definition.maximum_hp or (outcome == "victory" and hp == 0): return false
	run.last_processed_result_id = result_id
	run.boundary_hp = hp
	game.seal_run_encounter(outcome)
	if outcome == "victory":
		run.completed_encounters += 1
		if role() == "normal":
			var chapter_index := definition.chapter_index_for_slot(run.current_slot_index)
			if not run.defeated_normal_archetypes.has(chapter_index): run.defeated_normal_archetypes[chapter_index] = []
			run.defeated_normal_archetypes[chapter_index].append(definition.encounter_by_id(run.selected_encounter_id).enemy_id)
		run.boundary_hp = definition.hp_after_victory(run.current_slot_index, hp)
		if run.completed_encounters == definition.slots.size():
			run.reward_offer.clear()
			run.status = RunState.Status.VICTORY
		else: _create_reward()
	else:
		run.defeat_reason = outcome
		run.status = RunState.Status.DEFEAT
	state_changed.emit()
	return true

func abandon_run(expected_run_id: String) -> bool:
	if not run.is_active() or expected_run_id != run.run_instance_id: return false
	run.status = RunState.Status.ABANDONED
	game.show_main_menu()
	state_changed.emit()
	return true

func chapter() -> Dictionary:
	return definition.chapters[definition.chapter_index_for_slot(run.current_slot_index)]

func role() -> String:
	return definition.slots[run.current_slot_index].role
