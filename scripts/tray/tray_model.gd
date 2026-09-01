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
	var index := insertion_index(type_id)
	tiles.insert(index, type_id)
	var removed := resolve_triples()
	return {"insert_index":index, "removed":removed}

func resolve_triples() -> Array[String]:
	var removed: Array[String] = []
	var changed := true
	while changed:
		changed = false
		for type_id in tiles.duplicate():
			if tiles.count(type_id) >= 3:
				for i in 3: tiles.remove_at(tiles.find(type_id)); removed.append(type_id)
				changed = true
				break
	return removed

func is_full() -> bool:
	return tiles.size() >= capacity
