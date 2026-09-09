extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func fresh(id: String) -> BattleModel:
	return BattleModel.new(BalanceConfig.new(), EnemyCatalog.by_id(id))

func spell(events: Array[Dictionary]) -> Dictionary:
	for event in events:
		if event.type == "spell_resolved": return event
	return {}

func enemy_heals(events: Array[Dictionary]) -> Array:
	return events.filter(func(event): return event.type == "heal" and event.target == "enemy")

func count(events: Array[Dictionary], type_id: String) -> int:
	return events.filter(func(event): return event.type == type_id).size()

func _initialize() -> void:
	var slime := fresh("moss_slime")
	var stats_ok := slime.enemy_hp == 14 and slime.enemy_armor == 0 and slime.enemy_shield == 0
	stats_ok = stats_ok and slime.prepared_attack.damage == 4 and slime.prepared_attack.base_interval == 3
	slime.enemy_hp = 8; slime.prepared_attack.countdown = 1
	var attack := slime.apply_triple("life")
	var healed: bool = stats_ok and slime.core_hp == 36 and slime.enemy_hp == 11 and enemy_heals(attack)[0].value == 3
	healed = healed and attack.find(enemy_heals(attack)[0]) > attack.find(attack.filter(func(event): return event.type == "enemy_attack")[0])
	slime.enemy_hp = 13; slime.prepared_attack.countdown = 1
	var cap := slime.apply_triple("life")
	check(healed and slime.enemy_hp == 14 and enemy_heals(cap)[0].value == 1
		and slime.current_enemy.max_hp == 14 and count(attack, "enemy_attack") == 1, "1 Slime heals after HP damage, capped at resource max HP")

	slime = fresh("moss_slime")
	slime.enemy_hp = 8; slime.core_shield = 4; slime.prepared_attack.countdown = 1
	var absorbed := slime.apply_triple("life")
	var protected := slime.core_hp == 40 and slime.enemy_hp == 8 and enemy_heals(absorbed).is_empty()
	slime.prepared_attack.countdown = 1; slime.prepared_attack.frozen = true
	var frozen := slime.apply_triple("life")
	protected = protected and slime.enemy_hp == 8 and enemy_heals(frozen).is_empty() and count(frozen, "frozen_skip") == 1
	slime.enemy_hp = 5; slime.prepared_attack.countdown = 1
	var killed := slime.apply_triple("fire")
	check(protected and slime.combat_outcome() == "victory" and enemy_heals(killed).is_empty()
		and count(killed, "enemy_attack") == 0, "2 Slime: absorbed, Frozen, and pre-attack death never heal")

	var wisp := fresh("cave_wisp")
	var wisp_ok := wisp.enemy_hp == 12 and wisp.prepared_attack.damage == 3 and wisp.prepared_attack.base_interval == 1
	var ice := wisp.apply_triple("ice")
	wisp_ok = wisp_ok and spell(ice).hp_damage == 6 and count(ice, "damage") == 1 and count(ice, "frozen_skip") == 1
	wisp = fresh("cave_wisp")
	check(wisp_ok and spell(wisp.apply_triple("fire")).hp_damage == 6, "3 Wisp: one Ice vulnerability bonus; other Runes remain normal")

	var brute := fresh("stone_brute")
	var brute_ok := brute.enemy_hp == 18 and brute.enemy_armor == 2 and brute.prepared_attack.damage == 6 and brute.prepared_attack.base_interval == 3
	var fire := spell(brute.apply_triple("fire"))
	var lightning := spell(brute.apply_triple("lightning"))
	check(brute_ok and fire.hp_damage == 4 and lightning.hp_damage == 5, "4 Brute: Armor 2 reduces Fire; Lightning bypasses Armor")

	var catalog: RunDefinition = load("res://resources/runs/m4_run.tres")
	var enemy := EnemyCatalog.by_id("cave_wisp").duplicate(true) as EnemyDefinition
	enemy.armor = 2; enemy.shield = 1 # Test aggregation through defenses without changing content.
	var synergy := BattleModel.new(BalanceConfig.new(), enemy, [catalog.relic_by_id("crystal_prism")])
	synergy.apply_triple("shield")
	var combined := synergy.apply_triple("ice")
	var combined_spell := spell(combined)
	check(combined_spell.resolved_effect.ordinary_damage == 9 and combined_spell.hp_damage == 6
		and combined_spell.shield_damage == 1 and count(combined, "damage") == 1
		and count(combined, "timeline") == 1 and synergy.relic_state.activation_counts.crystal_prism == 1,
		"5 Prism + Wisp: bonuses combine before one Armor pass and one timeline step")
	print("M7A: 5 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
