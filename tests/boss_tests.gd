extends SceneTree

var failures := 0
var config := BalanceConfig.new()

func check(value: bool, label: String) -> void:
	if value: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)

func triple(controller: GameController, type_id := "life") -> void:
	controller.resolve_triples([type_id,type_id,type_id])

func _init() -> void:
	var level: LevelDefinition = load("res://resources/levels/level_10.tres")
	var controller := GameController.new(); controller.levels = [level]; controller.balance = config; controller.restart()
	check(controller.battle.current_enemy.id == "stone_golem" and controller.battle.current_enemy.max_hp == 40, "Stone Golem spawns with configured HP")
	triple(controller); var events: Array = []; controller.combat_feedback.connect(func(event): events.append(event))
	triple(controller)
	check(controller.battle.boss_telegraph == "rock_throw" and events.any(func(event): return event.get("ability","") == "rock_throw"), "Rock Throw telegraphs before damage")
	var hp_before := controller.battle.core_hp; triple(controller)
	check(controller.battle.core_hp == hp_before - 6 and controller.battle.boss_telegraph == "", "Rock Throw deals configured Core damage")
	triple(controller); events.clear(); triple(controller)
	check(controller.battle.boss_telegraph == "stone_lock", "Stone Lock telegraphs")
	triple(controller)
	var locked := controller.board.locked_stack_id
	check(locked >= 0 and not controller.board.is_available(controller.board.top_tile(locked).tile_id), "Stone Lock blocks exactly one visible Top Tile")
	check(controller.board.available_ids().size() > 0, "Stone Lock leaves other stacks selectable")
	var available_before := controller.board.available_ids().size(); triple(controller)
	check(controller.board.locked_stack_id == -1 and controller.board.available_ids().size() >= available_before, "next successful Triple clears Stone Lock")
	controller.board.active.clear()
	for stack in level.stacks:
		if stack.stack_id == 0:
			controller.board.active[0] = TilePlacement.create(0, "fire", stack.position, 0, 0)
			break
	controller.battle.boss_cycle_step = 5; triple(controller)
	check(controller.board.locked_stack_id == -1 and controller.board.available_ids().size() == 1, "Stone Lock skips when it would remove the final move")
	controller.restart(); controller.battle.enemy_hp = 1; triple(controller, "fire")
	check(controller.state == "won", "Golem death immediately completes its configured Level")
	controller.free()
	print("\n", "ALL BOSS TESTS PASSED" if failures == 0 else "%d BOSS TESTS FAILED" % failures)
	quit(failures)
