extends SceneTree

# Fixtures specify defenses/attack timing. Spell values always come from BattleModel/config.
class ReactionProbe extends BattleModel:
	var calls := 0
	func _apply_enemy_reactions(_context: Dictionary, events: Array[Dictionary]) -> void:
		calls += 1
		events.append({"type":"reaction_probe", "countdown":prepared_attack.countdown})

var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)

func fresh(interval := 3, armor := 0, shield := 0) -> BattleModel:
	var enemy := EnemyDefinition.new()
	enemy.max_hp = 200; enemy.attack_damage = 8; enemy.attack_interval_triples = interval
	enemy.armor = armor; enemy.shield = shield
	return BattleModel.new(BalanceConfig.new(), enemy)

func event_of(events: Array[Dictionary], type_id: String) -> Dictionary:
	for event in events:
		if event.type == type_id: return event
	check(false, "missing event " + type_id)
	return {}

func count_events(events: Array[Dictionary], type_id: String) -> int:
	return events.filter(func(event): return event.type == type_id).size()

func fixture(two_tiles := true) -> GameController:
	var level := LevelDefinition.new()
	var stack := StackDefinition.new(); stack.tile_types.assign(["fire", "life"] if two_tiles else ["fire"])
	level.stacks.assign([stack]); level.encounter_enemy_ids.assign(["training_dummy"])
	var game := GameController.new(); game.level = level; game.balance = BalanceConfig.new(); game.restart()
	return game

