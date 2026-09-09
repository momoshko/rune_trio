class_name EnemyDefinition
extends Resource

@export_category("Enemy")
@export_group("Identity")
@export var id := "training_dummy"
@export var name_key := "ENEMY_TRAINING_DUMMY"
@export_group("Combat")
@export var max_hp := 18
@export var armor := 0
@export var shield := 0
@export var shield_max := 0 # Legacy initial Shield remains valid; no restore by default.
@export var attack_damage := 6
@export var attack_interval_triples := 3
@export var attack_damage_sequence: Array[int] = []
@export var rock_throw_damage := 0
@export_group("Boss Phases")
@export var phase_hp_thresholds: Array[int] = []
@export var phase_armors: Array[int] = []
@export var phase_attack_damages: Array[int] = []
@export var phase_attack_intervals: Array[int] = []
@export var phase_mechanic_keys: Array[String] = []
@export var attack_name_keys: Array[String] = []
@export var phase_sequence_damages: Array[int] = []
@export var phase_sequence_intervals: Array[int] = []
@export var vulnerability_cycle: Array[String] = []
@export var vulnerability_bonus := 0
@export var phase_vulnerability_periods: Array[int] = []
@export_group("Mechanic")
@export_enum("NONE", "HEAL_ON_HP_HIT", "RUNE_VULNERABILITY", "SHIELD_AFTER_ATTACK", "SHIELD_ON_REPEAT", "HIT_UNSHIELDED", "BOOST_ATTACK_ON_REPEAT", "OPEN_ARMOR_ON_DEFENSE", "FAST_AT_HALF_HP", "EXTRA_TIMELINE_ON_REPEAT") var mechanic := "NONE"
@export var mechanic_amount := 0
@export var mechanic_cap := 0
@export var mechanic_threshold := 0
@export var vulnerable_rune := ""
@export var shield_break_rune := ""
@export var mechanic_key := ""
@export_group("Visuals")
@export var visual_color := Color("c97872")
@export var texture: Texture2D
@export var portrait: Texture2D
@export_range(0.5, 2.5, 0.05) var boss_scale := 1.0
@export var tags: Array[String] = []

func has_phases() -> bool:
	return phase_attack_damages.size() > 0

func phase_count() -> int:
	return phase_attack_damages.size() if has_phases() else 1

func phase_armor(index: int) -> int:
	return phase_armors[index] if index >= 0 and index < phase_armors.size() else armor

func phase_attack_damage(index: int) -> int:
	return phase_attack_damages[index] if index >= 0 and index < phase_attack_damages.size() else attack_damage

func phase_attack_interval(index: int) -> int:
	return phase_attack_intervals[index] if index >= 0 and index < phase_attack_intervals.size() else attack_interval_triples

func phase_mechanic_key(index: int) -> String:
	return phase_mechanic_keys[index] if index >= 0 and index < phase_mechanic_keys.size() else mechanic_key

func next_phase(index: int, hp: int) -> int:
	var result := index
	while result < phase_hp_thresholds.size() and hp <= phase_hp_thresholds[result]: result += 1
	return mini(result, phase_count() - 1)

func phases_valid() -> bool:
	if not has_phases(): return true
	var phase_data_valid := phase_armors.size() == phase_count() and phase_attack_intervals.size() == phase_count() \
		and phase_mechanic_keys.size() == phase_count() and phase_hp_thresholds.size() == phase_count() - 1
	if not phase_data_valid: return false
	if attack_name_keys.is_empty():
		if not phase_sequence_damages.is_empty() or not phase_sequence_intervals.is_empty(): return false
	else:
		var expected := phase_count() * attack_name_keys.size()
		if phase_sequence_damages.size() != expected or phase_sequence_intervals.size() != expected: return false
	return phase_vulnerability_periods.is_empty() or phase_vulnerability_periods.size() == phase_count()

func has_cyclic_vulnerability() -> bool:
	return not vulnerability_cycle.is_empty() and vulnerability_bonus > 0

func vulnerability_period(phase_index: int) -> int:
	return maxi(1, phase_vulnerability_periods[phase_index]) if phase_index >= 0 and phase_index < phase_vulnerability_periods.size() else 1

func attack_entry(phase_index: int, sequence: int) -> Dictionary:
	var entry := 0
	var name_key := ""
	var damage := phase_attack_damage(phase_index)
	var interval := phase_attack_interval(phase_index)
	if not attack_name_keys.is_empty():
		entry = (sequence - 1) % attack_name_keys.size()
		name_key = attack_name_keys[entry]
		var offset := phase_index * attack_name_keys.size() + entry
		if offset < phase_sequence_damages.size(): damage = phase_sequence_damages[offset]
		if offset < phase_sequence_intervals.size(): interval = phase_sequence_intervals[offset]
	return {"sequence":sequence, "entry":entry, "name_key":name_key,
		"damage":damage, "interval":maxi(1, interval)}

func prepare_attack(sequence: int, interval_override := 0, phase_index := 0) -> PreparedAttack:
	# Compatibility adapter for the existing v0.7 actions, not new boss mechanics.
	# Old bosses had a six-Triple cycle with one action every three Triples.
	var entry := attack_entry(phase_index, sequence)
	var interval: int = entry.interval
	if interval_override > 0: interval = interval_override
	var sequence_damage: int = entry.damage
	if not attack_damage_sequence.is_empty():
		sequence_damage = attack_damage_sequence[(sequence - 1) % attack_damage_sequence.size()]
	if has_phases(): return PreparedAttack.new(sequence, sequence_damage, interval, "enemy_attack", "", entry.name_key)
	if tags.has("heavy"):
		return PreparedAttack.new(sequence, rock_throw_damage, interval, "heavy_attack", "heavy_attack")
	if tags.has("frost_lock"):
		return PreparedAttack.new(sequence, 0, interval, "lock_stack_request", "frost_attack")
	if tags.has("boss"):
		interval = maxi(1, interval / 2)
		var witch := tags.has("frost_witch")
		if sequence % 2 == 0:
			return PreparedAttack.new(sequence, 0, interval, "lock_stack_request", "frost_seal" if witch else "stone_lock")
		var ability := "ice_bolt" if witch else "rock_throw"
		return PreparedAttack.new(sequence, rock_throw_damage, interval, ability, ability)
	return PreparedAttack.new(sequence, sequence_damage, interval)

static func legacy(balance: BalanceConfig) -> EnemyDefinition:
	var definition := EnemyDefinition.new()
	definition.max_hp = balance.enemy_hp
	definition.attack_damage = balance.enemy_attack_damage
	definition.attack_interval_triples = balance.enemy_attack_interval
	return definition
