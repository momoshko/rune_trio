class_name VisualLibrary
extends Resource

@export_category("Backgrounds")
@export var main_menu_background: Texture2D
@export var stone_ruins_background: Texture2D
@export var frozen_grove_background: Texture2D

@export_category("Core")
@export var core_texture: Texture2D
@export var core_glow_texture: Texture2D
@export var shield_overlay_texture: Texture2D
@export var core_path := ""

@export_category("Control Art")
# Optional paths keep missing art out of the scene's required resource dependencies.
@export var background_paths: Dictionary[String, String] = {}
@export var enemy_paths: Dictionary[String, String] = {}
@export var enemy_sizes: Dictionary[String, Vector2] = {}
@export var enemy_offsets: Dictionary[String, Vector2] = {}
@export var rune_tile_paths: Dictionary[String, String] = {}
# Crop transparent padding at draw time; the source PNGs stay untouched.
@export var texture_regions: Dictionary[String, Rect2] = {}
@export var background_modulate := Color(0.9, 0.92, 0.92, 1.0)
@export_range(0.0, 1.0) var battle_panel_opacity := 0.38
@export_range(0.0, 1.0) var board_panel_opacity := 0.08
@export_range(0.0, 1.0) var hud_panel_opacity := 0.76
var _texture_cache: Dictionary = {}

func background_texture(location: String) -> Texture2D:
	return _optional_texture(background_paths.get(location, ""))

func enemy_texture(enemy_id: String, phase_index := 0) -> Texture2D:
	var visual_id := "stone_golem_phase2" if enemy_id == "stone_golem" and phase_index > 0 else enemy_id
	return _optional_texture(enemy_paths.get(visual_id, ""))

func enemy_target_size(enemy_id: String) -> Vector2:
	return enemy_sizes.get(enemy_id, Vector2(96, 92))

func enemy_offset(enemy_id: String) -> Vector2:
	return enemy_offsets.get(enemy_id, Vector2.ZERO)

func rune_tile_texture(type_id: String) -> Texture2D:
	return _optional_texture(rune_tile_paths.get(type_id, ""))

func core_visual_texture() -> Texture2D:
	var mapped := _optional_texture(core_path)
	return mapped if mapped else core_texture

func _optional_texture(path: String) -> Texture2D:
	if path.is_empty(): return null
	if _texture_cache.has(path): return _texture_cache[path]
	var texture: Texture2D
	if ResourceLoader.exists(path, "Texture2D"):
		texture = ResourceLoader.load(path, "Texture2D") as Texture2D
	if texture and texture_regions.has(path):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = texture_regions[path]
		atlas.filter_clip = true
		texture = atlas
	_texture_cache[path] = texture
	return texture
