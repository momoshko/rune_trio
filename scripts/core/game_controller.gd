class_name GameController
extends Node

signal state_changed
signal tile_moving(placement, insert_index)
signal triple_resolved(type_id)
signal combat_feedback(event)
signal enemy_changed(index, total)
signal progress_changed
signal encounter_finished(result: Dictionary)

@export var levels: Array[LevelDefinition] = []
@export var balance: BalanceConfig
var board: BoardModel
var tray: TrayModel
var state := "menu"
var busy := false
var current_level_index := 0
var battle: BattleModel
var battle_enabled := true
var encounter_queue: Array[String] = []
var current_enemy_number := 0
var encounter_total := 0
var progress: CampaignSave
var save_enabled := false
var run_mode := false
var run_instance_id := ""
var encounter_instance_id := ""
var _run_level: LevelDefinition
var _action_generation := 0
var _result_sent := false
var _encounter_outcome := ""
@export var save_path := "user://rune_trio_progress.cfg"

var current_level: LevelDefinition:
	get: return _run_level if run_mode else (levels[current_level_index] if not levels.is_empty() else null)

var level: LevelDefinition:
	get: return current_level
	set(value): levels = [value]; current_level_index = 0

func _ready() -> void:
	progress = CampaignSave.new(); progress.load_file(save_path); save_enabled = true
	show_main_menu()

func play() -> void:
	ensure_progress(); start_level(mini(progress.highest_unlocked_level - 1, levels.size() - 1))

func ensure_progress()->void:
	if progress==null:progress=CampaignSave.new()

func start_campaign_level(index:int)->bool:
	if run_mode: return false
	ensure_progress()
	if index<0 or index>=levels.size() or not progress.is_unlocked(index):return false
	start_level(index);return true

func show_main_menu() -> void:
	_action_generation += 1
	run_mode = false; _run_level = null; run_instance_id = ""; encounter_instance_id = ""
	if is_inside_tree(): get_tree().paused = false
	board = null; tray = null; battle = null
	encounter_queue.clear(); current_enemy_number = 0; encounter_total = 0
	state = "menu"; busy = true
	state_changed.emit()

func pause_game() -> void:
	if state != "playing" or busy: return
	state = "paused"; busy = true; state_changed.emit()
	if is_inside_tree(): get_tree().paused = true

func continue_game() -> void:
	if state != "paused": return
	if is_inside_tree(): get_tree().paused = false
	state = "playing"; busy = false; state_changed.emit()

func restart() -> void:
	if run_mode: return
	_prepare_encounter(balance.core_max_hp)

func start_run_encounter(source: LevelDefinition, hp: int, run_id: String, encounter_id: String, relics: Array[RelicDefinition] = []) -> void:
	run_mode = true; _run_level = source
	run_instance_id = run_id; encounter_instance_id = encounter_id
	_prepare_encounter(hp, relics)

func _prepare_encounter(hp: int, relics: Array[RelicDefinition] = []) -> void:
	_action_generation += 1
	var generation := _action_generation
	_result_sent = false
	_encounter_outcome = ""
	if is_inside_tree(): get_tree().paused = false
	board = BoardModel.new(current_level)
	tray = TrayModel.new(balance.tray_capacity)
	var active_relics: Array[RelicDefinition] = []
	if run_mode: active_relics.assign(relics)
	battle = BattleModel.new(balance, null, active_relics)
	battle.core_hp = hp
	encounter_queue = current_level.encounter_enemy_ids.duplicate()
	encounter_total = encounter_queue.size(); current_enemy_number = 0
	if battle_enabled and encounter_total > 0: spawn_next_enemy()
	if generation != _action_generation: return
	state = "playing"; busy = false
	state_changed.emit()

func start_level(index: int) -> void:
	if run_mode: return
	current_level_index = clampi(index, 0, levels.size() - 1)
	restart()

func next_level() -> bool:
	if run_mode: return false
	if state not in ["won","milestone"] or current_level_index + 1 >= levels.size(): return false
	start_level(current_level_index + 1)
	return true

func restart_action() -> void:
	if state == "campaign_complete": start_level(0)
	else: restart()

func replay_chapter() -> void:
	start_level(0)

func complete_current_level()->void:
	_encounter_outcome = "victory"
	if run_mode:
		state = "won"; busy = true
		return
	ensure_progress();var number:=current_level_index+1;var relic_id:="golem_heart" if number==10 else ("frozen_crown" if number==20 else "")
	progress.complete(current_level.id,number,relic_id)
	if save_enabled:progress.save_file()
	progress_changed.emit()
	if number==20:state="campaign_complete"
	elif number==10:state="milestone"
	else:state="won"
	busy=true

func can_select(tile_id: int) -> bool:
	return state == "playing" and not busy and board.is_available(tile_id)

