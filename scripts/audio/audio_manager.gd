class_name AudioManager
extends Node

@export var library: AudioLibrary

var button_hover:AudioStream:
	get:
		return library.ui_hover if library else null
var button_click:AudioStream:
	get:
		return library.ui_click if library else null
var button_back:AudioStream:
	get:
		return library.ui_back if library else null
var level_select:AudioStream:
	get:
		return library.level_select if library else null
var tile_pick:AudioStream:
	get:
		return library.tile_pick if library else null
var tile_to_tray:AudioStream:
	get:
		return library.tile_land if library else null
var triple_complete:AudioStream:
	get:
		return library.triple if library else null
var enemy_hit:AudioStream:
	get:
		return library.enemy_hit if library else null
var enemy_attack:AudioStream:
	get:
		return library.enemy_attack if library else null
var core_hit:AudioStream:
	get:
		return library.core_hit if library else null
var enemy_death:AudioStream:
	get:
		return library.enemy_death if library else null
var victory:AudioStream:
	get:
		return library.victory if library else null
var defeat:AudioStream:
	get:
		return library.defeat if library else null
var relic_unlock:AudioStream:
	get:
		return library.relic_unlock if library else null
var boss_intro:AudioStream:
	get:
		return library.boss_intro if library else null
var menu_music:AudioStream:
	get:
		return library.menu_music if library else null
var stone_ruins_music:AudioStream:
	get:
		return library.stone_ruins_music if library else null
var frozen_grove_music:AudioStream:
	get:
		return library.frozen_grove_music if library else null

var music_player := AudioStreamPlayer.new()
var sfx_player := AudioStreamPlayer.new()
var current_music: AudioStream
var music_tween: Tween
var music_unlocked := not OS.has_feature("web")
var pending_music: AudioStream
const MUSIC_PLAYER_DB := -12.0

func _ready() -> void:
	music_player.bus = "Music"
	music_player.volume_db = MUSIC_PLAYER_DB
	sfx_player.bus = "SFX"
	add_child(music_player)
	add_child(sfx_player)

func play_ui(stream: AudioStream) -> void:
	play_sfx(stream)

func play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	sfx_player.stream = stream
	sfx_player.play()

func play_music(stream: AudioStream) -> void:
	if not music_unlocked:
		pending_music = stream
		return
	if stream == current_music:
		return
	if current_music == null or not music_player.playing:
		current_music = stream
		if music_tween:
			music_tween.kill()
		music_player.stop()
		music_player.stream = stream
		music_player.volume_db = MUSIC_PLAYER_DB
		if stream:
			music_player.play()
		return
	current_music = stream
	if music_tween: music_tween.kill()
	music_tween = create_tween()
	music_tween.tween_property(music_player, "volume_db", -35.0, 0.3)
	music_tween.tween_callback(func():
		music_player.stop()
		music_player.stream = stream
		if stream: music_player.play()
	)
	if stream: music_tween.tween_property(music_player, "volume_db", MUSIC_PLAYER_DB, 0.45)

func unlock_audio() -> void:
	if music_unlocked:
		return
	music_unlocked = true
	var stream := pending_music
	pending_music = null
	play_music(stream)

func element_stream(type_id: String) -> AudioStream:
	if library == null:return null
	return {"fire": library.fire, "ice": library.ice, "lightning": library.lightning, "wind": library.wind, "life": library.life, "shield": library.shield}.get(type_id)
