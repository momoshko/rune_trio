extends SceneTree

var failures := 0
var provider := RuntimeLayoutProvider.new()
var catalog: RunDefinition = load("res://resources/runs/m4_run.tres")

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func _initialize() -> void:
	var entries: Array = provider.bank.get("entries", [])
	var enemy_counts := {"cave_wisp":0, "stone_brute":0}
	var approved_only := entries.size() == 15 and provider.validation_errors().is_empty()
	for entry in entries:
		approved_only = approved_only and enemy_counts.has(entry.enemy_id)
		enemy_counts[entry.enemy_id] = int(enemy_counts.get(entry.enemy_id, 0)) + 1
		approved_only = approved_only and entry.seed not in ["m10b2:cave_wisp-003", "m10b2:cave_wisp-005",
			"m10b2:stone_brute-001", "m10b2:stone_brute-002", "m10b2:stone_brute-003",
			"m10b2:stone_brute-008", "m10b2:stone_brute-009", "m10b2:stone_brute-011", "m10b2:stone_brute-012"]
	check(approved_only and enemy_counts.cave_wisp == 10 and enemy_counts.stone_brute == 5,
		"1 Bank loads only 10 Wisp + 5 Brute APPROVED entries")

	var same_a := provider.select_layout_id(101, 0, "cave_wisp")
	var same_b := provider.select_layout_id(101, 0, "cave_wisp")
	check(not same_a.is_empty() and same_a == same_b, "2 Same run seed/slot/enemy resolves same stable ID")
	var different_a := provider.select_layout_id(101, 0, "cave_wisp")
	var different_b := provider.select_layout_id(102, 0, "cave_wisp")
	check(different_a != different_b, "3 Golden run seeds 101/102 can select different Wisp IDs")

	var fixed_wisp := catalog.encounter_by_id("chapter_1_cave_wisp").battle_level()
	var first := provider.resolve(202, 0, "cave_wisp", {}, fixed_wisp)
	var second := provider.resolve(999, 0, "cave_wisp", first.state, fixed_wisp)
	check(first.source == "approved" and second.layout_id == first.layout_id and second.layout_hash == first.layout_hash,
		"4 Saved resolution is stable and ignores later seed changes")

	var all_valid := true
	for entry in entries:
		var reconstructed := provider.reconstruct_entry(entry)
		all_valid = all_valid and reconstructed.source == "approved" \
			and reconstructed.layout_hash == entry.expected_layout_hash
	check(all_valid, "5 All 15 bank entries reconstruct to expected hashes")

	var baseline := _reward_offer(303, false)
	var with_layout := _reward_offer(303, true)
	check(baseline == with_layout, "6 Layout resolution is independent from reward RNG state/offers")

	var moss_fixed := catalog.encounter_by_id("chapter_1_moss_slime").battle_level()
	var moss := provider.resolve(404, 0, "moss_slime", {}, moss_fixed)
	check(moss.source == "fixed" and moss.level.id == moss_fixed.id and not moss.persist,
		"7 Non-pilot enemy keeps curated fixed LevelDefinition")

	var corrupt_bank := provider.bank.duplicate(true)
	corrupt_bank.entries[0].expected_layout_hash = "0000000000000000000000000000000000000000000000000000000000000000"
	var corrupt_saved := {"layout_id":corrupt_bank.entries[0].layout_id, "enemy_id":"cave_wisp",
		"bank_version":1, "layout_hash":corrupt_bank.entries[0].expected_layout_hash,
		"recipe_version":1, "generator_version":1, "fallback":false}
	var corrupt := RuntimeLayoutProvider.new(corrupt_bank).resolve(505, 0, "cave_wisp", corrupt_saved, fixed_wisp)
	var missing_saved := {"layout_id":"removed_layout", "enemy_id":"cave_wisp", "bank_version":1,
		"layout_hash":"old", "recipe_version":1, "generator_version":1, "fallback":false}
	var missing := provider.resolve(505, 0, "cave_wisp", missing_saved, fixed_wisp)
	check(corrupt.source == "fallback" and corrupt.state.fallback and missing.source == "fallback"
		and missing.state.layout_id == "removed_layout", "8 Corrupt/missing entry uses sticky curated fallback without reroll")

	var smoke_ok := _battle_smoke("cave_wisp", 606)
	smoke_ok = smoke_ok and _battle_smoke("stone_brute", 607)
	check(smoke_ok, "9 Approved Wisp and Brute layouts start real battles with Top at index 0")

	print("M10B3: 9 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func _reward_offer(seed_value: int, resolve_layout: bool) -> Array:
	var game := GameController.new(); game.balance = BalanceConfig.new()
	var controller := RunController.new(); controller.definition = catalog; controller.bind_game(game)
	controller.new_run(seed_value)
	controller.run.current_slot_index = 2
	controller.run.selected_encounter_id = catalog.pool(0, "normal")[0].id
	var before := controller.run.rng_state
	if resolve_layout:
		provider.resolve(seed_value, 0, "cave_wisp", {}, catalog.encounter_by_id("chapter_1_cave_wisp").battle_level())
		if controller.run.rng_state != before: return ["RNG_CHANGED"]
	controller._create_reward()
	var offer := controller.run.reward_offer.duplicate()
	controller.free(); game.free()
	return offer

func _battle_smoke(enemy_id: String, seed_value: int) -> bool:
	var game := GameController.new(); game.balance = BalanceConfig.new()
	var controller := RunController.new(); controller.definition = catalog; controller.bind_game(game)
	if not controller.new_run(seed_value): return false
	var encounter_id := "chapter_1_" + enemy_id
	controller.run.selected_encounter_id = encounter_id
	controller._start_encounter()
	var resolved: Dictionary = controller.run.resolved_layouts.get("0", {})
	var ok: bool = not resolved.get("fallback", true) and not str(resolved.get("layout_id", "")).is_empty() \
		and game.board != null and game.battle.current_enemy.id == enemy_id and game.current_level.id.begins_with("approved_")
	for stack in game.current_level.stacks:
		ok = ok and game.board.top_tile(stack.stack_id).type_id == stack.tile_types[0]
	controller.free(); game.free()
	return ok
