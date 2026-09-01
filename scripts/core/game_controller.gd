class_name GameController
extends Node

signal state_changed
signal tile_moving(placement, insert_index)
signal triple_resolved(type_id)
signal combat_feedback(event)
signal enemy_changed(index, total)
signal progress_changed

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
@export var save_path := "user://rune_trio_progress.cfg"

var current_level: LevelDefinition:
	get: return levels[current_level_index] if not levels.is_empty() else null

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
	ensure_progress()
	if index<0 or index>=levels.size() or not progress.is_unlocked(index):return false
	start_level(index);return true

func show_main_menu() -> void:
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
	if is_inside_tree(): get_tree().paused = false
	board = BoardModel.new(current_level)
	tray = TrayModel.new(balance.tray_capacity)
	battle = BattleModel.new(balance)
	encounter_queue = current_level.encounter_enemy_ids.duplicate()
	encounter_total = encounter_queue.size(); current_enemy_number = 0
	if battle_enabled and encounter_total > 0: spawn_next_enemy()
	state = "playing"; busy = false
	state_changed.emit()

func start_level(index: int) -> void:
	current_level_index = clampi(index, 0, levels.size() - 1)
	restart()

func next_level() -> bool:
	if state not in ["won","milestone"] or current_level_index + 1 >= levels.size(): return false
	start_level(current_level_index + 1)
	return true

func restart_action() -> void:
	if state == "campaign_complete": start_level(0)
	else: restart()

func replay_chapter() -> void:
	start_level(0)

func complete_current_level()->void:
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
	busy = true
	var tile := board.remove_tile(tile_id)
	var insert_index := tray.insertion_index(tile.type_id)
	tile_moving.emit(tile, insert_index); state_changed.emit()
	await get_tree().create_timer(balance.tile_move_duration).timeout
	var result := tray.add_tile(tile.type_id)
	if not result.removed.is_empty():
		resolve_triples(result.removed); state_changed.emit()
		await get_tree().create_timer(balance.triple_pop_duration).timeout
	finish_selection()

func select_tile_immediate(tile_id: int) -> bool:
	if state != "playing" or not board.is_available(tile_id): return false
	var tile := board.remove_tile(tile_id)
	var result := tray.add_tile(tile.type_id)
	if not result.removed.is_empty(): resolve_triples(result.removed)
	finish_selection()
	return true

func battle_active() -> bool:
	return battle_enabled and encounter_total > 0

func spawn_next_enemy() -> bool:
	if encounter_queue.is_empty(): return false
	var definition := EnemyCatalog.by_id(encounter_queue.pop_front())
	if definition == null: return false
	current_enemy_number += 1; battle.start_enemy(definition)
	enemy_changed.emit(current_enemy_number, encounter_total)
	combat_feedback.emit({"type":"enemy_spawned", "target":"enemy"})
	return true

func resolve_triples(removed: Array) -> void:
	for index in range(0, removed.size(), 3):
		var type_id: String = removed[index]
		triple_resolved.emit(type_id)
		if not battle_active(): continue
		if board.locked_stack_id >= 0:
			board.clear_stack_lock()
			combat_feedback.emit({"type":"stone_lock_cleared", "target":"board"})
		for event in battle.apply_triple(type_id):
			if event.type == "lock_stack_request":
				var candidates := board.safe_lock_candidates()
				if not candidates.is_empty() and board.lock_stack(candidates[-1]):
					combat_feedback.emit({"type":"stone_lock", "target":"board", "stack_id":board.locked_stack_id})
				else: combat_feedback.emit({"type":"stone_lock_skipped", "target":"board"})
			else: combat_feedback.emit(event)
		if battle.enemy_hp <= 0:
			if spawn_next_enemy(): continue
			complete_current_level(); return
		if battle.core_hp <= 0:
			state = "lost"; busy = true; return

func select_stack_immediate(stack_id: int) -> bool:
	var top := board.top_tile(stack_id)
	return select_tile_immediate(top.tile_id) if top else false

func finish_selection() -> void:
	if state in ["won", "milestone", "campaign_complete", "lost", "exhausted"]: busy = state != "playing"; state_changed.emit(); return
	if board.is_empty() and battle_active(): state = "exhausted"
	elif board.is_empty() and tray.tiles.is_empty(): complete_current_level()
	elif tray.is_full(): state = "lost"
	busy = false
	state_changed.emit()
