extends SceneTree

var failures := 0
var catalog: RunDefinition = load("res://resources/runs/m4_run.tres")

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func spell(events: Array[Dictionary]) -> Dictionary:
	for event in events:
		if event.type == "spell_resolved": return event
	return {}

func mirror_battle() -> BattleModel:
	var enemy := EnemyDefinition.new()
	enemy.max_hp = 200
	enemy.attack_damage = 0
	enemy.attack_interval_triples = 3
	return BattleModel.new(BalanceConfig.new(), enemy, [catalog.relic_by_id("mirror_charm")])

func _initialize() -> void:
	var brute := BattleModel.new(BalanceConfig.new(), EnemyCatalog.by_id("stone_brute"))
	var fire := spell(brute.apply_triple("fire"))
	var lightning := spell(brute.apply_triple("lightning"))
	check(brute.enemy_armor == 2 and fire.hp_damage == 4 and lightning.hp_damage == 5,
		"1 Stone Brute: Armor 2 reduces Fire 6 to 4; Lightning 5 bypasses")

	var mirror := mirror_battle()
	mirror.core_hp = 20
	var early := spell(mirror.apply_triple("shield"))
	mirror.core_hp = 8
	mirror.core_shield = 0
	var later := spell(mirror.apply_triple("fire"))
	check(not early.activated_relics.has("mirror_charm") and mirror.relic_state.total_triples == 2
		and later.activated_relics.has("mirror_charm") and later.healing == 6 and later.shield_gained == 6
		and mirror.core_hp == 14 and mirror.core_shield == 6,
		"2 Mirror Ward activates later when a Triple begins at 10 HP or less")

	mirror.core_hp = 8
	mirror.core_shield = 0
	var repeated := spell(mirror.apply_triple("ice"))
	check(not repeated.activated_relics.has("mirror_charm") and repeated.healing == 0
		and repeated.shield_gained == 0 and mirror.core_hp == 8 and mirror.core_shield == 0
		and mirror.relic_state.activation_counts.get("mirror_charm", 0) == 1,
		"3 Mirror Ward activates only once per encounter")

	TranslationServer.set_locale("ru")
	var view: GameView = load("res://scenes/main/main.tscn").instantiate()
	var copy_ok := tr("M7A_STONE_BRUTE_MECHANIC") == "Броня 2. Молния её пробивает."
	copy_ok = copy_ok and tr("M7A_CAVE_WISP_MECHANIC") == "Уязвим к Льду: получает +3 урона."
	copy_ok = copy_ok and tr("M6_RELIC_MIRROR_CHARM_DESC") == "При 10 HP или меньше следующая Тройка один раз за бой восстанавливает 6 HP и даёт 6 Щита."
	copy_ok = copy_ok and tr("M8UX_RUNE_ICE_DESC") == "Наносит 3 урона. Если до атаки осталось 1–2 Тройки, замораживает и отменяет её."
	copy_ok = copy_ok and view.prepared_attack_text({"damage":8, "countdown":3, "kind":"enemy_attack", "frozen":false}) == "Удар 8 · через 3 Тройки"
	copy_ok = copy_ok and view.prepared_attack_text({"damage":8, "countdown":1, "kind":"enemy_attack", "frozen":true}) == "Удар 8 · через 1 Тройку · ЗАМОРОЖЕН"
	check(copy_ok, "4 RU copy smoke: enemies, Mirror, Ice Rune and attack intent")
	view.free()
	print("M8.1: 4 targeted scenarios — ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
