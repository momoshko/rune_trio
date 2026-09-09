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
	check(controller.battle.current_enemy.id == "stone_golem" and controller.battle.current_enemy.max_hp == 32
		and controller.battle.enemy_armor == 1 and controller.battle.prepared_attack.damage == 8,
		"Stone Golem spawns with M9A phase 1 stats")
	var events: Array = []; controller.combat_feedback.connect(func(event): events.append(event))
	var hp_before := controller.battle.core_hp
	for index in 3: triple(controller)
	check(controller.battle.core_hp == hp_before - 8 and not events.any(func(event): return event.type == "lock_stack_request"),
		"Stone Golem uses the common prepared attack and never requests a stack lock")
	controller.battle.enemy_hp = 18
	controller.battle.prepared_attack.countdown = 2
	triple(controller, "fire")
	check(controller.battle.current_phase_index == 1 and controller.battle.enemy_armor == 0
		and controller.battle.prepared_attack.damage == 8, "controller combat preserves old attack across phase change")
	controller.restart(); controller.battle.enemy_hp = 1; triple(controller, "fire")
	check(controller.state == "won", "Golem death immediately completes its configured Level")
	var witch := BattleModel.new(config, EnemyCatalog.by_id("frost_witch"))
	witch.prepared_attack.countdown = 1
	var arrow := witch.advance_enemy_action()
	check(arrow.any(func(event): return event.type == "enemy_attack" and event.incoming == 6)
		and witch.prepared_attack.name_key == "M9B_ICE_SPEAR" and witch.prepared_attack.damage == 10
		and witch.prepared_attack.base_interval == 4,
		"Frost Witch uses common Arrow-to-Spear prepared attack sequence")
	var weaver := BattleModel.new(config, EnemyCatalog.by_id("eclipse_weaver"))
	var opening := weaver.apply_triple("fire")
	check(opening.any(func(event): return event.type == "damage" and event.hp_damage == 9)
		and weaver.current_vulnerability_index == 0 and weaver.vulnerability_progress == 1,
		"Eclipse Weaver starts with Fire vulnerability bonus and one shared timeline step")
	controller.free()
	print("\n", "ALL BOSS TESTS PASSED" if failures == 0 else "%d BOSS TESTS FAILED" % failures)
	quit(failures)
