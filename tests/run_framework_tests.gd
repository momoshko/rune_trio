extends SceneTree

# Lifecycle injection is deliberately NOT a solver or a combat solvability test.
class SaveProbe extends CampaignSave:
	var writes := 0
	func save_file() -> Error:
		writes += 1
		return OK

var failures := 0
var checks := 0
var game: GameController
var controller: RunController
var definition: RunDefinition = load("res://resources/runs/m1_run.tres")
var probe := SaveProbe.new()

func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)

func _init() -> void:
	call_deferred("run_tests")

func result(outcome := "victory", hp := 23) -> Dictionary:
	return {"run_instance_id": controller.run.run_instance_id,
		"encounter_instance_id": controller.run.current_encounter_instance_id,
		"result_id": controller.run.current_encounter_instance_id + ":test",
		"outcome": outcome, "core_hp": hp}

func new_attempt() -> void:
	if controller.run.is_active(): controller.abandon_run(controller.run.run_instance_id)
	check(controller.new_run(), "New Run allowed from inactive/terminal state")

func advance_to(slot_index: int) -> void:
	while controller.run.current_slot_index < slot_index:
		controller.accept_encounter_result(result())
		controller.continue_run()

func one_fire_board() -> void:
	var level := LevelDefinition.new()
	var stack := StackDefinition.new()
	stack.tile_types.assign(["fire"])
	level.stacks.assign([stack])
	game.board = BoardModel.new(level)
	game.tray.tiles.assign(["fire", "fire"])
	game.encounter_queue.clear()
	game.battle.enemy_hp = 1