func _init() -> void:
	var battle := fresh()
	check(battle.config.core_max_hp == 40 and battle.config.shield_max == 24 and battle.config.tray_capacity == 7, "final Core/Shield/Row limits")
	check(battle.config.fire_damage == 6 and battle.config.ice_damage == 3 and battle.config.lightning_damage == 5 and battle.config.wind_damage == 3 and battle.config.life_heal == 8 and battle.config.shield_gain == 8, "single config has the six specified base values")
	var events := battle.apply_triple("fire")
	check(battle.enemy_hp == 200 - battle.config.fire_damage, "Fire: base damage without defenses")
	check(battle.prepared_attack.countdown == 2, "Fire advances timeline exactly once")
	battle = fresh(3, 2); events = battle.apply_triple("fire")
	check(event_of(events, "damage").hp_damage == 4 and battle.enemy_hp == 196, "Fire: Armor reduces one aggregated effect")
	battle = fresh(3, 2, 3); events = battle.apply_triple("fire")
	var damage := event_of(events, "damage")
	check(battle.enemy_shield == 0 and battle.enemy_hp == 199, "Fire: Armor then Shield then HP overflow")
	check(damage.incoming == battle.config.fire_damage and damage.armor_blocked == 2 and damage.shield_absorbed == 3 and damage.hp_damage == 1 and damage.value == 1, "damage event reports actual mitigation and HP damage")
	var spell := event_of(events, "spell_resolved")
	check(spell.base_effect.damage == battle.config.fire_damage and spell.hp_damage == 1 and spell.shield_damage == 3, "spell event keeps base effect and actual results distinct")
	battle = fresh(3, 99); events = battle.apply_triple("fire")
	check(battle.enemy_hp == 200 and event_of(events, "damage").hp_damage == 0, "high Armor never produces negative damage")
	battle = fresh(3, 0, 2); battle.apply_triple("fire")
	check(battle.enemy_shield == 0 and battle.enemy_hp == 200 - (battle.config.fire_damage - 2), "Enemy Shield cannot underflow")
	battle = fresh(3, 10); events = battle.apply_triple("lightning")
	check(battle.enemy_hp == 200 - battle.config.lightning_damage and event_of(events, "damage").armor_blocked == 0, "Lightning bypasses Armor")
	battle = fresh(3, 10, 50); events = battle.apply_triple("lightning")
	damage = event_of(events, "damage")
	check(battle.enemy_hp == 200 - battle.config.lightning_damage and battle.enemy_shield == 50, "Lightning bypasses and preserves Enemy Shield")
	check(damage.direct and damage.hp_damage == battle.config.lightning_damage and damage.shield_absorbed == 0, "Lightning event reports direct HP damage only")
	battle = fresh(); battle.core_hp = 20; events = battle.apply_triple("life")
	check(battle.core_hp == 20 + battle.config.life_heal and battle.enemy_hp == 200, "Life heals and does not damage enemy")
	check(event_of(events, "heal").value == battle.config.life_heal and battle.prepared_attack.countdown == 2, "Life actual healing event; timeline advances")
	battle = fresh(); battle.core_hp = 39; events = battle.apply_triple("life")
	check(battle.core_hp == 40 and event_of(events, "heal").value == 1, "Life caps at maximum and reports actual healing")
	battle = fresh(); events = battle.apply_triple("life")
	check(battle.core_hp == 40 and event_of(events, "heal").value == 0 and battle.prepared_attack.countdown == 2, "full-HP Life still advances timeline")
	battle = fresh(); events = battle.apply_triple("shield")
	check(battle.core_shield == battle.config.shield_gain and battle.enemy_hp == 200 and battle.prepared_attack.countdown == 2, "Shield grants base Shield, no damage, one timeline tick")
	battle = fresh(); battle.core_shield = 23; events = battle.apply_triple("shield")
	check(battle.core_shield == 24 and event_of(events, "shield").value == 1, "Shield caps at 24 with actual gain")
	battle = fresh(); battle.core_shield = 24; events = battle.apply_triple("shield")
	check(battle.prepared_attack.countdown == 2 and event_of(events, "shield").value == 0, "capped Shield still advances timeline")
	battle = fresh(1); battle.core_shield = 5; events = battle.apply_triple("fire")
	var attack := event_of(events, "enemy_attack")
	check(battle.core_shield == 0 and battle.core_hp == 37, "enemy attack consumes Core Shield before HP")
	check(attack.shield_absorbed == 5 and attack.hp_damage == 3 and attack.value == 3, "attack reports separate actual Shield and HP losses")
	battle = fresh(1); battle.core_shield = 20; events = battle.apply_triple("fire")
	check(battle.core_hp == 40 and battle.core_shield == 12 and event_of(events, "enemy_attack").hp_damage == 0, "fully absorbed attack causes zero HP damage")
	battle = fresh(1); battle.core_hp = 2; events = battle.apply_triple("fire")
	check(battle.core_hp == 0 and event_of(events, "enemy_attack").hp_damage == 2 and battle.combat_outcome() == "CORE_DESTROYED", "Core HP clamps to zero; event excludes overkill")
	check(event_of(events, "defeat").outcome == "CORE_DESTROYED", "Core death is an explicit combat result")
	battle = fresh(); events = battle.apply_triple("ice")
	check(battle.enemy_hp == 200 - battle.config.ice_damage and not battle.enemy_frozen and battle.enemy_action_counter == 2, "Ice at countdown 3: damage only")
	battle = fresh(); battle.enemy_action_counter = 2; events = battle.apply_triple("ice")
	check(battle.enemy_frozen and battle.enemy_action_counter == 1 and count_events(events, "frozen_skip") == 0, "Ice at countdown 2 freezes current prepared attack")
	var frozen_attack := battle.prepared_attack
	events = battle.apply_triple("ice")
	check(battle.core_hp == 40 and count_events(events, "frozen_skip") == 1 and count_events(events, "enemy_attack") == 0, "second Ice consumes only one frozen attack")
	check(count_events(events, "status") == 0 and event_of(events, "spell_resolved").control == "already_frozen", "repeat Ice does not add another freeze")
	check(not battle.enemy_frozen and battle.enemy_action_counter == 3 and battle.prepared_attack.sequence == frozen_attack.sequence + 1, "skip clears Frozen and prepares next normal interval")
	for i in 3: events = battle.apply_triple("life")
	check(count_events(events, "enemy_attack") == 1 and battle.core_hp == 32, "next attack is not frozen again")
	battle = fresh(); battle.enemy_action_counter = 1; events = battle.apply_triple("ice")
	check(count_events(events, "status") == 1 and count_events(events, "frozen_skip") == 1 and battle.core_hp == 40 and not battle.enemy_frozen, "Ice at countdown 1 freezes and skips immediately")
	for countdown in [1, 3]:
		battle = fresh(); battle.enemy_action_counter = countdown
		events = battle.apply_triple("wind")
		check(battle.enemy_action_counter == countdown and count_events(events, "enemy_attack") == 0 and battle.enemy_hp == 200 - battle.config.wind_damage, "Wind preserves countdown %d before attack check" % countdown)
	battle = fresh()
	for i in 20: battle.apply_triple("wind")
	check(battle.enemy_action_counter == 3 and battle.core_hp == 40 and battle.prepared_attack.sequence == 1, "repeated Wind neither grows countdown nor executes attacks")
	check(battle.delay_prepared_attack(100) == battle.prepared_attack.base_interval + 1, "delay cap belongs to current prepared attack interval + 1")
	battle.apply_triple("wind")
	check(battle.enemy_action_counter == 4, "Wind also respects upper-bound countdown")
	battle = fresh(5); check(battle.delay_prepared_attack(100) == 6, "delay cap is per attack, not legacy global max 4")
	battle = fresh(); battle.enemy_action_counter = -10; events = battle.apply_triple("life")
	check(count_events(events, "enemy_attack") == 1 and count_events(events, "timeline") == 1, "one source Triple performs at most one attack")
	check(battle.enemy_action_counter == 3 and battle.prepared_attack.sequence == 2, "negative countdown never carries to next attack")
	battle = fresh(1); battle.enemy_hp = 1; events = battle.apply_triple("fire")
	check(battle.combat_outcome() == "victory" and battle.core_hp == 40 and count_events(events, "timeline") == 0 and count_events(events, "enemy_attack") == 0, "lethal Spell stops timeline and attack")
	check(event_of(events, "damage").hp_damage == 1, "damage event caps overkill at actual Enemy HP")
	check(battle.apply_triple("life").is_empty(), "terminal battle cannot resolve another source Triple")
	battle = fresh(); var supplemental: Array[Dictionary] = []
	battle.damage_enemy(2, "probe", supplemental)
	check(battle.enemy_action_counter == 3 and battle.previous_triple_type.is_empty(), "numeric damage helper does not create source Triple/timeline tick")
	var before := battle.capture_triple_context("fire", 7)
	events = battle.apply_triple("fire", before)
	check(battle.apply_triple("fire", before).is_empty() and battle.enemy_action_counter == 2, "same source context cannot be resolved twice")
	var probe := ReactionProbe.new(BalanceConfig.new())
	events = probe.apply_triple("life")
	check(events.find(event_of(events, "spell_resolved")) < events.find(event_of(events, "reaction_probe")) and events.find(event_of(events, "reaction_probe")) < events.find(event_of(events, "timeline")), "extension point is after Spell and before timeline")
	probe.enemy_hp = 1; var previous_calls := probe.calls; probe.apply_triple("fire")
	check(probe.calls == previous_calls, "lethal Spell skips reaction extension point")
	var game := fixture()
	game.tray.tiles.assign(["fire", "fire", "ice", "ice", "wind", "wind"])
	game.battle.apply_triple("wind")
	game.battle.core_hp = 27; game.battle.core_shield = 4; game.battle.enemy_hp = 50
	game.battle.enemy_shield = 3; game.battle.enemy_armor = 2; game.battle.enemy_action_counter = 2; game.battle.enemy_frozen = true
	var row_at_effect: Array[int] = []
	game.triple_resolved.connect(func(_type): row_at_effect.append(game.tray.tiles.size()))
	game.select_tile_immediate(0)
	var context := game.battle.last_triple_context
	check(context.is_read_only() and context.triple_type == "fire" and context.previous_triple_type == "wind", "immutable context records current/previous source Triple")
	check(context.core_hp == 27 and context.core_shield == 4 and context.enemy_hp == 50 and context.enemy_shield == 3 and context.enemy_armor == 2, "context captures pre-effect HP and defenses")
	check(context.row_occupancy == 7 and context.attack_countdown == 2 and context.attack_frozen, "context captures Row and attack BEFORE removal/effects")
	check(row_at_effect == [4] and game.tray.tiles.size() == 4 and game.state == "playing", "seventh matching Rune removes Triple BEFORE effects; no false ROW_FULL")
	game.battle.core_hp = 1; game.battle.enemy_action_counter = 1; game.tray.reset()
	check(context.core_hp == 27 and context.row_occupancy == 7 and context.attack_countdown == 2, "snapshot is independent of later mutable state")
	game.free()
	game = fixture(); var original_countdown := game.battle.enemy_action_counter; game.select_tile_immediate(0)
	check(game.battle.enemy_action_counter == original_countdown and game.battle.previous_triple_type.is_empty(), "single Rune selection does NOT advance combat time")
	game.free()
	game = fixture(false); game.tray.tiles.assign(["fire", "fire"]); game.battle.enemy_hp = 1; game.battle.enemy_action_counter = 1
	game.select_tile_immediate(0)
	check(game.state == "won" and game.board.is_empty() and game.battle.core_hp == 40, "last Board Rune kills enemy: Victory beats Board Exhausted")
	game.free()
	game = fixture(false); game.select_tile_immediate(0)
	check(game.state == "exhausted", "enemy survives empty Board: BOARD_EXHAUSTED")
	game.free()
	game = fixture(false); game.tray.tiles.assign(["ice", "ice", "wind", "wind", "shield", "shield"]); game.select_tile_immediate(0)
	check(game.state == "lost" and game.tray.tiles.size() == 7, "seven unmatched Rune: ROW_FULL beats simultaneous empty Board")
	game.free()
	battle = fresh(); battle.core_hp = 0
	check(battle.action_outcome(7, 7, false) == "CORE_DESTROYED", "Core death beats Row Full and Board Exhausted")
	battle.enemy_hp = 0
	check(battle.action_outcome(7, 7, false) == "victory", "Enemy death has highest result priority")
	battle = fresh(); check(battle.action_outcome(0, 7, false) == "BOARD_EXHAUSTED", "no available Rune ends surviving battle")
	var row := TrayModel.new(7); row.tiles.assign(["fire", "fire", "ice", "ice", "wind", "wind"])
	var added := row.add_tile("fire")
	check(added.removed.size() == 3 and row.tiles.size() == 4 and not row.is_full(), "standalone Tray API preserves auto-Triple before overflow")
	for path in ["training_dummy", "slime", "brute", "wisp", "stone_guard", "stone_golem", "frost_beast", "frost_witch"]:
		var enemy := EnemyCatalog.by_id(path)
		check(enemy != null and enemy.armor == 0 and enemy.shield == 0, "legacy defenses default to zero: " + path)
	for path in ["stone_guard", "stone_golem", "frost_beast", "frost_witch"]:
		battle = BattleModel.new(BalanceConfig.new(), EnemyCatalog.by_id(path))
		battle.enemy_action_counter = 1; events = battle.apply_triple("wind")
		check(battle.enemy_action_counter == 1 and battle.prepared_attack.sequence == 1, "Wind uses unified prepared timeline for " + path)
		events = battle.apply_triple("ice")
		check(count_events(events, "frozen_skip") == 1 and count_events(events, "lock_stack_request") == 0 and battle.core_hp == 40 and battle.prepared_attack.sequence == 2, "Ice consumes existing prepared action for " + path)
	battle = fresh(3, 2, 5); var hud := battle.hud_data()
	check(hud.core_hp == 40 and hud.core_max_hp == 40 and hud.core_shield == 0 and hud.core_max_shield == 24 and hud.enemy_armor == 2 and hud.enemy_shield == 5 and hud.attack.damage == 8 and hud.attack.countdown == 3 and not hud.attack.frozen, "HUD exposes all combat values without UI calculations")
	game = GameController.new(); game.balance = BalanceConfig.new()
	var run := RunController.new(); run.definition = load("res://resources/runs/m1_run.tres"); run.bind_game(game); run.new_run()
	game.battle.core_hp = 28; game.battle.core_shield = 5; game.battle.enemy_action_counter = 1
	game.resolve_triples(["fire", "fire", "fire"])
	var damaged_hp := game.battle.core_hp
	check(damaged_hp < 28 and game.battle.core_shield == 0, "M1 battle receives actual new-model HP/Shield damage")
	game.resolve_triples(["shield", "shield", "shield"])
	game.battle.enemy_hp = 1; game.resolve_triples(["fire", "fire", "fire"]); game.finish_selection()
	check(run.run.status == RunState.Status.BETWEEN_ENCOUNTERS and run.run.boundary_hp == damaged_hp, "M1 receives real post-combat HP at victory boundary")
	run.continue_run()
	check(game.battle.core_hp == damaged_hp and game.battle.core_shield == 0, "M1 carries actual HP and resets new-model Core Shield")
	run.free(); game.free()
	print("M2 RUNE RULES: %d checks, %d failures" % [checks, failures])
	quit(failures)
