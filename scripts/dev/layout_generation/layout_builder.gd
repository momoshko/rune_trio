class_name LayoutBuilder
extends RefCounted

const GENERATOR_VERSION := 1
const RUNES := ["fire", "ice", "lightning", "wind", "life", "shield"]
const MAX_PLACEMENT_ATTEMPTS := 24

class StableRandom:
	var seed_text: String
	var counter := 0

	func _init(value: String) -> void:
		seed_text = value

	func next_u32() -> int:
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update((seed_text + "#" + str(counter)).to_utf8_buffer())
		counter += 1
		return int((context.finish().hex_encode() as String).substr(0, 8).hex_to_int())

	func range_inclusive(minimum: int, maximum: int) -> int:
		return minimum + next_u32() % (maximum - minimum + 1)

static func build(recipe: LayoutRecipe, seed: String) -> Dictionary:
	var errors := validate_recipe(recipe)
	if seed.is_empty(): errors.append("seed must not be empty")
	if not errors.is_empty(): return _failure(errors)
	var rng := StableRandom.new(_identity_prefix(recipe, seed))
	var feasible_stacks: Array[int] = []
	var effective_minimums := _effective_minimums(recipe)
	var minimum_runes := _sum_values(effective_minimums)
	var maximum_runes := _sum_values(recipe.rune_maximums)
	for count in range(recipe.min_stacks, recipe.max_stacks + 1):
		var low := maxi(maxi(recipe.min_total_runes, count * recipe.min_stack_length), minimum_runes)
		var high := mini(mini(recipe.max_total_runes, count * recipe.max_stack_length), maximum_runes)
		if low <= high: feasible_stacks.append(count)
	if feasible_stacks.is_empty(): return _failure(["no stack count can satisfy total/count/length bounds"])
	var stack_count := feasible_stacks[rng.range_inclusive(0, feasible_stacks.size() - 1)]
	var total_low := maxi(maxi(recipe.min_total_runes, stack_count * recipe.min_stack_length), minimum_runes)
	var total_high := mini(mini(recipe.max_total_runes, stack_count * recipe.max_stack_length), maximum_runes)
	var total_runes := rng.range_inclusive(total_low, total_high)
	var counts_result := _allocate_counts(recipe, effective_minimums, total_runes, rng)
	if not counts_result.ok: return counts_result
	var lengths := _allocate_lengths(recipe, stack_count, total_runes, rng)
	for attempt in MAX_PLACEMENT_ATTEMPTS:
		var placed := _place_runes(recipe, lengths, counts_result.counts, rng)
		if placed.ok:
			var generated := GeneratedLayout.new()
			generated.recipe_id = recipe.recipe_id
			generated.recipe_version = recipe.recipe_version
			generated.generator_version = GENERATOR_VERSION
			generated.seed = seed
			generated.stacks.assign(placed.stacks)
			generated.stack_lengths.assign(lengths)
			generated.rune_counts = counts_result.counts.duplicate(true)
			generated.layout_hash = canonical_hash(GENERATOR_VERSION, recipe.recipe_id,
				recipe.recipe_version, seed, generated.stacks)
			return {"ok":true, "layout":generated, "errors":PackedStringArray()}
	return _failure(["bounded placement attempts exhausted"])