func run_tests() -> void:
	var save_path := "user://rune_trio_progress.cfg"
	var save_existed := FileAccess.file_exists(save_path)
	var save_before := FileAccess.get_file_as_bytes(save_path) if save_existed else PackedByteArray()
	game = GameController.new(); game.balance = BalanceConfig.new()
	root.add_child(game)
	probe.highest_unlocked_level = 13
	probe.completed_level_ids.assign(["level_1", "level_10"])
	probe.relic_ids.assign(["golem_heart"])
	game.progress = probe; game.save_enabled = true
	controller = RunController.new(); controller.definition = definition
	controller.bind_game(game); root.add_child(controller)
	check(controller.run.status == RunState.Status.IDLE, "initial IDLE")
	check(definition.validation_errors().is_empty(), "M1 definition validates")
	var sources := ["level_1", "level_2", "level_5", "level_10", "level_11", "level_16", "level_15", "level_20", "level_17", "level_19", "level_5", "level_20"]
	for index in sources.size():
		check(definition.slots[index].level.id == sources[index], "fixed source at slot %d" % (index + 1))
	new_attempt()
	var first_run := controller.run
	var first_id := first_run.run_instance_id
	check(first_run.current_slot_index == 0 and first_run.completed_encounters == 0 and game.battle.core_hp == 40 and game.tray.tiles.is_empty(), "slot 1, 40 HP, empty Tray")
	check(not controller.new_run() and controller.run == first_run, "double New Run ignored")
	check(not controller.continue_run(), "Continue during battle ignored")
	var old_board := game.board
	var old_tray := game.tray
	var old_battle := game.battle
	game.board.remove_tile(game.board.available_ids()[0])
	game.tray.tiles.assign(["wind"])
	game.battle.core_hp = 23; game.battle.core_shield = 9
	game.battle.enemy_frozen = true; game.battle.boss_cycle_step = 3
	var old_result := result("victory", game.battle.core_hp)
	check(controller.accept_encounter_result(old_result) and first_run.status == RunState.Status.BETWEEN_ENCOUNTERS, "victory enters BETWEEN_ENCOUNTERS")
	check(first_run.boundary_hp == 23 and first_run.completed_encounters == 1, "actual Core HP stored at boundary")
	check(not controller.accept_encounter_result(old_result) and first_run.completed_encounters == 1, "duplicate result ignored")
	check(not controller.new_run(), "New Run cannot replace between-encounter state")
	check(controller.continue_run() and first_run.current_slot_index == 1 and first_run.status == RunState.Status.BATTLE, "Continue launches next slot")
	check(not controller.continue_run() and first_run.current_slot_index == 1, "double Continue cannot skip slot")
	check(game.battle.core_hp == 23 and game.battle.core_shield == 0, "Core damage carries; Shield resets")
	check(game.board != old_board and game.tray != old_tray and game.battle != old_battle and game.tray.tiles.is_empty(), "fresh Board, Tray and Battle")
	check(game.board.remaining_count() == game.current_level.tile_count() and not game.battle.enemy_frozen and game.battle.boss_cycle_step == 0 and game.current_enemy_number == 1, "fresh board and enemy counters/statuses")
	check(not controller.accept_encounter_result(old_result) and game.battle.core_hp == 23, "stale encounter callback ignored")
	var active_board := game.board
	game.restart(); game.restart_action(); game.start_level(0)
	check(game.board == active_board and not game.next_level() and not game.start_campaign_level(0), "legacy entry/restart commands cannot bypass run")
	var encounter_ids := [first_run.current_encounter_instance_id]
	for slot_index in range(2, 4):
		controller.accept_encounter_result(result())
		controller.continue_run()
		check(not encounter_ids.has(first_run.current_encounter_instance_id), "unique encounter instance at slot %d" % (slot_index + 1))
		encounter_ids.append(first_run.current_encounter_instance_id)
	var boss_result := result("victory", 22)
	controller.accept_encounter_result(boss_result)
	check(first_run.status == RunState.Status.BETWEEN_ENCOUNTERS and first_run.boundary_hp == 38, "boss slot 4 heals and does not end run")
	check(not controller.accept_encounter_result(boss_result) and first_run.boundary_hp == 38, "boss recovery applies once")
	controller.continue_run()
	check(definition.chapter_index_for_slot(first_run.current_slot_index) == 1, "Continue enters Chapter 2")
	# Finish sequentially, including the reused level_20 in slots 8 and 12.
	advance_to(7)
	check(game.current_level.id == "level_20", "slot 8 reuses level_20")
	var slot8_result := result("victory", 12)
	controller.accept_encounter_result(slot8_result)
	check(first_run.status == RunState.Status.BETWEEN_ENCOUNTERS and first_run.boundary_hp == 32, "slot 8 is chapter end, NOT run victory")
	check(not controller.accept_encounter_result(slot8_result) and first_run.boundary_hp == 32, "slot 8 recovery not repeated")
	controller.continue_run()
	check(controller.chapter().id == "eclipse_lands" and game.battle.core_hp == 32, "slot 9 starts Eclipse Lands with recovery HP")
	advance_to(11)
	check(game.current_level.id == "level_20" and first_run.current_encounter_instance_id != slot8_result.encounter_instance_id, "slot 12 has separate instance of same resource")
	controller.accept_encounter_result(result("victory", 1))
	check(first_run.status == RunState.Status.VICTORY and first_run.completed_encounters == 12 and first_run.boundary_hp == 1, "slot 12 ends run WITHOUT recovery")
	check(not controller.continue_run() and not controller.abandon_run(first_id), "terminal victory rejects Continue/Abandon")
	for hp in [1, 12, 22, 35]:
		check(definition.hp_after_victory(3, hp) == {1:32, 12:32, 22:38, 35:40}[hp], "recovery formula %d" % hp)
	for reason in ["ROW_FULL", "CORE_DESTROYED", "BOARD_EXHAUSTED"]:
		new_attempt(); advance_to(3)
		var loss_hp := 0 if reason == "CORE_DESTROYED" else 12
		controller.accept_encounter_result(result(reason, loss_hp))
		check(controller.run.status == RunState.Status.DEFEAT and controller.run.defeat_reason == reason and controller.run.boundary_hp == loss_hp, reason + " ends run without recovery")
	var defeated_run := controller.run
	var stale_run_result := result()
	new_attempt()
	check(controller.run != defeated_run and controller.run.run_instance_id != defeated_run.run_instance_id and controller.run.current_slot_index == 0 and game.battle.core_hp == 40, "New Run after Defeat creates new instance at full HP")
	stale_run_result.encounter_instance_id = controller.run.current_encounter_instance_id
	check(not controller.accept_encounter_result(stale_run_result), "old run ID rejected even with current encounter ID")
	var paused_run := controller.run
	var paused_encounter := paused_run.current_encounter_instance_id
	game.pause_game()
	check(paused and paused_run.status == RunState.Status.BATTLE and not game.can_select(game.board.available_ids()[0]), "pause blocks actions without progression transition")
	game.continue_game()
	check(not paused and controller.run == paused_run and paused_run.current_encounter_instance_id == paused_encounter, "resume preserves encounter and progression")
	check(not controller.abandon_run(first_id), "stale abandon confirmation ignored")
	game.pause_game()
	check(controller.abandon_run(paused_run.run_instance_id) and not paused and game.state == "menu" and paused_run.status == RunState.Status.ABANDONED, "confirmed abandon from pause clears battle and resumes menu")
	new_attempt(); controller.accept_encounter_result(result())
	check(controller.abandon_run(controller.run.run_instance_id) and controller.run.status == RunState.Status.ABANDONED, "abandon between encounters")
	for invalid_kind in ["count", "level", "role", "chapter", "identity"]:
		var invalid: RunDefinition = definition.duplicate(true)
		match invalid_kind:
			"count": invalid.slots.pop_back()
			"level": invalid.slots[0].erase("level")
			"role": invalid.slots[0].role = "boss"
			"chapter": invalid.chapters[1].first_slot = 3
			"identity": invalid.chapters[1].id = invalid.chapters[0].id
		controller.definition = invalid
		check(not controller.new_run() and not controller.validation_errors.is_empty() and game.board == null, "invalid definition rejected BEFORE launch: " + invalid_kind)
	controller.definition = definition
	new_attempt()
	var emitted: Array[Dictionary] = []
	game.encounter_finished.connect(func(event): emitted.append(event))
	one_fire_board()
	game.select_tile_immediate(0)
	check(game.board.is_empty() and controller.run.status == RunState.Status.BETWEEN_ENCOUNTERS and emitted[-1].outcome == "victory", "last Triple kill wins over BOARD_EXHAUSTED")
	game.finish_selection(); game.finish_selection()
	check(emitted.size() == 1, "real GameController emits one result only")
	for reason in ["ROW_FULL", "CORE_DESTROYED", "BOARD_EXHAUSTED"]:
		new_attempt()
		match reason:
			"ROW_FULL": game.tray.tiles.assign(["fire", "fire", "ice", "ice", "wind", "wind", "life"])
			"CORE_DESTROYED":
				game.battle.core_hp = 1
				game.battle.start_enemy(EnemyCatalog.by_id("brute"))
				game.battle.enemy_action_counter = 1
				game.resolve_triples(["fire", "fire", "fire"])
			"BOARD_EXHAUSTED": game.board.active.clear()
		game.finish_selection()
		check(controller.run.status == RunState.Status.DEFEAT and emitted[-1].outcome == reason, "real battle result reports " + reason)
	# Exercise the campaign-completion branch at each reused boss source.
	new_attempt()
	for slot in [3, 7, 11]:
		advance_to(slot)
		game.battle.core_hp = 22
		while game.state == "playing":
			game.battle.enemy_hp = 1
			game.resolve_triples(["fire", "fire", "fire"])
		game.finish_selection()
		check(controller.run.status == (RunState.Status.VICTORY if slot == 11 else RunState.Status.BETWEEN_ENCOUNTERS), "real boss completion follows slot, not legacy level ID: %d" % (slot + 1))
		if slot != 11: controller.continue_run()
	# Both await boundaries must be invalidated by Abandon/New Run.
	game.balance.tile_move_duration = 0.03
	game.balance.triple_pop_duration = 0.08
	new_attempt()
	game.select_tile(game.board.available_ids()[0])
	controller.abandon_run(controller.run.run_instance_id)
	check(game.board == null and game.tray == null, "abandon during tile flight clears encounter")
	new_attempt()
	var fresh_board := game.board
	var fresh_count := fresh_board.remaining_count()
	await create_timer(0.16).timeout
	check(game.board == fresh_board and game.board.remaining_count() == fresh_count and game.tray.tiles.is_empty() and not game.busy, "old tile-move timer cannot mutate new run")
	one_fire_board()
	game.select_tile(0)
	await create_timer(0.05).timeout
	check(game.state == "won" and controller.run.status == RunState.Status.BATTLE, "winning action waits for pop animation before publishing")
	controller.abandon_run(controller.run.run_instance_id)
	new_attempt()
	var fresh_id := controller.run.current_encounter_instance_id
	await create_timer(0.12).timeout
	check(controller.run.current_encounter_instance_id == fresh_id and controller.run.completed_encounters == 0 and game.state == "playing", "old triple-pop timer cannot complete new run")
	# Inject a result while an old tile is still moving, then continue immediately.
	game.select_tile(game.board.available_ids()[0])
	controller.accept_encounter_result(result()); controller.continue_run()
	fresh_board = game.board
	await create_timer(0.12).timeout
	check(game.board == fresh_board and game.tray.tiles.is_empty() and controller.run.current_slot_index == 1, "old timer cannot mutate next encounter in same run")
	new_attempt()
	one_fire_board()
	game.triple_resolved.connect(func(_type):
		controller.abandon_run(controller.run.run_instance_id)
		controller.new_run(), CONNECT_ONE_SHOT)
	game.select_tile_immediate(0)
	check(game.state == "playing" and game.battle.enemy_hp == game.battle.current_enemy.max_hp and controller.run.completed_encounters == 0, "reentrant Triple callback cannot damage replacement run")
	controller.abandon_run(controller.run.run_instance_id)
	game.enemy_changed.connect(func(_index, _total): controller.abandon_run(controller.run.run_instance_id), CONNECT_ONE_SHOT)
	controller.new_run()
	check(game.state == "menu" and game.board == null and controller.run.status == RunState.Status.ABANDONED, "reentrant spawn callback cannot resurrect abandoned battle")
	check(probe.writes == 0 and probe.highest_unlocked_level == 13 and probe.completed_level_ids == ["level_1", "level_10"] and probe.relic_ids == ["golem_heart"], "run never writes or modifies CampaignSave, unlocks or trophies")
	check(FileAccess.file_exists(save_path) == save_existed and (not save_existed or FileAccess.get_file_as_bytes(save_path) == save_before), "real user campaign file remains byte-for-byte unchanged")
	if controller.run.is_active(): controller.abandon_run(controller.run.run_instance_id)
	controller.queue_free(); game.queue_free()
	await process_frame
	print("RUN FRAMEWORK: %d checks, %d failures (injection, not solver validation)" % [checks, failures])
	quit(failures)
