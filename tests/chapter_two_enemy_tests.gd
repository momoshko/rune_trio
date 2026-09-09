extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func fresh(id: String) -> BattleModel:
	return BattleModel.new(BalanceConfig.new(), EnemyCatalog.by_id(id))

func events_of(events: Array[Dictionary], type_id: String, target := "") -> Array:
	return events.filter(func(event): return event.type == type_id and (target.is_empty() or event.get("target", "") == target))

func _initialize() -> void:
	var shell := fresh("crystal_shell")
	var stats := shell.enemy_hp == 20 and shell.enemy_shield == 8 and shell.current_enemy.shield_max == 8
	shell.enemy_shield = 0; shell.prepared_attack.countdown = 1
	var hit := shell.apply_triple("life")
	var restore_ok := shell.enemy_shield == 4 and shell.core_hp == 34
	restore_ok = restore_ok and hit.find(events_of(hit, "shield", "enemy")[0]) > hit.find(events_of(hit, "enemy_attack")[0])
	shell.enemy_shield = 7; shell.core_shield = 8; shell.prepared_attack.countdown = 1
	var capped := shell.apply_triple("life")
	check(stats and restore_ok and shell.enemy_shield == 8 and events_of(capped, "shield", "enemy")[0].value == 1
		and events_of(capped, "enemy_attack")[0].hp_damage == 0 and events_of(capped, "timeline").size() == 1,
		"1 Shell restores after executed/absorbed attack, capped at 8")

	shell = fresh("crystal_shell")
	shell.enemy_shield = 0; shell.prepared_attack.countdown = 1; shell.prepared_attack.frozen = true
	var frozen := shell.apply_triple("life")
	var skip_ok := shell.enemy_shield == 0 and events_of(frozen, "frozen_skip").size() == 1
	shell.enemy_hp = 5; shell.prepared_attack.countdown = 1
	var dead := shell.apply_triple("fire")
	check(skip_ok and events_of(frozen, "shield", "enemy").is_empty() and shell.enemy_hp == 0
		and events_of(dead, "shield", "enemy").is_empty(), "2 Shell does not restore on Frozen skip or death")

	var seer := fresh("ice_seer")
	seer.apply_triple("fire")
	var repeat := seer.apply_triple("fire")
	var repeat_ok := seer.enemy_hp == 10 and seer.enemy_shield == 3
	repeat_ok = repeat_ok and repeat.find(events_of(repeat, "shield", "enemy")[0]) > repeat.find(events_of(repeat, "spell_resolved")[0])
	seer.apply_triple("ice")
	repeat_ok = repeat_ok and seer.enemy_shield == 0
	seer.apply_triple("life"); seer.apply_triple("life"); seer.apply_triple("life"); seer.apply_triple("life")
	repeat_ok = repeat_ok and seer.enemy_shield == 6
	seer = fresh("ice_seer"); seer.apply_triple("fire"); seer.enemy_hp = 6
	var killing := seer.apply_triple("fire")
	check(repeat_ok and seer.enemy_hp == 0 and seer.enemy_shield == 0 and events_of(killing, "shield", "enemy").is_empty(),
		"3 Seer reacts after repeat, not alternate/lethal Spell; cap 6")

	var leech := fresh("snow_leech")
	leech.prepared_attack.countdown = 1
	var bare := leech.apply_triple("life")
	var leech_ok: bool = events_of(bare, "enemy_attack")[0].incoming == 8 and leech.core_hp == 32
	leech = fresh("snow_leech"); leech.core_shield = 1; leech.prepared_attack.countdown = 1
	var guarded := leech.apply_triple("life")
	leech_ok = leech_ok and events_of(guarded, "enemy_attack")[0].incoming == 6 and leech.core_hp == 35
	leech = fresh("snow_leech"); leech.prepared_attack.countdown = 1
	leech.apply_triple("shield")
	leech_ok = leech_ok and leech.core_hp == 40 and leech.core_shield == 2 and leech.prepared_attack.damage == 6
	leech.core_shield = 0; leech.prepared_attack.countdown = 1; leech.prepared_attack.frozen = true
	check(leech_ok and events_of(leech.apply_triple("life"), "enemy_attack").is_empty(), "4 Leech uses live pre-attack Shield (0, 1, current Spell, Frozen)")

	var catalog: RunDefinition = load("res://resources/runs/m4_run.tres")
	var synergy := BattleModel.new(BalanceConfig.new(), EnemyCatalog.by_id("ice_seer"), [catalog.relic_by_id("ember_crown")])
	synergy.apply_triple("fire")
	var boosted := synergy.apply_triple("fire")
	check(synergy.enemy_hp == 6 and synergy.enemy_shield == 3
		and events_of(boosted, "spell_resolved")[0].hp_damage == 10 and events_of(boosted, "timeline").size() == 1,
		"5 Crown damage resolves before Seer reaction")
	print("M7B: 5 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