static func validate_recipe(recipe: LayoutRecipe) -> PackedStringArray:
	var errors := PackedStringArray()
	if recipe == null: errors.append("missing recipe"); return errors
	if recipe.recipe_id.is_empty(): errors.append("recipe_id must not be empty")
	if recipe.recipe_version <= 0: errors.append("recipe_version must be positive")
	if recipe.min_stacks <= 0 or recipe.min_stacks > recipe.max_stacks: errors.append("invalid stack range")
	if recipe.min_total_runes <= 0 or recipe.min_total_runes > recipe.max_total_runes: errors.append("invalid total Rune range")
	if recipe.min_stack_length <= 0 or recipe.min_stack_length > recipe.max_stack_length: errors.append("invalid stack length range")
	if recipe.max_same_type_streak <= 0: errors.append("max_same_type_streak must be positive")
	for table_name in ["rune_minimums", "rune_maximums", "rune_weights"]:
		var table: Dictionary = recipe.get(table_name)
		for key in table.keys():
			if str(key) not in RUNES: errors.append("invalid Rune type in %s: %s" % [table_name, key])
	for type_id in RUNES:
		if not recipe.rune_minimums.has(type_id) or not recipe.rune_maximums.has(type_id):
			errors.append("missing Rune bounds: " + type_id); continue
		var minimum := int(recipe.rune_minimums[type_id])
		var maximum := int(recipe.rune_maximums[type_id])
		if minimum < 0 or maximum < minimum: errors.append("invalid Rune bounds: " + type_id)
		if float(recipe.rune_weights.get(type_id, 1.0)) < 0.0: errors.append("negative Rune weight: " + type_id)
	var early_totals := {}
	for index in recipe.early_access.size():
		var constraint: Dictionary = recipe.early_access[index]
		var type_id := str(constraint.get("rune", ""))
		var required := int(constraint.get("required_count", 0))
		var max_depth := int(constraint.get("max_depth", -1))
		if type_id not in RUNES or required <= 0 or max_depth < 0:
			errors.append("invalid early_access constraint at %d" % index); continue
		if early_totals.has(type_id):
			errors.append("duplicate early_access Rune: " + type_id); continue
		early_totals[type_id] = int(early_totals.get(type_id, 0)) + required
		if int(early_totals[type_id]) > int(recipe.rune_maximums.get(type_id, -1)):
			errors.append("early_access exceeds Rune maximum: " + type_id)
	if _sum_values(_effective_minimums(recipe)) > recipe.max_total_runes:
		errors.append("effective Rune minimums exceed maximum total")
	if _sum_values(recipe.rune_maximums) < recipe.min_total_runes:
		errors.append("Rune maximums cannot reach minimum total")
	var structural_low := recipe.min_stacks * recipe.min_stack_length
	var structural_high := recipe.max_stacks * recipe.max_stack_length
	if maxi(structural_low, recipe.min_total_runes) > mini(structural_high, recipe.max_total_runes):
		errors.append("stack length bounds cannot satisfy total Rune range")
	return errors

static func canonical_hash(generator_version: int, recipe_id: String, recipe_version: int,
		seed: String, stacks: Array) -> String:
	var parts := ["generator", str(generator_version), _token(recipe_id), str(recipe_version), _token(seed), str(stacks.size())]
	for stack in stacks:
		parts.append(str(stack.size()))
		for type_id in stack: parts.append(_token(str(type_id)))
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update("|".join(parts).to_utf8_buffer())
	return context.finish().hex_encode()

static func _allocate_counts(recipe: LayoutRecipe, minimums: Dictionary, total: int, rng: StableRandom) -> Dictionary:
	var counts := minimums.duplicate(true)
	var remaining := total - _sum_values(counts)
	while remaining > 0:
		var weighted: Array[String] = []
		for type_id in RUNES:
			if int(counts[type_id]) >= int(recipe.rune_maximums[type_id]): continue
			var weight := maxi(0, int(round(float(recipe.rune_weights.get(type_id, 1.0)) * 10.0)))
			for unused in weight: weighted.append(type_id)
		if weighted.is_empty(): return _failure(["Rune weights/maxima cannot allocate selected total"])
		var chosen := weighted[rng.range_inclusive(0, weighted.size() - 1)]
		counts[chosen] = int(counts[chosen]) + 1
		remaining -= 1
	return {"ok":true, "counts":counts}

static func _allocate_lengths(recipe: LayoutRecipe, stack_count: int, total: int, rng: StableRandom) -> Array[int]:
	var lengths: Array[int] = []
	lengths.resize(stack_count); lengths.fill(recipe.min_stack_length)
	var remaining := total - stack_count * recipe.min_stack_length
	while remaining > 0:
		var candidates: Array[int] = []
		for index in stack_count:
			if lengths[index] < recipe.max_stack_length: candidates.append(index)
		var chosen := candidates[rng.range_inclusive(0, candidates.size() - 1)]
		lengths[chosen] += 1
		remaining -= 1
	return lengths

