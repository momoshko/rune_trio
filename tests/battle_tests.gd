extends SceneTree

var failures := 0
var config := BalanceConfig.new()

func check(value: bool, label: String) -> void:
	if value: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)

func fresh() -> BattleModel:
	return BattleModel.new(config)

func _init() -> void:
	var battle := fresh(); battle.apply_triple("fire")
	check(battle.enemy_hp == config.enemy_hp - config.fire_damage, "FIRE Triple damages Enemy")
	battle = fresh(); battle.enemy_action_counter = 2; battle.apply_triple("ice")
	check(battle.enemy_hp == config.enemy_hp - config.ice_damage and battle.enemy_frozen, "ICE damages and freezes Enemy")
	battle.enemy_action_counter = 1; var hp_before := battle.core_hp; var events := battle.apply_triple("fire")
	check(battle.core_hp == hp_before and not battle.enemy_frozen and events.any(func(event): return event.type == "frozen_skip"), "Frozen Enemy skips next ready attack")
	battle = fresh(); battle.apply_triple("lightning")
	check(battle.enemy_hp == config.enemy_hp - config.lightning_damage, "LIGHTNING Triple damages Enemy")
	battle = fresh(); var counter_before := battle.enemy_action_counter; battle.apply_triple("wind")
	check(battle.enemy_hp == config.enemy_hp - config.wind_damage and battle.enemy_action_counter == counter_before, "WIND offsets one countdown step")
	battle = fresh(); battle.core_hp = config.core_max_hp - 3; battle.apply_triple("life")
	check(battle.core_hp == config.core_max_hp, "LIFE heals without exceeding maximum")
	battle.enemy_action_counter = config.enemy_action_delay_max; battle.apply_triple("life"); check(battle.core_hp == config.core_max_hp, "LIFE remains capped at maximum HP")
	battle = fresh(); battle.apply_triple("shield")
	check(battle.core_shield == config.shield_gain, "SHIELD adds temporary Shield")
	battle.core_shield = 5; battle.enemy_action_counter = 1; hp_before = battle.core_hp; battle.apply_triple("lightning")
	check(battle.core_shield == 0 and battle.core_hp == hp_before - 3, "Enemy damage consumes Shield before Core HP")
	battle = fresh(); hp_before = battle.core_hp; battle.apply_triple("fire"); check(battle.core_hp == hp_before, "Enemy waits after first Triple")
	battle.apply_triple("fire"); check(battle.core_hp == hp_before - config.enemy_attack_damage, "Enemy attacks after configured Triple interval")
	battle = fresh(); battle.core_hp = config.enemy_attack_damage; battle.enemy_action_counter = 1; battle.apply_triple("fire")
	check(battle.core_hp == 0, "Core HP can reach zero from Enemy attack")

	var levels: Array[LevelDefinition] = [load("res://resources/levels/level_1_mixed.tres"), load("res://resources/levels/level_2.tres"), load("res://resources/levels/level_3.tres")]
	var controller := GameController.new(); controller.levels = levels; controller.balance = config; controller.restart()
	var remaining_before := controller.board.remaining_count(); controller.battle.enemy_hp = config.fire_damage
	controller.resolve_triples(["fire","fire","fire"])
	check(controller.state == "won" and controller.board.remaining_count() == remaining_before, "Enemy death triggers immediate Victory without clearing Board")
	controller.restart(); controller.tray.tiles.assign(["fire","ice","lightning","wind","life","shield"])
	var top_id: int = controller.board.available_ids()[0]; controller.select_tile_immediate(top_id)
	check(controller.state == "lost" and controller.tray.is_full(), "full Tray still causes puzzle Lose")
	controller.restart(); controller.battle.core_hp = 1; controller.battle.enemy_action_counter = 1; controller.resolve_triples(["fire","fire","fire"])
	check(controller.state == "lost", "Core death causes Lose")
	controller.restart()
	check(controller.state == "playing" and controller.battle.core_hp == config.core_max_hp and controller.battle.enemy_hp == controller.battle.current_enemy.max_hp and controller.board.remaining_count() == levels[0].tile_count(), "Restart resets Battle and Puzzle")
	controller.free()

	print("\n", "ALL BATTLE TESTS PASSED" if failures == 0 else "%d BATTLE TESTS FAILED" % failures)
	quit(failures)
