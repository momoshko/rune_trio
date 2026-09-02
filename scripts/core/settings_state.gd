class_name SettingsState
extends RefCounted

const DEFAULT_MUSIC := 70.0
const DEFAULT_SFX := 80.0
var music_volume := DEFAULT_MUSIC
var sfx_volume := DEFAULT_SFX
var path := "user://rune_trio_settings.cfg"

func load_file() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	music_volume = clampf(float(config.get_value("audio", "music", DEFAULT_MUSIC)), 0.0, 100.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx", DEFAULT_SFX)), 0.0, 100.0)

func save_file() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	return config.save(path)
