class_name RuntimeLayoutProvider
extends RefCounted

const BANK_PATH := "res://resources/layout_banks/approved_layout_bank_v1.json"
const PILOT_ENEMIES := ["cave_wisp", "stone_brute"]
const RECIPE_PATHS := {
	"cave_wisp_pilot":"res://resources/layout_recipes/cave_wisp_pilot.tres",
	"stone_brute_pilot":"res://resources/layout_recipes/stone_brute_pilot.tres",
}

var bank: Dictionary = {}
var entries_by_id: Dictionary = {}
var pools: Dictionary = {}

func _init(bank_override: Dictionary = {}) -> void:
	bank = bank_override.duplicate(true) if not bank_override.is_empty() else _load_bank()
	_index_bank()

func bank_version() -> int:
	return int(bank.get("bank_version", 0))

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if bank_version() != 1: errors.append("unsupported bank_version")
	var ids := {}
	for raw_entry in bank.get("entries", []):
		var entry: Dictionary = raw_entry
		var layout_id := str(entry.get("layout_id", ""))
		if layout_id.is_empty() or ids.has(layout_id): errors.append("duplicate/missing layout_id")
		ids[layout_id] = true
		if str(entry.get("enemy_id", "")) not in PILOT_ENEMIES: errors.append("non-pilot enemy in bank")
		if int(entry.get("recipe_version", 0)) <= 0 or int(entry.get("generator_version", 0)) <= 0:
			errors.append("invalid version metadata: " + layout_id)
		if str(entry.get("seed", "")).is_empty() or str(entry.get("expected_layout_hash", "")).length() != 64:
			errors.append("invalid reconstruction metadata: " + layout_id)
	return errors

func select_layout_id(run_seed: Variant, encounter_slot: int, enemy_id: String) -> String:
	var pool: Array = pools.get(enemy_id, [])
	if pool.is_empty(): return ""
	var digest := stable_selection_hash(run_seed, encounter_slot, enemy_id, bank_version())
	var index := 0
	for offset in range(0, 16, 2):
		index = (index * 256 + digest.substr(offset, 2).hex_to_int()) % pool.size()
	return str(pool[index])

func resolve(run_seed: Variant, encounter_slot: int, enemy_id: String,
		saved: Dictionary, fixed_level: LevelDefinition) -> Dictionary:
	if enemy_id not in PILOT_ENEMIES:
		return _fixed(fixed_level, enemy_id, "fixed_enemy", false, {})
	if not saved.is_empty():
		if saved.get("fallback", false): return _fixed(fixed_level, enemy_id, str(saved.get("reason", "saved_fallback")), true, saved)
		var saved_id := str(saved.get("layout_id", ""))
		if not entries_by_id.has(saved_id):
			push_warning("Runtime layout fallback: saved layout ID missing from bank: " + saved_id)
			var missing_state := saved.duplicate(true)
			missing_state.fallback = true
			missing_state.reason = "saved_layout_missing"
			return _fixed(fixed_level, enemy_id, "saved_layout_missing", true, missing_state)
		return _reconstruct(entries_by_id[saved_id], fixed_level, enemy_id)
	var selected := select_layout_id(run_seed, encounter_slot, enemy_id)
	if selected.is_empty():
		push_warning("Runtime layout fallback: empty approved pool for " + enemy_id)
		return _fixed(fixed_level, enemy_id, "empty_pool", true, {})
	return _reconstruct(entries_by_id[selected], fixed_level, enemy_id)

func reconstruct_entry(entry: Dictionary, fixed_level: LevelDefinition = null) -> Dictionary:
	return _reconstruct(entry, fixed_level, str(entry.get("enemy_id", "")))

