extends SceneTree

var failures:=0
func check(value:bool,label:String)->void:
	if value:print("PASS: ",label)
	else:failures+=1;push_error("FAIL: "+label)

func has_property(resource:Resource,property_name:StringName)->bool:
	return resource.get_property_list().any(func(item):return item.name==property_name)

func _init()->void:call_deferred("run")

func run()->void:
	var audio_library:AudioLibrary=load("res://resources/audio/audio_library.tres")
	var visual_library:VisualLibrary=load("res://resources/visuals/visual_library.tres")
	check(audio_library!=null and audio_library.menu_music and audio_library.ui_click,"AudioLibrary loads with existing assignments")
	check(has_property(audio_library,"tile_land") and has_property(audio_library,"relic_unlock"),"AudioLibrary exposes manual Puzzle and Flow slots")
	check(visual_library!=null and has_property(visual_library,"main_menu_background") and has_property(visual_library,"shield_overlay_texture"),"VisualLibrary exposes Background and Core slots")
	var tile:TileDefinition=load("res://resources/tiles/fire.tres")
	var enemy:EnemyDefinition=load("res://resources/enemies/stone_golem.tres")
	var relic:RelicDefinition=load("res://resources/relics/golem_heart.tres")
	check(has_property(tile,"texture") and has_property(tile,"glow_texture"),"Tile resources expose Texture2D slots")
	check(has_property(enemy,"texture") and has_property(enemy,"portrait"),"Enemy resources expose Texture2D slots")
	check(has_property(relic,"texture"),"Relic resources expose Texture2D slot")
	var scene:GameView=load("res://scenes/main/main.tscn").instantiate();root.add_child(scene);await process_frame
	check(scene.audio.library==audio_library and scene.visual_library==visual_library,"Main scene references both editable libraries")
	scene.audio.play_sfx(null);check(true,"null asset fallback is safe")
	if scene.audio.music_tween:scene.audio.music_tween.kill()
	scene.audio.music_player.stop();scene.audio.sfx_player.stop();scene.queue_free();await process_frame;await process_frame
	print("\n","ALL ASSET LIBRARY TESTS PASSED" if failures==0 else "%d ASSET LIBRARY TESTS FAILED"%failures)
	quit(failures)
