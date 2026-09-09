extends SceneTree

var failures := 0

func require(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("smoke")

func smoke() -> void:
	var scene: GameView = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	for frame in 4: await process_frame
	scene.game.save_enabled = false
	var controller := scene.run_controller
	var offers: RunOfferView = scene.get_node("OfferOverlay")
	scene.get_node("MainMenu/Center/Panel/Play").pressed.emit()
	for frame in 3: await process_frame
	require(offers.visible and offers.buttons.size() == 2 and not scene.get_node("MainMenu").visible, "New Run shows choice")
	var original := controller.run.encounter_offer.duplicate()
	scene.menu_command(); scene.cancel_abandon(); scene.update_view()
	require(offers.visible and original == controller.run.encounter_offer, "Cancel exit does not reroll")
	var stale_button := offers.buttons[0]
	stale_button.pressed.emit(); stale_button.pressed.emit()
	require(controller.run.status == RunState.Status.BATTLE and not offers.visible, "Choose starts exactly one Battle")
	# One real Triple drives the normal reward through GameController's result signal.
	scene.game.battle.enemy_hp = 1
	var tiny := LevelDefinition.new()
	var stack := StackDefinition.new(); stack.tile_types.assign(["fire"]); tiny.stacks.append(stack)
	scene.game.board = BoardModel.new(tiny)
	scene.game.tray.tiles.assign(["fire", "fire"])
	scene.game.select_stack_immediate(0)
	require(controller.run.status == RunState.Status.REWARD and offers.visible and offers.buttons.size() == 3, "Real Victory shows reward")
	require(offers.buttons[2].disabled and offers.buttons[2].text == scene.tr("M4_CORE_RESTORED"), "Full HP Restore disabled and localized")
	require(not controller.claim_reward("restore_core", controller.run.offer_id("reward")), "Disabled Restore rejected by controller too")
	var reward_button := offers.buttons[0]
	reward_button.pressed.emit(); reward_button.pressed.emit()
	require(controller.run.acquired_relic_ids.size() == 1 and controller.run.status == RunState.Status.ENCOUNTER_CHOICE, "Reward callback cannot double-claim")
	# Layout-only smoke, no screenshots: scroll allows the same cards on short screens.
	root.size = Vector2i(540, 960)
	for frame in 4: await process_frame
	require(offers.size.x <= scene.size.x and offers.size.y <= scene.size.y, "Offer surface fits viewport")
	scene.menu_command(); scene.confirm_abandon()
	require(controller.run.status == RunState.Status.ABANDONED and scene.game.state == "menu" and not offers.visible, "Abandon returns to menu")
	scene.audio.music_player.stop(); scene.audio.sfx_player.stop()
	await create_timer(0.3).timeout
	scene.queue_free(); await process_frame
	print("M4 Run/UI smoke: 1 scenario — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
