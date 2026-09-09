extends SceneTree

var failures := 0
var catalog: RunDefinition = load("res://resources/runs/m4_run.tres")

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func fresh(ids: Array, armor := 0, shield := 0) -> BattleModel:
	var enemy := EnemyDefinition.new()
	enemy.max_hp = 200; enemy.attack_damage = 0; enemy.attack_interval_triples = 3
	enemy.armor = armor; enemy.shield = shield
	var owned: Array[RelicDefinition] = []
	for id in ids: owned.append(catalog.relic_by_id(id))
	return BattleModel.new(BalanceConfig.new(), enemy, owned)

func cast(battle: BattleModel, rune: String, occupancy := 3) -> Array[Dictionary]:
	return battle.apply_triple(rune, battle.capture_triple_context(rune, occupancy))

func spell(events: Array[Dictionary]) -> Dictionary:
	for event in events:
		if event.type == "spell_resolved": return event
	return {}

func count(events: Array[Dictionary], type_id: String) -> int:
	return events.filter(func(event): return event.type == type_id).size()

func _initialize() -> void:
	var shield := fresh(["empty_buckler", "tempered_flame"])
	var shield_ok: bool = spell(cast(shield, "shield")).shield_gained == 12
	cast(shield, "fire")
	shield_ok = shield_ok and spell(cast(shield, "shield")).shield_gained == 12 and shield.core_shield == 24
	check(shield_ok and spell(cast(shield, "shield")).shield_gained == 0, "1 Shield relics and cap")

	var sequence := fresh(["steam_seal", "cold_spring", "frozen_crown"])
	sequence.prepared_attack.countdown = 2
	cast(sequence, "ice")
	var steam := cast(sequence, "fire")
	var sequence_ok: bool = spell(steam).hp_damage == 10 and count(steam, "frozen_skip") == 1
	cast(sequence, "wind")
	sequence.core_hp = 30
	var ice := spell(cast(sequence, "ice"))
	sequence_ok = sequence_ok and ice.healing == 7 and ice.shield_gained == 4 and ice.hp_damage == 3
	var again := spell(cast(sequence, "ice"))
	check(sequence_ok and again.healing == 0 and again.shield_gained == 0, "2 Sequences: Steam preserves Frozen; Spring + Crown")

	var life := fresh(["living_fortress", "blood_flower"], 2, 3)
	life.core_hp = 20; life.core_shield = 1
	var life_events := cast(life, "life")
	var life_spell := spell(life_events)
	var life_ok: bool = life_spell.hp_damage == 3 and life_spell.shield_damage == 3 and life_spell.healing == 8
	life.core_hp = 21; life.core_shield = 0
	var no_bonus := spell(cast(life, "life"))
	check(life_ok and count(life_events, "damage") == 1 and count(life_events, "timeline") == 1
		and no_bonus.hp_damage == 0 and no_bonus.healing == 8, "3 Life bonuses aggregate before one Armor application; pre-heal threshold")

	var first := fresh(["dawn_charm", "mirror_charm"])
	first.core_hp = 10
	var opening := spell(cast(first, "fire"))
	var first_ok: bool = opening.healing == 6 and opening.shield_gained == 10
	first.core_hp = 1
	var second := spell(cast(first, "wind"))
	first_ok = first_ok and second.healing == 0 and second.shield_gained == 0
	first.reset(first.current_enemy)
	cast(first, "fire") # First Triple at full HP consumes Mirror's opportunity.
	first.core_hp = 10
	check(first_ok and spell(cast(first, "fire")).healing == 0, "4 First Triple: Dawn/Mirror; no late activation; encounter reset")

	var golem := fresh(["golem_heart"], 2)
	var occupancy_ok: bool = spell(cast(golem, "shield", 5)).hp_damage == 3
	occupancy_ok = occupancy_ok and spell(cast(golem, "shield", 6)).hp_damage == 3
	occupancy_ok = occupancy_ok and spell(cast(golem, "shield", 7)).hp_damage == 0
	var focus := fresh(["fragile_focus"], 20, 30)
	occupancy_ok = occupancy_ok and spell(cast(focus, "lightning", 6)).hp_damage == 9 and focus.enemy_shield == 30
	occupancy_ok = occupancy_ok and spell(cast(focus, "lightning", 5)).hp_damage == 5
	check(occupancy_ok and spell(cast(focus, "life", 6)).hp_damage == 0, "5 Pre-removal occupancy boundaries and attack-only Focus")

	var lightning := fresh(["storm_needle", "storm_front"], 20, 30)
	cast(lightning, "wind")
	var lightning_events := cast(lightning, "lightning")
	check(spell(lightning_events).hp_damage == 11 and lightning.enemy_shield == 30
		and count(lightning_events, "damage") == 1, "6 Needle + Storm Front: aggregate direct damage")

	var echo := fresh(["echo_seal", "brazier_heart"])
	for rune in ["life", "shield", "ice"]: cast(echo, rune)
	var echoed_fire := cast(echo, "fire")
	var echo_ok: bool = spell(echoed_fire).hp_damage == 12 and count(echoed_fire, "timeline") == 1
	echo_ok = echo_ok and count(echoed_fire, "spell_resolved") == 1 and echo.relic_state.total_triples == 4
	var echo_life := fresh(["echo_seal"])
	for index in 3: cast(echo_life, "wind")
	echo_life.core_hp = 20
	echo_ok = echo_ok and spell(cast(echo_life, "life")).healing == 12
	# No replayed freeze or delay: fourth Ice/Wind still has one original effect.
	var echo_control := fresh(["echo_seal"])
	for index in 3: cast(echo_control, "wind")
	echo_control.prepared_attack.countdown = 2
	var echoed_ice := cast(echo_control, "ice")
	echo_ok = echo_ok and spell(echoed_ice).hp_damage == 4 and count(echoed_ice, "status") == 1 and count(echoed_ice, "timeline") == 1
	check(echo_ok, "7 Echo: half BASE only, numeric rounding, no recursive effects")

	var trinity := fresh(["trinity_mark", "storm_needle", "storm_front"], 2, 5)
	cast(trinity, "life"); cast(trinity, "wind")
	trinity.enemy_shield = 5
	var composite := cast(trinity, "lightning")
	var channels: Array = composite.filter(func(event): return event.type == "damage")
	var tri_ok: bool = channels.size() == 2 and channels[0].direct and channels[0].hp_damage == 11
	tri_ok = tri_ok and not channels[1].direct and channels[1].incoming == 4 and channels[1].armor_blocked == 2
	tri_ok = tri_ok and trinity.enemy_shield == 3 and spell(composite).shield_gained == 4
	for index in 2: cast(trinity, "lightning")
	var same := spell(cast(trinity, "lightning"))
	check(tri_ok and count(composite, "timeline") == 1 and same.shield_gained == 0,
		"8 Triunity: separate direct/ordinary channels; same-type third does not trigger")
	print("M6: 8 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