static func stable_selection_hash(run_seed: Variant, encounter_slot: int,
		enemy_id: String, selected_bank_version: int) -> String:
	var values := ["runtime_layout", str(run_seed), str(selected_bank_version), str(encounter_slot), enemy_id]
	var encoded: Array[String] = []
	for value in values:
		var token := str(value)
		encoded.append("%d:%s" % [token.to_utf8_buffer().size(), token])
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update("|".join(encoded).to_utf8_buffer())
	return context.finish().hex_encode()

func _reconstruct(entry: Dictionary, fixed_level: LevelDefinition, enemy_id: String) -> Dictionary:
	var reason := ""
	var recipe_id := str(entry.get("recipe_id", ""))
	if not RECIPE_PATHS.has(recipe_id): reason = "missing_recipe"
	elif int(entry.get("generator_version", 0)) != LayoutBuilder.GENERATOR_VERSION: reason = "unsupported_generator_version"
	else:
		var recipe: LayoutRecipe = load(RECIPE_PATHS[recipe_id])
		if recipe == null or recipe.recipe_version != int(entry.get("recipe_version", 0)): reason = "recipe_version_mismatch"
		else:
			var built := LayoutBuilder.build(recipe, str(entry.get("seed", "")))
			if not built.ok: reason = "builder_failure"
			elif built.layout.layout_hash != str(entry.get("expected_layout_hash", "")): reason = "layout_hash_mismatch"
			else:
				var level: LevelDefinition = built.layout.to_level("approved_" + str(entry.layout_id))
				level.encounter_enemy_ids.assign([enemy_id])
				var state := _state_for(entry, false, "")
				return {"level":level, "source":"approved", "persist":true, "state":state,
					"layout_id":entry.layout_id, "layout_hash":built.layout.layout_hash, "reason":""}
	push_warning("Runtime layout fallback for %s: %s" % [enemy_id, reason])
	return _fixed(fixed_level, enemy_id, reason, true, _state_for(entry, true, reason))

func _fixed(level: LevelDefinition, enemy_id: String, reason: String, persist: bool, state: Dictionary) -> Dictionary:
	var fixed := level.duplicate(true) as LevelDefinition if level != null else LevelDefinition.new()
	if fixed.encounter_enemy_ids.is_empty() and not enemy_id.is_empty(): fixed.encounter_enemy_ids.assign([enemy_id])
	if persist and state.is_empty():
		state = {"slot":-1, "enemy_id":enemy_id, "bank_version":bank_version(), "layout_id":"",
			"layout_hash":"", "recipe_version":0, "generator_version":0, "fallback":true, "reason":reason}
	return {"level":fixed, "source":"fallback" if persist else "fixed", "persist":persist,
		"state":state, "layout_id":str(state.get("layout_id", "")),
		"layout_hash":str(state.get("layout_hash", "")), "reason":reason}

func _state_for(entry: Dictionary, fallback: bool, reason: String) -> Dictionary:
	return {"enemy_id":str(entry.get("enemy_id", "")), "bank_version":bank_version(),
		"layout_id":str(entry.get("layout_id", "")), "layout_hash":str(entry.get("expected_layout_hash", "")),
		"recipe_version":int(entry.get("recipe_version", 0)),
		"generator_version":int(entry.get("generator_version", 0)), "fallback":fallback, "reason":reason}

func _load_bank() -> Dictionary:
	if not FileAccess.file_exists(BANK_PATH):
		push_error("Approved layout bank missing: " + BANK_PATH)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BANK_PATH))
	if not parsed is Dictionary:
		push_error("Approved layout bank is invalid JSON")
		return {}
	return parsed

func _index_bank() -> void:
	entries_by_id.clear(); pools.clear()
	for raw_entry in bank.get("entries", []):
		var entry: Dictionary = raw_entry
		var layout_id := str(entry.get("layout_id", ""))
		entries_by_id[layout_id] = entry
		var enemy_id := str(entry.get("enemy_id", ""))
		if not pools.has(enemy_id): pools[enemy_id] = []
		pools[enemy_id].append(layout_id)
	for enemy_id in pools: pools[enemy_id].sort()
