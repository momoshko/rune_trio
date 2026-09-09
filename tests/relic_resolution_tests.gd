extends SceneTree

var failures := 0
var catalog: RunDefinition = load("res://resources/runs/m4_run.tres")

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func fresh(ids: Array = [], armor := 0, shield := 0) -> BattleModel:
	var enemy := EnemyDefinition.new()
	enemy.max_hp = 200; enemy.attack_damage = 0; enemy.attack_interval_triples = 3
	enemy.armor = armor; enemy.shield = shield
	var relics: Array[RelicDefinition] = []
	for id in ids: relics.append(catalog.relic_by_id(id))
	return BattleModel.new(BalanceConfig.new(), enemy, relics)

func spell(events: Array[Dictionary]) -> Dictionary:
	for event in events:
		if event.type == "spell_resolved": return event
	return {}

func damage(battle: BattleModel, type_id: String) -> int:
	return spell(battle.apply_triple(type_id)).hp_damage

func count(events: Array[Dictionary], type_id: String) -> int:
	return events.filter(func(event): return event.type == type_id).size()

func _initialize() -> void:
	var plain := fresh()
	var base := plain.apply_triple("fire")
	check(spell(base).hp_damage == 6 and spell(base).activated_relics.is_empty()
		and count(base, "timeline") == 1 and plain.previous_triple_type == "fire", "1 No relics: M2 baseline")

	var heart := fresh(["brazier_heart"], 2)
	var context := heart.capture_triple_context("fire", 7)
	var first := spell(heart.apply_triple("fire", context))
	var heart_ok: bool = first.hp_damage == 7 and first.base_effect.damage == 6 and first.resolved_effect.damage == 9
	heart_ok = heart_ok and damage(heart, "fire") == 4 and heart.relic_state.activation_counts.brazier_heart == 1
	heart_ok = heart_ok and context.is_read_only() and context.activation_counts.is_read_only()
	heart_ok = heart_ok and context.activation_counts.is_empty() and context.row_occupancy == 7 and context.previous_triple_type == ""
	heart.reset(heart.current_enemy)
	check(heart_ok and heart.relic_state.total_triples == 0 and damage(heart, "fire") == 7, "2 Heart once, before Armor; immutable context; encounter reset")

	var crown := fresh(["ember_crown"])
	var hits: Array[int] = []
	for type_id in ["fire", "fire", "fire", "fire", "ice", "fire"]: hits.append(damage(crown, type_id))
	check(hits == [6, 10, 6, 10, 3, 6] and crown.relic_state.activation_counts.ember_crown == 2, "3 Crown even streak and interruption")

	var prism := fresh(["crystal_prism"])
	var prism_ok := damage(prism, "ice") == 3
	prism.apply_triple("shield")
	var ice := spell(prism.apply_triple("ice"))
	check(prism_ok and ice.hp_damage == 6 and ice.context.previous_triple_type == "shield"
		and prism.previous_triple_type == "ice", "4 Prism reads previous original Shield")

	var needle := fresh(["storm_needle"], 20, 30)
	var needle_ok := damage(needle, "lightning") == 5
	needle.apply_triple("fire")
	needle_ok = needle_ok and damage(needle, "lightning") == 7 and damage(needle, "lightning") == 5
	check(needle_ok and needle.enemy_shield == 30, "5 Needle: previous other, direct damage, no first/consecutive bonus")

	var compass := fresh(["wind_compass"])
	compass.apply_triple("lightning")
	var wind := compass.apply_triple("wind")
	var compass_ok: bool = compass.prepared_attack.countdown == 3 and spell(wind).resolved_effect.timeline_modifier == 2
	compass.apply_triple("lightning")
	compass.prepared_attack.countdown = compass.prepared_attack.base_interval + 1
	var capped := compass.apply_triple("wind")
	check(compass_ok and compass.prepared_attack.countdown == 4 and count(wind, "timeline") == 1
		and count(capped, "timeline") == 1 and compass.relic_state.total_triples == 4, "6 Compass: one timeline step and interval+1 cap")

	var cup := fresh(["overflow_chalice"])
	cup.core_hp = 37
	var life := spell(cup.apply_triple("life"))
	var cup_ok: bool = life.healing == 3 and life.shield_gained == 5 and cup.core_hp == 40
	var full := spell(cup.apply_triple("life"))
	cup.core_shield = 22
	var capped_life := cup.apply_triple("life")
	check(cup_ok and full.healing == 0 and full.shield_gained == 8 and cup.core_shield == 24
		and count(capped_life, "spell_resolved") == 1 and count(capped_life, "timeline") == 1
		and cup.relic_state.total_triples == 3, "7 Cup: overflow, Shield cap, no extra Spell or Triple")
	print("M5: 7 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
