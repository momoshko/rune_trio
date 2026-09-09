class_name RelicDefinition
extends Resource
@export_category("Relic")
@export_group("Identity")
@export var id:=""
@export var name_key:=""
@export var description_key:=""
@export var icon_key:=""
@export_enum("COMMON", "RARE") var rarity := "COMMON"
@export_enum("ATTACK", "CONTROL", "DEFENSE", "MIXED") var category := "MIXED"
@export var rules: Array[RelicRule] = []
@export_group("Visuals")
@export var texture:Texture2D
