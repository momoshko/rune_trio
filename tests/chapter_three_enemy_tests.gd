extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func fresh(id: String, relics: Array[RelicDefinition] = []) -> BattleModel:
	return BattleModel.new(BalanceConfig.new(), EnemyCatalog.by_id(id), relics)

func spell(events: Array[Dictionary]) -> Dictionary:
	for event in events:
		if event.type == "spell_resolved": return event
	return {}

func events_of(events: Array[Dictionary], type_id: String) -> Array:
	return events.filter(func(event): return event.type == type_id)

func _initialize() -> void:
	var ash := fresh("ash_knight")
	ash.apply_triple("fire")
	ash.prepared_attack.countdown = ash.prepared_attack.base_interval + 1
	ash.apply_triple("fire")
	var plus_two := ash.prepared_attack.damage == 9 and ash.prepared_attack.temporary_damage_bonus == 2
	ash.apply_triple("fire")
	ash.apply_triple("fire")
	check(plus_two and ash.prepared_attack.damage == 11 and ash.prepared_attack.temporary_damage_bonus == 4,
		"1 Ash Knight repeat bonus stacks to +4 cap")

	ash = fresh("ash_knight"); ash.apply_triple("fire"); ash.apply_triple("fire")
	ash.prepared_attack.countdown = 1
	var executed := ash.apply_triple("fire")
	var reset_after_hit: bool = events_of(executed, "enemy_attack")[0].incoming == 11 and ash.prepared_attack.damage == 7
	ash.prepared_attack.temporary_damage_bonus = 2
	ash.prepared_attack.countdown = 1; ash.prepared_attack.frozen = true
	var skipped := ash.apply_triple("life")
	check(reset_after_hit and events_of(skipped, "frozen_skip").size() == 1 and ash.prepared_attack.damage == 7,
		"2 Ash Knight bonus resets after executed and Frozen-skipped attack")

	var sentinel := fresh("grave_sentinel")
	sentinel.apply_triple("shield")
	var opened: bool = sentinel.enemy_mechanic_state.armor_open
	var open_fire := spell(sentinel.apply_triple("fire"))
	var closed_fire := spell(sentinel.apply_triple("fire"))
	check(opened and open_fire.hp_damage == 6 and not sentinel.enemy_mechanic_state.armor_open
		and closed_fire.hp_damage == 4, "3 Grave Sentinel opens Armor for exactly one attacking Triple")

	var catalog: RunDefinition = load("res://resources/runs/m4_run.tres")
	sentinel = fresh("grave_sentinel", [catalog.relic_by_id("living_fortress")])
	sentinel.core_shield = 1
	var life := spell(sentinel.apply_triple("life"))
	var remains_open: bool = sentinel.enemy_mechanic_state.armor_open
	var next_attack := spell(sentinel.apply_triple("fire"))
	check(life.resolved_effect.ordinary_damage == 3 and life.hp_damage == 1 and remains_open
		and next_attack.hp_damage == 6 and not sentinel.enemy_mechanic_state.armor_open,
		"4 Defensive Life relic damage opens but does not consume Armor window")

	var acolyte := fresh("eclipse_acolyte")
	acolyte.enemy_hp = 17
	var current_countdown := acolyte.prepared_attack.countdown
	acolyte.apply_triple("fire")
	var transitioned: bool = acolyte.enemy_hp == 11 and acolyte.enemy_mechanic_state.fast_attacks_enabled
	var current_unchanged := acolyte.prepared_attack.countdown == current_countdown - 1 and acolyte.prepared_attack.base_interval == 3
	acolyte.prepared_attack.countdown = 1
	acolyte.apply_triple("life")
	check(transitioned and current_unchanged and acolyte.prepared_attack.base_interval == 2
		and acolyte.prepared_attack.countdown == 2, "5 Eclipse Acolyte speeds only future prepared attacks")

	print("M7C: 5 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
