class_name TileCatalog
extends RefCounted

static func all() -> Dictionary:
	var result := {}
	for path in [
		"res://resources/tiles/fire.tres", "res://resources/tiles/ice.tres",
		"res://resources/tiles/lightning.tres", "res://resources/tiles/wind.tres",
		"res://resources/tiles/life.tres", "res://resources/tiles/shield.tres"
	]:
		var definition: TileDefinition = load(path)
		result[definition.id] = definition
	return result