func select_tile(tile_id: int) -> void:
	if not can_select(tile_id): return
	var generation := _action_generation
	busy = true
	var tile := board.remove_tile(tile_id)
	var insert_index := tray.insertion_index(tile.type_id)
	tile_moving.emit(tile, insert_index); state_changed.emit()
	if generation != _action_generation: return
	await get_tree().create_timer(balance.tile_move_duration).timeout
	if generation != _action_generation: return
	var resolved := _add_rune_and_resolve(tile.type_id)
	if generation != _action_generation: return
	if resolved:
		state_changed.emit()
		if generation != _action_generation: return
		await get_tree().create_timer(balance.triple_pop_duration).timeout
		if generation != _action_generation: return
	finish_selection()

func select_tile_immediate(tile_id: int) -> bool:
	if not can_select(tile_id): return false
	var generation := _action_generation
	busy = true
	var tile := board.remove_tile(tile_id)
	_add_rune_and_resolve(tile.type_id)
	if generation != _action_generation: return true
	finish_selection()
	return true

func _add_rune_and_resolve(type_id: String) -> bool:
	var generation := _action_generation
	tray.insert_tile(type_id)
	var matched := tray.matched_type()
	var resolved := false
	while not matched.is_empty():
		# Snapshot after insertion but BEFORE removal/effects (7th matching Rune included).
		var context := battle.capture_triple_context(matched, tray.tiles.size()) if battle_active() else {}
		var removed := tray.remove_matched_triple(matched)
		resolved = true
		resolve_triples(removed, context)
		if generation != _action_generation or state != "playing": return resolved
		matched = tray.matched_type()
	return resolved

func battle_active() -> bool:
	return battle_enabled and encounter_total > 0

func spawn_next_enemy() -> bool:
	var generation := _action_generation
	if encounter_queue.is_empty(): return false
	var definition := EnemyCatalog.by_id(encounter_queue.pop_front())
	if definition == null: return false
	current_enemy_number += 1; battle.start_enemy(definition)
	enemy_changed.emit(current_enemy_number, encounter_total)
	if generation != _action_generation: return false
	combat_feedback.emit({"type":"enemy_spawned", "target":"enemy"})
	return true

func resolve_triples(removed: Array, context: Dictionary = {}) -> void:
	var generation := _action_generation
	for index in range(0, removed.size(), 3):
		var type_id: String = removed[index]
		triple_resolved.emit(type_id)
		if generation != _action_generation: return
		if not battle_active(): continue
		if board.locked_stack_id >= 0:
			board.clear_stack_lock()
			combat_feedback.emit({"type":"stone_lock_cleared", "target":"board"})
			if generation != _action_generation: return
		for event in battle.apply_triple(type_id, context):
			if event.type == "lock_stack_request":
				var candidates := board.safe_lock_candidates()
				if not candidates.is_empty() and board.lock_stack(candidates[-1]):
					combat_feedback.emit({"type":"stone_lock", "target":"board", "stack_id":board.locked_stack_id})
				else: combat_feedback.emit({"type":"stone_lock_skipped", "target":"board"})
			else: combat_feedback.emit(event)
			if generation != _action_generation: return
		var outcome := battle.combat_outcome()
		if outcome == "victory":
			var spawned := spawn_next_enemy()
			if generation != _action_generation: return
			if spawned: continue
			complete_current_level(); return
		if outcome == "CORE_DESTROYED":
			_encounter_outcome = outcome; state = "lost"; busy = true; return

func select_stack_immediate(stack_id: int) -> bool:
	var top := board.top_tile(stack_id)
	return select_tile_immediate(top.tile_id) if top else false

func finish_selection() -> void:
	if board == null: return
	# Combat victory is already terminal: never replace it with empty-board defeat.
	if state not in ["won", "milestone", "campaign_complete", "lost", "exhausted"]:
		if battle_active():
			_encounter_outcome = battle.action_outcome(tray.tiles.size(), tray.capacity, not board.available_ids().is_empty())
			match _encounter_outcome:
				"victory": complete_current_level()
				"CORE_DESTROYED", "ROW_FULL": state = "lost"
				"BOARD_EXHAUSTED": state = "exhausted"
		elif board.is_empty() and tray.tiles.is_empty(): complete_current_level()
		elif tray.is_full(): state = "lost"
	busy = state != "playing"
	_publish_encounter_result()
	state_changed.emit()

func seal_run_encounter(outcome: String) -> void:
	_encounter_outcome = outcome
	_action_generation += 1
	_result_sent = true
	busy = true
	state = "won" if outcome == "victory" else ("exhausted" if outcome == "BOARD_EXHAUSTED" else "lost")
	if is_inside_tree(): get_tree().paused = false

func _publish_encounter_result() -> void:
	if not run_mode or _result_sent or state not in ["won", "lost", "exhausted"]: return
	_result_sent = true
	encounter_finished.emit({"run_instance_id": run_instance_id, "encounter_instance_id": encounter_instance_id,
		"result_id": encounter_instance_id + ":result", "outcome": _encounter_outcome, "core_hp": battle.core_hp})
