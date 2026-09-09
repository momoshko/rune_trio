class_name TrayModel
extends RefCounted

var capacity: int
var tiles: Array[String] = []

func _init(tray_capacity: int) -> void:
	capacity = tray_capacity

func reset() -> void:
	tiles.clear()

func insertion_index(type_id: String) -> int:
	var last := -1
	for i in tiles.size():
		if tiles[i] == type_id: last = i
	return last + 1 if last >= 0 else tiles.size()

func add_tile(type_id: String) -> Dictionary:
	var index := insert_tile(type_id)
	var removed := resolve_triples()
	return {"insert_index":index, "removed":removed}

func insert_tile(type_id: String) -> int:
	var index := insertion_index(type_id)
	tiles.insert(index, type_id)
	return index

func matched_type() -> String:
	for type_id in tiles:
		if tiles.count(type_id) >= 3: return type_id
	return ""

func remove_matched_triple(type_id: String) -> Array[String]:
	var removed: Array[String] = []
	if tiles.count(type_id) < 3: return removed
	for index in 3:
		tiles.remove_at(tiles.find(type_id))
		removed.append(type_id)
	return removed

func resolve_triples() -> Array[String]:
	var removed: Array[String] = []
	var match_type := matched_type()
	while not match_type.is_empty():
		removed.append_array(remove_matched_triple(match_type))
		match_type = matched_type()
	return removed

func is_full() -> bool:
	return tiles.size() >= capacity
