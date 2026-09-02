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
	check(audio.button_click and audio.button_back and audio.level_select, "active UI streams are assigned")
	check(audio.button_hover == null, "UI hover sound is intentionally disabled")
	check(audio.victory and audio.defeat and audio.relic_unlock and audio.boss_intro, "flow streams are assigned")
	check(audio.sfx_player.bus == "SFX" and audio.music_player.bus == "Music", "players use separate buses")
	audio.play_sfx(null)
	check(true, "missing stream is safe")
	var music_index := AudioServer.get_bus_index("Music")
	var sfx_index := AudioServer.get_bus_index("SFX")
	var music_before := AudioServer.get_bus_volume_db(music_index)
	scene.set_sfx_volume(0.0)
	check(AudioServer.is_bus_mute(sfx_index), "SFX zero mutes SFX bus")
	check(is_equal_approx(AudioServer.get_bus_volume_db(music_index), music_before), "SFX slider does not change Music bus")
	scene.set_sfx_volume(80.0)
	var sfx_before := AudioServer.get_bus_volume_db(sfx_index)
	scene.set_music_volume(35.0)
	check(is_equal_approx(AudioServer.get_bus_volume_db(sfx_index), sfx_before), "Music slider does not change SFX bus")
	var level_button: Button = scene.get_node("CampaignOverlay/Center/Panel/StoneGrid").get_child(0)
	level_button.button_down.emit()
	check(audio.sfx_player.stream == audio.level_select, "Level button uses level_select without ui_click")
	var back_button: Button = scene.get_node("CampaignOverlay/Center/Panel/Back")
	back_button.button_down.emit()
	check(audio.sfx_player.stream == audio.button_back, "Back button uses ui_back without ui_click")
	var play_button: Button = scene.get_node("MainMenu/Center/Panel/Play")
	play_button.button_down.emit()
	check(audio.sfx_player.stream == audio.button_click, "ordinary button uses ui_click")
	play_button.mouse_entered.emit()
	check(audio.sfx_player.stream == audio.button_click, "button hover does not play another sound")
	scene.game.play()
	await process_frame
	scene.previous_state = "playing";scene.game.state = "won";scene.update_view()
	check(audio.sfx_player.stream == audio.victory, "ordinary victory uses victory SFX")
	scene.previous_state = "playing";scene.game.state = "lost";scene.update_view()
	check(audio.sfx_player.stream == audio.defeat, "defeat uses defeat SFX")
	scene.previous_state = "playing";scene.game.state = "milestone";scene.update_view()
	check(audio.sfx_player.stream == audio.relic_unlock, "boss relic reveal uses relic_unlock instead of victory")
	scene.intro_level = -1;scene.game.start_level(9)
	check(audio.sfx_player.stream == audio.boss_intro, "Boss overlay uses boss_intro SFX")
	audio.sfx_player.stop();audio.music_player.stop()
	await create_timer(0.25).timeout
	scene.queue_free()
	await process_frame;await process_frame
	print("\n", "ALL AUDIO SFX TESTS PASSED" if failures == 0 else "%d AUDIO SFX TESTS FAILED" % failures)
	quit(failures)
