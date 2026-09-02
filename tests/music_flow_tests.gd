extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	if value: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var scene: GameView = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var audio = scene.audio
	check(audio.menu_music and audio.stone_ruins_music and audio.frozen_grove_music, "three music streams are assigned")
	check(audio.menu_music.loop and audio.stone_ruins_music.loop and audio.frozen_grove_music.loop, "all MP3 streams use Godot loop import")
	check(audio.music_player.bus == "Music" and is_equal_approx(audio.music_player.volume_db, -12.0), "music player uses Music bus at restrained baseline")
	check(audio.current_music == audio.menu_music, "Main Menu selects menu theme")
	var menu_tween = audio.music_tween
	scene.show_campaign();scene.hide_campaign()
	check(audio.current_music == audio.menu_music and audio.music_tween == menu_tween, "Levels and Back do not restart menu theme")
	scene.game.start_level(0);await process_frame
	check(audio.current_music == audio.stone_ruins_music, "Stone Ruins level selects stone music")
	var stone_tween = audio.music_tween
	scene.game.pause_game();scene.update_view();scene.game.continue_game();scene.update_view()
	check(audio.current_music == audio.stone_ruins_music and audio.music_tween == stone_tween, "Pause and Continue do not restart gameplay music")
	scene.previous_state="playing";scene.game.state="won";scene.update_view()
	check(audio.current_music == audio.stone_ruins_music, "Victory overlay keeps current music")
	scene.game.show_main_menu();await process_frame
	check(audio.current_music == audio.menu_music, "Main Menu transition restores menu theme")
	scene.game.start_level(10);await process_frame
	check(audio.current_music == audio.frozen_grove_music, "Level 11 selects frozen music")
	var music_index:=AudioServer.get_bus_index("Music");var sfx_index:=AudioServer.get_bus_index("SFX")
	scene.set_music_volume(0.0)
	check(AudioServer.is_bus_mute(music_index), "Music slider zero mutes Music")
	scene.set_music_volume(70.0);var music_db:=AudioServer.get_bus_volume_db(music_index)
	scene.set_sfx_volume(0.0)
	check(not AudioServer.is_bus_mute(music_index) and is_equal_approx(AudioServer.get_bus_volume_db(music_index),music_db), "SFX slider does not affect Music")
	scene.set_sfx_volume(80.0)
	if audio.music_tween: audio.music_tween.kill()
	audio.music_player.stop();audio.current_music=null;audio.music_unlocked=false;audio.pending_music=null
	audio.play_music(audio.menu_music)
	check(audio.current_music==null and audio.pending_music==audio.menu_music and not audio.music_player.playing,"locked Web-style audio defers playback")
	audio.unlock_audio()
	check(audio.current_music==audio.menu_music,"first interaction starts pending music")
	if audio.music_tween:audio.music_tween.kill()
	audio.music_player.stop();audio.sfx_player.stop()
	await create_timer(.25).timeout
	scene.queue_free();await process_frame;await process_frame
	print("\n","ALL MUSIC FLOW TESTS PASSED" if failures==0 else "%d MUSIC FLOW TESTS FAILED"%failures)
	quit(failures)
