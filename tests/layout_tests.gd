extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	if value: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)

func settle() -> void:
	for i in 3: await process_frame

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var scene: GameView = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	scene.game.play()
	for viewport_size in [Vector2(720,1280), Vector2(540,960), Vector2(1280,720)]:
		scene.size = viewport_size; scene.request_layout_refresh(); await settle()
		var board := scene.board_rect()
		var battle := scene.battle_rect()
		check(board.size.x >= minf(480.0, viewport_size.x * .75) and board.size.y >= 360.0, "initial Board layout has a useful size at %s" % viewport_size)
		check(absf(board.get_center().x - viewport_size.x * .5) < 2.0, "Board is centered at %s" % viewport_size)
		check(board.position.x >= -1.0 and board.end.x <= viewport_size.x + 1.0 and board.end.y <= viewport_size.y + 1.0, "Board fits viewport at %s" % viewport_size)
		check(battle.position.x >= -1.0 and battle.end.x <= viewport_size.x + 1.0 and battle.end.y <= board.position.y + 1.0, "Battle panel has a bounded non-overlapping region at %s" % viewport_size)
		var hud:Control=scene.get_node("Center/Content/HUD")
		var remaining:Label=scene.get_node("Center/Content/HUD/Rows/Remaining")
		check(not remaining.text.is_empty() and hud.global_position.y + hud.size.y <= battle.position.y + 1.0, "gameplay HUD fits above Battle panel at %s" % viewport_size)
		scene.game.show_main_menu(); scene.show_campaign(); await settle()
		var campaign_panel:Control=scene.get_node("CampaignOverlay/Center/Panel")
		var campaign_rect:=Rect2(campaign_panel.global_position,campaign_panel.size)
		check(campaign_rect.position.x>=-1.0 and campaign_rect.end.x<=viewport_size.x+1.0 and campaign_rect.position.y>=-1.0 and campaign_rect.end.y<=viewport_size.y+1.0,"Campaign screen fits viewport at %s"%viewport_size)
		scene.hide_campaign();scene.game.play();await settle()
	var refreshes_before := scene.layout_refresh_count
	scene.size = Vector2(720,1280); scene.request_layout_refresh(); await settle()
	check(scene.layout_refresh_count > refreshes_before and scene.board_rect().size.x >= 700.0, "resize back uses the same layout refresh path")
	scene.queue_free()
	print("\n", "ALL LAYOUT TESTS PASSED" if failures == 0 else "%d LAYOUT TESTS FAILED" % failures)
	quit(failures)
