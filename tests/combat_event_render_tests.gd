extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	if value: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var scene: GameView = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	scene.game.play()
	await process_frame
	scene.show_combat_feedback({"type":"damage", "target":"enemy", "value":4, "effect":"fire"})
	scene.show_combat_feedback({"type":"boss_telegraph", "ability":"heavy_attack"})
	scene.show_combat_feedback({"type":"defeat", "target":"core"})
	scene.show_combat_feedback({"type":"schema_probe"})
	scene.queue_redraw()
	await process_frame
	await process_frame
	check(scene.combat_events.any(func(event): return event.get("type", "") == "damage" and event.get("target", "") == "enemy"), "feedback queue accepts targeted events")
	check(scene.combat_events.any(func(event): return event.get("type", "") == "boss_telegraph" and event.get("target", "") == ""), "boss telegraph remains valid without target")
	check(scene.combat_events.any(func(event): return event.get("type", "") == "defeat"), "defeat event renders safely")
	scene.queue_free()
	print("\n", "ALL COMBAT EVENT RENDER TESTS PASSED" if failures == 0 else "%d COMBAT EVENT RENDER TESTS FAILED" % failures)
	quit(failures)
