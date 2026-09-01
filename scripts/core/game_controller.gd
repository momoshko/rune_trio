class_name GameController
extends Node

signal state_changed
signal tile_moving(placement, insert_index)
signal triple_resolved(type_id)

@export var level: LevelDefinition
@export var balance: BalanceConfig
var board: BoardModel
var tray: TrayModel
var state := "playing"
var busy := false

func _ready() -> void:
	restart()

func restart() -> void:
	board = BoardModel.new(level)
	tray = TrayModel.new(balance.tray_capacity)
	state = "playing"; busy = false
	state_changed.emit()

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
		triple_resolved.emit(tile.type_id); state_changed.emit()
		await get_tree().create_timer(balance.triple_pop_duration).timeout
	finish_selection()

func select_tile_immediate(tile_id: int) -> bool:
	if state != "playing" or not board.is_available(tile_id): return false
	var tile := board.remove_tile(tile_id)
	tray.add_tile(tile.type_id)
	finish_selection()
	return true

func finish_selection() -> void:
	if board.is_empty() and tray.tiles.is_empty(): state = "won"
	elif tray.is_full(): state = "lost"
	busy = false
	state_changed.emit()
