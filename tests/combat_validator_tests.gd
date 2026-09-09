extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func layout(columns: Array) -> LevelDefinition:
	var level := LevelDefinition.new()
	for index in columns.size():
		var stack := StackDefinition.new()
		stack.stack_id = 10 + index * 7 # Actual IDs, deliberately not array indices.
		stack.tile_types.assign(columns[index])
		level.stacks.append(stack)
	return level

func enemy(hp: int, damage := 0, interval := 1) -> EnemyDefinition:
	var value := EnemyDefinition.new()
	value.max_hp = hp; value.attack_damage = damage; value.attack_interval_triples = interval
	return value

func _initialize() -> void:
	var balance := BalanceConfig.new()
	var fire := layout([["fire", "fire", "fire", "life"]])
	var simple := CombatValidator.solve(fire, enemy(6), balance)
	check(simple.status == CombatValidator.SOLVABLE and simple.replay_verified
		and simple.witness.stack_ids == PackedInt32Array([10, 10, 10])
		and simple.witness.triples == ["fire"] and simple.witness.max_row_occupancy == 3,
		"1 Simple Fire victory before board clear")

	var small := layout([["fire"], ["fire"], ["fire"]])
	var impossible := CombatValidator.solve(small, enemy(7), balance)
	# 2^3 remaining-stack states, not 16 permutation prefixes: proves dedup.
	check(impossible.status == CombatValidator.UNSOLVABLE and impossible.explored_states == 8,
		"2 Exhaustive insufficient damage + canonical dedup")

	var limited := CombatValidator.solve(fire, enemy(6), balance, {"max_states":1})
	var depth := CombatValidator.solve(fire, enemy(6), balance, {"max_depth":1})
	var special := enemy(6); special.tags.assign(["boss"])
	check(limited.status == CombatValidator.UNKNOWN and depth.status == CombatValidator.UNKNOWN
		and CombatValidator.solve(fire, special, balance).status == CombatValidator.UNKNOWN,
		"3 Budgets and unsupported scope are UNKNOWN")

	var fragile := BalanceConfig.new(); fragile.core_max_hp = 7
	var defense := layout([["fire", "fire", "fire", "fire", "fire", "fire", "fire", "fire", "fire"],
		["shield", "shield", "shield"]])
	# Interval 2 makes ordering matter: Shield must precede the second Triple.
	var guarded := CombatValidator.solve(defense, enemy(18, 8, 2), fragile)
	var no_guard := CombatValidator.solve(layout([defense.stacks[0].tile_types]), enemy(18, 8, 2), fragile)
	var healing_balance := BalanceConfig.new(); healing_balance.core_max_hp = 13
	var healing := layout([["fire", "fire", "fire", "fire", "fire", "fire",
		"life", "life", "life", "fire", "fire", "fire", "fire", "fire", "fire"]])
	var healed := CombatValidator.solve(healing, enemy(24, 8, 2), healing_balance)
	check(guarded.status == CombatValidator.SOLVABLE and no_guard.status == CombatValidator.UNSOLVABLE
		and healed.status == CombatValidator.SOLVABLE and healed.witness.hp_damage_received == 16,
		"4 Shield ordering and Life recovery")

	var controlled := layout([["fire", "fire", "fire"], ["ice", "ice", "ice"]])
	var ice := CombatValidator.solve(controlled, enemy(9, 8), fragile)
	controlled.stacks[1].tile_types.assign(["wind", "wind", "wind"])
	var wind := CombatValidator.solve(controlled, enemy(9, 8), fragile)
	check(ice.status == CombatValidator.SOLVABLE and ice.witness.triples == ["ice", "fire"]
		and wind.status == CombatValidator.SOLVABLE and wind.witness.triples == ["wind", "fire"],
		"5 Ice and Wind prevent lethal attack")

	var armored := enemy(5); armored.armor = 20; armored.shield = 30
	var direct := CombatValidator.solve(layout([["lightning", "lightning", "lightning"]]), armored, balance)
	check(direct.status == CombatValidator.SOLVABLE and direct.witness.enemy_hp == 0
		and direct.witness.action_count == 3, "6 Lightning ignores Armor/Shield; victory on last Rune")

	var replayed := CombatValidator.replay(simple.witness)
	simple.witness.core_hp -= 1
	var tampered := CombatValidator.replay(simple.witness)
	check(replayed.valid and replayed.outcome == "victory" and not tampered.valid,
		"7 Fresh real-controller replay and mismatch rejection")
	print("M3: 7 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
