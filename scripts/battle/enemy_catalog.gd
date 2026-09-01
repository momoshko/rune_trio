class_name EnemyCatalog
extends RefCounted

static func by_id(id: String) -> EnemyDefinition:
	var path := "res://resources/enemies/%s.tres" % id
	return load(path) if ResourceLoader.exists(path) else null
