extends SceneTree

const WISP_001_HASH := "18186bb3ebd046884753654a74ba78e7d9e1b9d481569cc1525752b6ebc07bda"
const WISP_002_HASH := "ab49f973d2723266119914a61e89a9d06c89555c6aa6a56d4302db6678a6a874"
const BRUTE_001_HASH := "befc57aba914e290ee360fc054fbffeb41a7ade62dea6b1edd24a56513d38838"
const WISP_001_STACKS := [
	["ice", "fire", "fire", "wind", "fire", "lightning"],
	["ice", "ice", "fire", "lightning", "ice", "fire"],
	["shield", "wind", "fire", "fire", "shield", "shield"],
	["ice", "ice", "shield", "wind", "ice", "lightning"],
	["wind", "ice", "fire", "ice", "wind"],
]

var failures := 0
var wisp: LayoutRecipe = load("res://resources/layout_recipes/cave_wisp_pilot.tres")
var brute: LayoutRecipe = load("res://resources/layout_recipes/stone_brute_pilot.tres")

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func in_bounds(layout: GeneratedLayout, recipe: LayoutRecipe) -> bool:
	if layout.stacks.size() < recipe.min_stacks or layout.stacks.size() > recipe.max_stacks: return false
	var total := 0
	for stack in layout.stacks:
		total += stack.size()
		if stack.size() < recipe.min_stack_length or stack.size() > recipe.max_stack_length: return false
		var streak := 0; var previous := ""
		for type_id in stack:
			streak = streak + 1 if type_id == previous else 1
			if streak > recipe.max_same_type_streak: return false
			previous = type_id
	if total < recipe.min_total_runes or total > recipe.max_total_runes: return false
	for type_id in LayoutBuilder.RUNES:
		if int(layout.rune_counts[type_id]) < int(recipe.rune_minimums[type_id]): return false
		if int(layout.rune_counts[type_id]) > int(recipe.rune_maximums[type_id]): return false
	return true

func early_access_ok(layout: GeneratedLayout, recipe: LayoutRecipe) -> bool:
	for constraint in recipe.early_access:
		var found := 0
		for stack in layout.stacks:
			for depth in mini(stack.size(), int(constraint.max_depth) + 1):
				if stack[depth] == constraint.rune: found += 1
		if found < int(constraint.required_count): return false
	return true

func _initialize() -> void:
	var wisp_001 := LayoutBuilder.build(wisp, "wisp-test-001")
	var wisp_repeat := LayoutBuilder.build(wisp, "wisp-test-001")
	var wisp_002 := LayoutBuilder.build(wisp, "wisp-test-002")
	var brute_001 := LayoutBuilder.build(brute, "brute-test-001")
	check(wisp_001.ok and wisp_repeat.ok and wisp_001.layout.ordered_stacks() == wisp_repeat.layout.ordered_stacks()
		and wisp_001.layout.layout_hash == wisp_repeat.layout.layout_hash, "1 Same seed determinism")
	check(wisp_002.ok and wisp_001.layout.ordered_stacks() != wisp_002.layout.ordered_stacks(), "2 Golden seeds demonstrate variation")
	var level: LevelDefinition = wisp_001.layout.to_level("wisp_fixture")
	var board := BoardModel.new(level)
	var top_ok := true
	for index in level.stacks.size(): top_ok = top_ok and board.top_tile(index).type_id == wisp_001.layout.stacks[index][0]
	check(top_ok, "3 Conversion preserves tile_types[0] as Top")
	check(in_bounds(wisp_001.layout, wisp) and in_bounds(wisp_002.layout, wisp)
		and in_bounds(brute_001.layout, brute), "4 Pilot outputs obey count/length/streak bounds")
	check(early_access_ok(wisp_001.layout, wisp) and early_access_ok(wisp_002.layout, wisp)
		and early_access_ok(brute_001.layout, brute), "5 Pilot early-access guarantees hold")
	var invalid := wisp.duplicate(true) as LayoutRecipe
	invalid.min_stacks = 7; invalid.max_stacks = 5
	var rejected := LayoutBuilder.build(invalid, "invalid-test")
	check(not rejected.ok and not rejected.errors.is_empty() and rejected.errors[0].contains("stack range"), "6 Invalid recipe has explicit failure")
	check(wisp_001.layout.ordered_stacks() == WISP_001_STACKS and wisp_001.layout.layout_hash == WISP_001_HASH
		and wisp_002.layout.layout_hash == WISP_002_HASH and brute_001.layout.layout_hash == BRUTE_001_HASH,
		"7 Full ordered structure and hashes match golden fixtures")
	var changed_recipe_hash := LayoutBuilder.canonical_hash(1, wisp.recipe_id, 2, "wisp-test-001", wisp_001.layout.stacks)
	var changed_generator_hash := LayoutBuilder.canonical_hash(2, wisp.recipe_id, 1, "wisp-test-001", wisp_001.layout.stacks)
	check(changed_recipe_hash != wisp_001.layout.layout_hash and changed_generator_hash != wisp_001.layout.layout_hash,
		"8 Generator and recipe versions participate in hash identity")
	print("M10B1: 8 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
