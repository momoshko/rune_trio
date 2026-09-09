class_name RunDefinition
extends Resource

@export var id := ""
# Chapters cover consecutive slots; presentation reuses existing location assets.
@export var chapters: Array[Dictionary] = []
@export var slots: Array[Dictionary] = []
@export var encounters: Array[EncounterDefinition] = []
@export var relics: Array[RelicDefinition] = []
@export var restore_amount := 12
@export var initial_hp := 40
@export var recovery_amount := 16
@export var recovery_floor := 32
@export var maximum_hp := 40

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("Missing stable run ID")
	if slots.size() != 12: errors.append("M1 requires 12 slots")
	if chapters.size() != 3: errors.append("M1 requires 3 chapters")
	var chapter_ids: Array[String] = []
	for index in chapters.size():
		var chapter := chapters[index]
		var chapter_id := str(chapter.get("id", ""))
		if chapter_id.is_empty() or chapter_ids.has(chapter_id) or str(chapter.get("name_key", "")).is_empty():
			errors.append("Invalid chapter identity at %d" % index)
		chapter_ids.append(chapter_id)
		if chapter.get("first_slot", -1) != index * 4 or chapter.get("slot_count", 0) != 4:
			errors.append("Chapters must cover 4 consecutive slots each")
		if chapter.get("presentation", "") not in ["stone_ruins", "frozen_grove"]:
			errors.append("Chapter must reuse an existing presentation")
	for index in slots.size():
		var slot := slots[index]
		var expected_role := "final_boss" if index == 11 else ("boss" if index % 4 == 3 else ("elite" if index % 4 == 2 else "normal"))
		if slot.get("role", "") != expected_role: errors.append("Invalid role at slot %d" % index)
	if initial_hp != 40 or maximum_hp != 40 or recovery_amount != 16 or recovery_floor != 32:
		errors.append("Invalid M1 recovery parameters")
	if restore_amount != 12: errors.append("Restore must grant 12 HP")
	var encounter_ids := {}
	for encounter in encounters:
		if encounter == null:
			errors.append("Null encounter"); continue
		if encounter.id.is_empty() or encounter_ids.has(encounter.id): errors.append("Duplicate/missing encounter ID")
		encounter_ids[encounter.id] = true
		if encounter.chapter < 0 or encounter.chapter >= 3 or encounter.role not in ["normal", "elite", "boss"]:
			errors.append("Invalid encounter chapter/role: " + encounter.id)
		if encounter.level == null or EnemyCatalog.by_id(encounter.enemy_id) == null:
			errors.append("Missing authored enemy/layout: " + encounter.id)
		if encounter.danger not in ["MODERATE", "HIGH", "VERY_HIGH"] or encounter.reward_category not in ["ATTACK", "CONTROL", "DEFENSE", "MIXED"] or encounter.mechanic_key.is_empty():
			errors.append("Missing encounter display metadata: " + encounter.id)
	for index in 3:
		var archetypes := {}
		for encounter in pool(index, "normal"): archetypes[encounter.enemy_id] = true
		if archetypes.size() < 3: errors.append("Chapter %d needs 3 normal archetypes for stable two-card offers" % (index + 1))
		for fixed_role in ["elite", "boss"]:
			if pool(index, fixed_role).size() != 1: errors.append("Chapter %d needs exactly one %s" % [index + 1, fixed_role])
	var relic_ids := {}
	var counts := {"COMMON":0, "RARE":0}
	for relic in relics:
		if relic == null:
			errors.append("Null relic"); continue
		if relic.id.is_empty() or relic.id == "restore_core" or relic_ids.has(relic.id): errors.append("Duplicate/invalid relic ID")
		relic_ids[relic.id] = true
		if not counts.has(relic.rarity): errors.append("Invalid rarity")
		else: counts[relic.rarity] += 1
		if relic.category not in ["ATTACK", "CONTROL", "DEFENSE", "MIXED"] or relic.name_key.is_empty() or relic.description_key.is_empty() or relic.icon_key.is_empty():
			errors.append("Missing relic metadata: " + relic.id)
	if counts.COMMON < 12 or counts.RARE < 8: errors.append("M4 needs at least 12 Common and 8 Rare relics")
	return errors

func pool(chapter_index: int, encounter_role: String) -> Array[EncounterDefinition]:
	var result: Array[EncounterDefinition] = []
	for encounter in encounters:
		if encounter and encounter.chapter == chapter_index and encounter.role == encounter_role: result.append(encounter)
	return result

func encounter_by_id(encounter_id: String) -> EncounterDefinition:
	for encounter in encounters:
		if encounter.id == encounter_id: return encounter
	return null

func relic_by_id(relic_id: String) -> RelicDefinition:
	for relic in relics:
		if relic.id == relic_id: return relic
	return null

func chapter_index_for_slot(slot_index: int) -> int:
	for index in chapters.size():
		var chapter := chapters[index]
		if slot_index >= chapter.first_slot and slot_index < chapter.first_slot + chapter.slot_count:
			return index
	return -1

func is_chapter_end(slot_index: int) -> bool:
	var index := chapter_index_for_slot(slot_index)
	return index >= 0 and slot_index == chapters[index].first_slot + chapters[index].slot_count - 1

func hp_after_victory(slot_index: int, hp: int) -> int:
	if is_chapter_end(slot_index) and slot_index < slots.size() - 1:
		return mini(maximum_hp, maxi(recovery_floor, hp + recovery_amount))
	return hp
