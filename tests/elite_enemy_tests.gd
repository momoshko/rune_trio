extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func fresh(id: String, relics: Array[RelicDefinition] = []) -> BattleModel:
	return BattleModel.new(BalanceConfig.new(), EnemyCatalog.by_id(id), relics)

func events_of(events: Array[Dictionary], type_id: String) -> Array:
	return events.filter(func(event): return event.type == type_id)

func spell(events: Array[Dictionary]) -> Dictionary:
	for event in events:
		if event.type == "spell_resolved": return event
	return {}

func resolve_attack(battle: BattleModel) -> Array[Dictionary]:
	battle.prepared_attack.countdown = 1
	return battle.advance_enemy_action()

func _initialize() -> void:
	var guard := fresh("stone_guard")
	var first := resolve_attack(guard)
	var second := resolve_attack(guard)
	var third := resolve_attack(guard)
	check(events_of(first, "enemy_attack")[0].incoming == 8
		and events_of(second, "enemy_attack")[0].incoming == 12
		and events_of(third, "enemy_attack")[0].incoming == 8,
		"1 Stone Guardian alternates 8, 12, 8")

	guard = fresh("stone_guard")
	resolve_attack(guard)
	guard.prepared_attack.countdown = 1; guard.prepared_attack.frozen = true
	var frozen_heavy := guard.advance_enemy_action()
	check(events_of(frozen_heavy, "enemy_attack").is_empty() and events_of(frozen_heavy, "frozen_skip").size() == 1
		and guard.prepared_attack.damage == 8 and guard.prepared_attack.sequence == 3,
		"2 Frozen heavy attack is consumed; next attack is 8")

	var beast := fresh("frost_beast")
	var beast_hit := resolve_attack(beast)
	var beast_ok: bool = events_of(beast_hit, "enemy_attack")[0].incoming == 7 and beast.enemy_shield == 6
	beast = fresh("frost_beast"); beast.prepared_attack.countdown = 1; beast.prepared_attack.frozen = true
	var beast_skip := beast.advance_enemy_action()
	check(beast_ok and events_of(beast_skip, "frozen_skip").size() == 1 and beast.enemy_shield == 0,
		"3 Ice Beast gains Shield only after an executed attack")

	var catalog: RunDefinition = load("res://resources/runs/m4_run.tres")
	beast = fresh("frost_beast", [catalog.relic_by_id("crystal_prism")])
	beast.apply_triple("shield"); beast.enemy_shield = 6
	var ice := spell(beast.apply_triple("ice"))
	var ice_ok: bool = beast.enemy_shield == 0 and ice.hp_damage == 6 and ice.shield_damage == 6
	beast = fresh("frost_beast"); beast.enemy_shield = 6
	var lightning := spell(beast.apply_triple("lightning"))
	check(ice_ok and lightning.hp_damage == 5 and beast.enemy_shield == 6,
		"4 Ice breaks Shield before full Spell damage; Lightning bypasses and preserves it")

	var revenant := fresh("storm_revenant")
	revenant.apply_triple("fire")
	var first_countdown := revenant.prepared_attack.countdown
	var repeated := revenant.apply_triple("fire")
	var timeline: Array = events_of(repeated, "timeline")
	check(first_countdown == 2 and timeline.size() == 1 and timeline[0].after == 0
		and events_of(repeated, "enemy_attack").size() == 1 and revenant.prepared_attack.countdown == 3,
		"5 Storm Revenant repeat applies one extra countdown reduction")

	revenant = fresh("storm_revenant")
	revenant.previous_triple_type = "life"
	revenant.prepared_attack.countdown = 1
	var overdue := revenant.apply_triple("life")
	check(events_of(overdue, "enemy_attack").size() == 1 and events_of(overdue, "timeline")[0].after == 0
		and revenant.prepared_attack.sequence == 2 and revenant.prepared_attack.countdown == 3,
		"6 Storm Revenant executes at most one attack without carrying remainder")

	print("M8: 6 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