static func _place_runes(recipe: LayoutRecipe, lengths: Array[int], counts: Dictionary, rng: StableRandom) -> Dictionary:
	var stacks: Array[Array] = []
	for length in lengths:
		var stack: Array = []; stack.resize(length); stack.fill(""); stacks.append(stack)
	var remaining := counts.duplicate(true)
	for constraint in recipe.early_access:
		var type_id := str(constraint.rune)
		var candidates: Array[Vector2i] = []
		for stack_index in stacks.size():
			for depth in mini(stacks[stack_index].size(), int(constraint.max_depth) + 1):
				if stacks[stack_index][depth] == "": candidates.append(Vector2i(stack_index, depth))
		if candidates.size() < int(constraint.required_count): return {"ok":false}
		_shuffle(candidates, rng)
		for index in int(constraint.required_count):
			var cell := candidates[index]
			stacks[cell.x][cell.y] = type_id
			remaining[type_id] = int(remaining[type_id]) - 1
	var cells: Array[Vector2i] = []
	for depth in recipe.max_stack_length:
		for stack_index in stacks.size():
			if depth < stacks[stack_index].size() and stacks[stack_index][depth] == "": cells.append(Vector2i(stack_index, depth))
	for cell in cells:
		var valid: Array[String] = []
		for type_id in RUNES:
			if int(remaining[type_id]) > 0 and _can_place(stacks[cell.x], cell.y, type_id, recipe.max_same_type_streak): valid.append(type_id)
		if valid.is_empty(): return {"ok":false}
		var selected := valid[rng.range_inclusive(0, valid.size() - 1)]
		stacks[cell.x][cell.y] = selected
		remaining[selected] = int(remaining[selected]) - 1
	for value in remaining.values():
		if int(value) != 0: return {"ok":false}
	if not _streaks_valid(stacks, recipe.max_same_type_streak): return {"ok":false}
	return {"ok":true, "stacks":stacks}

static func _can_place(stack: Array, depth: int, type_id: String, maximum: int) -> bool:
	var before := 0
	for index in range(depth - 1, -1, -1):
		if stack[index] != type_id: break
		before += 1
	var after := 0
	for index in range(depth + 1, stack.size()):
		if stack[index] == "": break
		if stack[index] != type_id: break
		after += 1
	return before + 1 + after <= maximum

static func _streaks_valid(stacks: Array[Array], maximum: int) -> bool:
	for stack in stacks:
		var previous := ""
		var streak := 0
		for type_id in stack:
			streak = streak + 1 if type_id == previous else 1
			if streak > maximum: return false
			previous = type_id
	return true

static func _effective_minimums(recipe: LayoutRecipe) -> Dictionary:
	var result := {}
	for type_id in RUNES: result[type_id] = int(recipe.rune_minimums.get(type_id, 0))
	for constraint in recipe.early_access:
		var type_id := str(constraint.get("rune", ""))
		if type_id in RUNES: result[type_id] = maxi(int(result[type_id]), int(constraint.get("required_count", 0)))
	return result

static func _sum_values(values: Dictionary) -> int:
	var total := 0
	for type_id in RUNES: total += int(values.get(type_id, 0))
	return total

static func _shuffle(values: Array, rng: StableRandom) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := rng.range_inclusive(0, index)
		var value = values[index]; values[index] = values[other]; values[other] = value

static func _identity_prefix(recipe: LayoutRecipe, seed: String) -> String:
	return "%d|%s|%d|%s" % [GENERATOR_VERSION, _token(recipe.recipe_id), recipe.recipe_version, _token(seed)]

static func _token(value: String) -> String:
	return "%d:%s" % [value.to_utf8_buffer().size(), value]

static func _failure(messages: Array) -> Dictionary:
	var errors := PackedStringArray()
	for message in messages: errors.append(str(message))
	return {"ok":false, "layout":null, "errors":errors}
