class_name GameView
extends Control

const SettingsStateScript := preload("res://scripts/core/settings_state.gd")

@onready var game: GameController = $GameController
@onready var run_controller: RunController = $RunController
@onready var level_label: Label = $Center/Content/HUD/Rows/Level
@onready var remaining_label: Label = $Center/Content/HUD/Rows/Remaining
@onready var tray_label: Label = $Center/Content/TrayLabel
@onready var board_space: Control = $Center/Content/BoardSpace
@onready var battle_space: Control = $Center/Content/BattleSpace
@onready var tray_space: Control = $Center/Content/TraySpace
@onready var content: VBoxContainer = $Center/Content
@onready var hud: MarginContainer = $Center/Content/HUD
@onready var overlay: ColorRect = $ResultOverlay
@onready var result_title: Label = $ResultOverlay/Center/Panel/Title
@onready var result_subtitle: Label = $ResultOverlay/Center/Panel/Subtitle
@onready var audio: Node = $AudioManager
@export var visual_library: VisualLibrary
var settings = SettingsStateScript.new()
var definitions := {}
var flights: Array = []
var triple_type := ""
var triple_time := 0.0
var revealed_tile_id := -1
var reveal_time := 0.0
var layout_refresh_pending := false
var layout_refresh_count := 0
var combat_events: Array = []
var campaign_visible := false
var settings_visible := false
var ambience_time := 0.0
var last_music_context := ""
var intro_time := 0.0
var intro_level := -1
var previous_state := ""
var visual_encounter_id := ""
var abandon_run_id := ""

func _ready() -> void:
	TranslationServer.set_locale("ru")
	definitions = TileCatalog.all()
	game.state_changed.connect(update_view)
	game.tile_moving.connect(show_tile_flight)
	game.triple_resolved.connect(show_triple)
	game.combat_feedback.connect(show_combat_feedback)
	game.progress_changed.connect(update_view)
	run_controller.state_changed.connect(update_view)
	$ResultOverlay/Center/Panel/Restart.pressed.connect(restart_command)
	$ResultOverlay/Center/Panel/Next.pressed.connect(continue_command)
	$ResultOverlay/Center/Panel/Menu.pressed.connect(menu_command)
	$MainMenu/Center/Panel/Play.pressed.connect(new_run_command)
	$OfferOverlay.exit_requested.connect(menu_command)
	$OfferOverlay.build_requested.connect(show_current_build)
	# Legacy campaign remains available in code/data, not in the player-facing menu.
	$MainMenu/Center/Panel/Settings.pressed.connect(show_settings)
	$CampaignOverlay/Center/Panel/Back.pressed.connect(hide_campaign)
	$SettingsOverlay/Center/Panel/Back.pressed.connect(hide_settings)
	$SettingsOverlay/Center/Panel/Music.value_changed.connect(set_music_volume)
	$SettingsOverlay/Center/Panel/SFX.value_changed.connect(set_sfx_volume)
	$PauseButton.pressed.connect(game.pause_game)
	$PauseOverlay/Center/Panel/Continue.pressed.connect(game.continue_game)
	$PauseOverlay/Center/Panel/Restart.pressed.connect(game.restart)
	$PauseOverlay/Center/Panel/Build.pressed.connect(show_current_build)
	$PauseOverlay/Center/Panel/Menu.pressed.connect(menu_command)
	$BuildButton.pressed.connect(show_current_build)
	$InfoOverlay.close_requested.connect($InfoOverlay.hide_modal)
	$AbandonOverlay/Center/Panel/Confirm.pressed.connect(confirm_abandon)
	$AbandonOverlay/Center/Panel/Cancel.pressed.connect(cancel_abandon)
	resized.connect(request_layout_refresh)
	for region in [board_space, battle_space, tray_space]:
		region.item_rect_changed.connect(queue_redraw)
	settings.load_file()
	$SettingsOverlay/Center/Panel/Music.value = settings.music_volume
	$SettingsOverlay/Center/Panel/SFX.value = settings.sfx_volume
	apply_audio_settings()
	install_visual_theme()
	build_rune_buttons()
	build_campaign_buttons()
	connect_button_feedback(self)
	request_layout_refresh()
	update_view()

func restart_command() -> void:
	if game.run_mode: new_run_command()
	else: game.restart_action()

func new_run_command() -> void:
	$MainMenu/Center/Panel/Subtitle.visible = false
	if not run_controller.new_run() and not run_controller.validation_errors.is_empty():
		$MainMenu/Center/Panel/Subtitle.visible = true
		$MainMenu/Center/Panel/Subtitle.text = tr("M4_CONFIG_ERROR") + "\n" + "\n".join(run_controller.validation_errors)

func continue_command() -> void:
	if game.run_mode: run_controller.continue_run()
	else: game.next_level()

func menu_command() -> void:
	if game.run_mode and run_controller.run.is_active():
		abandon_run_id = run_controller.run.run_instance_id
		$AbandonOverlay.visible = true
	else: game.show_main_menu()

func confirm_abandon() -> void:
	run_controller.abandon_run(abandon_run_id)
	cancel_abandon()

func cancel_abandon() -> void:
	abandon_run_id = ""
	$AbandonOverlay.visible = false

func build_rune_buttons() -> void:
	var bar: HBoxContainer = $Center/Content/HUD/Rows/RuneBar
	for type_id in ["fire", "ice", "lightning", "wind", "life", "shield"]:
		var definition: TileDefinition = definitions[type_id]
		var button := Button.new()
		button.name = type_id.capitalize()
		button.text = tr(definition.name_key).substr(0, 1)
		button.tooltip_text = tr(definition.name_key)
		button.custom_minimum_size = Vector2(42, 32)
		button.set_meta("rune_type", type_id)
		button.pressed.connect(show_rune_info.bind(type_id))
		bar.add_child(button)

func show_current_build() -> void:
	if not game.run_mode or not run_controller.run.is_active(): return
	$InfoOverlay.show_build(run_controller)

func show_rune_info(type_id: String) -> void:
	if not definitions.has(type_id): return
	$InfoOverlay.show_rune(definitions[type_id], tr("M8UX_RUNE_" + type_id.to_upper() + "_DESC"))

func background_location() -> String:
	if game.run_mode and run_controller.run.is_active(): return run_controller.chapter().presentation
	if game.current_level and game.state != "menu": return presentation_location()
	return ""

func presentation_location() -> String:
	return run_controller.chapter().presentation if game.run_mode else game.current_level.location_id

func build_campaign_buttons()->void:
	for index in game.levels.size():
		var button:=Button.new();button.custom_minimum_size=Vector2(88,58);button.tooltip_text=tr(game.levels[index].name_key)
		button.set_meta("sfx_kind","level_select")
		button.pressed.connect(func(): if game.start_campaign_level(index): campaign_visible=false; update_view())
		var grid:GridContainer=$CampaignOverlay/Center/Panel/StoneGrid if index<10 else $CampaignOverlay/Center/Panel/FrozenGrid
		grid.add_child(button)

func show_campaign()->void:
	campaign_visible=true;update_view()

func hide_campaign()->void:
	campaign_visible=false;update_view()

func show_settings() -> void:
	settings_visible = true
	update_view()

func hide_settings() -> void:
	settings_visible = false
	settings.save_file()
	update_view()

func set_music_volume(value: float) -> void:
	settings.music_volume = value
	apply_bus_volume("Music", value)

func set_sfx_volume(value: float) -> void:
	settings.sfx_volume = value
	apply_bus_volume("SFX", value)

func apply_audio_settings() -> void:
	apply_bus_volume("Music", settings.music_volume)
	apply_bus_volume("SFX", settings.sfx_volume)

func apply_bus_volume(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value / 100.0, 0.0001)))
		AudioServer.set_bus_mute(index, value <= 0.0)

func install_visual_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 18
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("14243b")
	normal.border_color = Color("35536f")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	var hover := normal.duplicate()
	hover.bg_color = Color("1b3650")
	hover.border_color = Color("51b8c8")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("0c182a")
	pressed.border_color = Color("7ad9df")
	var disabled := normal.duplicate()
	disabled.bg_color = Color("111827")
	disabled.border_color = Color("273449")
	ui_theme.set_stylebox("normal", "Button", normal)
	ui_theme.set_stylebox("hover", "Button", hover)
	ui_theme.set_stylebox("pressed", "Button", pressed)
	ui_theme.set_stylebox("disabled", "Button", disabled)
	ui_theme.set_color("font_color", "Button", Color("dceafb"))
	ui_theme.set_color("font_disabled_color", "Button", Color("667388"))
	theme = ui_theme

func connect_button_feedback(root: Node) -> void:
	for child in root.get_children():
		if child is Button:
			child.button_down.connect(audio.unlock_audio)
			child.mouse_entered.connect(animate_button.bind(child, 1.025, null))
			child.mouse_exited.connect(animate_button.bind(child, 1.0, null))
			var press_stream:AudioStream=audio.level_select if child.get_meta("sfx_kind","")=="level_select" else (audio.button_back if child.name in ["Back","Menu"] else audio.button_click)
			child.button_down.connect(animate_button.bind(child, 0.975, press_stream))
			child.button_up.connect(animate_button.bind(child, 1.025, null))
		connect_button_feedback(child)

func animate_button(button: Button, scale_value: float, stream: AudioStream) -> void:
	button.pivot_offset = button.size * 0.5
	button.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(button, "scale", Vector2.ONE * scale_value, 0.12)
	audio.play_ui(stream)

func update_campaign_buttons()->void:
	game.ensure_progress()
	var buttons:Array=[];buttons.append_array($CampaignOverlay/Center/Panel/StoneGrid.get_children());buttons.append_array($CampaignOverlay/Center/Panel/FrozenGrid.get_children())
	for index in buttons.size():
		var marker:=" ◆" if game.levels[index].milestone=="boss" else (" ◇" if game.levels[index].milestone=="mini_boss" else "")
		buttons[index].text=("✓ " if game.progress.completed_level_ids.has(game.levels[index].id) else "")+str(index+1)+marker
		buttons[index].disabled=not game.progress.is_unlocked(index)
		buttons[index].modulate=Color("8fe1d3") if game.progress.completed_level_ids.has(game.levels[index].id) else (Color("ffd47a") if game.levels[index].milestone=="boss" else (Color("b7a8ff") if game.levels[index].milestone=="mini_boss" else Color.WHITE))
	$CampaignOverlay/Center/Panel/Location2.modulate=Color.WHITE if game.progress.has_location_two() else Color(.45,.5,.6,1)
	var stone_done := 0
	var frozen_done := 0
	for level_id in game.progress.completed_level_ids:
		var number := int(str(level_id).trim_prefix("level_"))
		if number <= 10: stone_done += 1
		else: frozen_done += 1
	$CampaignOverlay/Center/Panel/Location1.text = tr("UI_STONE_PROGRESS") % stone_done
	$CampaignOverlay/Center/Panel/Location2.text = tr("UI_FROZEN_PROGRESS") % frozen_done
	$MainMenu/Center/Panel/Relics.text="%s %d/2"%[tr("UI_RELICS"),game.progress.relic_ids.size()]
	$MainMenu/Center/Panel/RelicHelp.text=tr("UI_RELICS_HELP")
	$CampaignOverlay/Center/Panel/RelicSection.text=tr("UI_RELICS")
	$CampaignOverlay/Center/Panel/GolemRelic.text="%s — %s\n%s\n%s"%[tr("RELIC_GOLEM_HEART"),tr("ENEMY_STONE_GOLEM"),tr("RELIC_GOLEM_HEART_DESC"),tr("UI_RELIC_OBTAINED") if game.progress.relic_ids.has("golem_heart") else tr("UI_RELIC_LOCKED")]
	$CampaignOverlay/Center/Panel/CrownRelic.text="%s — %s\n%s\n%s"%[tr("RELIC_FROZEN_CROWN"),tr("ENEMY_FROST_WITCH"),tr("RELIC_FROZEN_CROWN_DESC"),tr("UI_RELIC_OBTAINED") if game.progress.relic_ids.has("frozen_crown") else tr("UI_RELIC_LOCKED")]

func layout_mode_for_size(viewport_size: Vector2) -> String:
	return "wide" if viewport_size.x / maxf(viewport_size.y, 1.0) >= 1.2 else "portrait"

func request_layout_refresh() -> void:
	if layout_refresh_pending: return
	layout_refresh_pending = true
	call_deferred("refresh_layout")

func refresh_layout() -> void:
	var wide := layout_mode_for_size(size) == "wide"
	var target_width := minf(size.x, 480.0 if wide else 720.0)
	var hud_height := 148.0 if wide else 190.0
	var tray_height := 84.0 if wide else 104.0
	var battle_height := 156.0 if wide else 180.0
	var board_height := maxf(360.0, size.y - hud_height - battle_height - tray_height - 50.0)
	content.custom_minimum_size = Vector2(target_width, minf(size.y, hud_height + battle_height + board_height + tray_height + 38.0))
	hud.custom_minimum_size.y = hud_height
	battle_space.custom_minimum_size.y = battle_height
	board_space.custom_minimum_size.y = board_height
	tray_space.custom_minimum_size.y = tray_height
	await get_tree().process_frame
	if game.run_mode:
		# Measure the translated run HUD after wrapping before allocating the Board.
		# Keep the complete Rune Row on screen, including in short wide viewports.
		board_space.custom_minimum_size.y = maxf(180.0, size.y - hud.size.y - battle_height - tray_height - 46.0)
		content.custom_minimum_size.y = size.y
	layout_refresh_pending = false
	layout_refresh_count += 1
	if game.tray: tray_label.text = row_caption(game.tray.tiles.size(), game.tray.capacity, tray_label.size.x)
	queue_redraw()

func row_caption(used: int, capacity: int, available_width: float) -> String:
	var caption := "%s %d/%d" % [tr("UI_TRAY"), used, capacity]
	if capacity - used == 1:
		var warning := caption + " · " + tr("UI_ONE_SLOT_LEFT")
		var width := tray_label.get_theme_font("font").get_string_size(warning, HORIZONTAL_ALIGNMENT_LEFT, -1, tray_label.get_theme_font_size("font_size")).x
		if available_width >= width: return warning
	return caption

func enemy_defense_text(combat: Dictionary) -> Dictionary:
	return {"armor":tr("UI_ENEMY_ARMOR_VALUE") % combat.enemy_armor if combat.enemy_armor > 0 else "",
		"shield":tr("UI_ENEMY_SHIELD_VALUE") % combat.enemy_shield if combat.enemy_shield > 0 else ""}

func update_view() -> void:
	if visual_encounter_id != game.encounter_instance_id or game.board == null:
		visual_encounter_id = game.encounter_instance_id
		flights.clear(); combat_events.clear()
		triple_time = 0.0; reveal_time = 0.0; revealed_tile_id = -1
		intro_time = 0.0; intro_level = -1
		cancel_abandon()
		request_layout_refresh()
	$Center/Content/HUD/Rows/Title.visible = not game.run_mode
	var mechanic_key := game.battle.current_enemy.phase_mechanic_key(game.battle.current_phase_index) if game.battle else ""
	$Center/Content/HUD/Rows/EnemyMechanic.visible = not mechanic_key.is_empty()
	$Center/Content/HUD/Rows/EnemyMechanic.text = tr(mechanic_key) if not mechanic_key.is_empty() else ""
	if game.battle:
		var combat_hud := game.battle.hud_data()
		var next_attack: Dictionary = combat_hud.next_attack
		if not str(next_attack.name_key).is_empty():
			$Center/Content/HUD/Rows/EnemyMechanic.text += " · " + tr("M9B_NEXT_ATTACK") % tr(next_attack.name_key)
		var vulnerability: Dictionary = combat_hud.vulnerability
		if not vulnerability.is_empty():
			$Center/Content/HUD/Rows/EnemyMechanic.text += "\n" + tr("M9C_VULNERABILITY_HUD") % [
				tr("M9C_RUNE_" + str(vulnerability.current).to_upper()), vulnerability.bonus,
				tr("M9C_RUNE_" + str(vulnerability.next).to_upper()), vulnerability.remaining,
				triple_count_word(vulnerability.remaining)]
	update_campaign_buttons()
	$MainMenu.visible = game.state == "menu" and not campaign_visible
	$CampaignOverlay.visible=game.state=="menu" and campaign_visible
	$SettingsOverlay.visible=game.state=="menu" and settings_visible
	$MainMenu.visible = game.state == "menu" and not campaign_visible and not settings_visible
	$PauseOverlay.visible = game.state == "paused"
	$PauseButton.visible = game.state == "playing"
	var active_run := game.run_mode and run_controller.run.is_active()
	$BuildButton.visible = active_run and game.state == "playing" and not $OfferOverlay.visible
	$BuildButton.text = tr("M8UX_RELIC_COUNT") % run_controller.run.acquired_relic_ids.size()
	$PauseOverlay/Center/Panel/Build.visible = active_run
	$PauseOverlay/Center/Panel/Build.text = tr("M8UX_RELIC_COUNT") % run_controller.run.acquired_relic_ids.size()
	$Center/Content/HUD/Rows/RuneBar.visible = active_run and game.state == "playing"
	if game.state == "menu" or not active_run: $InfoOverlay.hide_modal()
	$PauseOverlay/Center/Panel/Restart.visible = not game.run_mode
	$PauseOverlay/Center/Panel/Menu.text = tr("UI_END_RUN") if game.run_mode else tr("UI_MAIN_MENU")
	overlay.visible = game.state in ["won", "milestone", "campaign_complete", "lost", "exhausted"]
	$OfferOverlay.refresh(run_controller)
	$BuildButton.visible = active_run and game.state == "playing" and not $OfferOverlay.visible
	# Keep the real last battle visible beneath run modals; the modal layers own input.
	$Center.visible = game.state != "menu" and game.board != null
	if $OfferOverlay.visible: overlay.visible = false
	if game.board == null:
		update_music_flow();queue_redraw(); return
	if game.state == "playing" and game.current_level_index != intro_level and game.current_level.milestone in ["boss", "mini_boss"]:
		intro_level = game.current_level_index;intro_time = 1.2
		if game.current_level.milestone=="boss":audio.play_sfx(audio.boss_intro)
	level_label.text = "%s/%d" % [tr(game.current_level.name_key), game.levels.size()]
	remaining_label.text = "%s: %d" % [tr("UI_TILES_LEFT"), game.board.remaining_count()]
	tray_label.text = row_caption(game.tray.tiles.size(), game.tray.capacity, tray_label.size.x)
	# One Label owns both captions, so the warning cannot overlap the Row title.
	if game.tray.capacity - game.tray.tiles.size() == 1:
		tray_label.modulate = Color("f2b15e")
	else: tray_label.modulate = Color.WHITE
	$ResultOverlay/Center/Panel/Next.visible = game.state in ["won","milestone"]
	$ResultOverlay/Center/Panel/Next.text=tr("UI_CONTINUE") if game.state=="milestone" else tr("UI_NEXT_LEVEL")
	$ResultOverlay/Center/Panel/Menu.visible = game.state in ["milestone","campaign_complete"]
	result_subtitle.text=""
	if game.state=="milestone":result_subtitle.text=tr("UI_GOLEM_REWARD")
	elif game.state=="campaign_complete":result_subtitle.text=tr("UI_WITCH_REWARD")
	elif game.state=="won" and game.current_level.milestone=="mini_boss":result_subtitle.text=tr("UI_MINIBOSS_DEFEATED")
	$ResultOverlay/Center/Panel/Restart.text = tr("UI_REPLAY_CAMPAIGN") if game.state == "campaign_complete" else tr("UI_RESTART")
	if game.state == "campaign_complete": result_title.text = tr("UI_CAMPAIGN_COMPLETE")
	elif game.state=="milestone":result_title.text=tr("UI_GOLEM_DEFEATED")
	elif game.state == "won": result_title.text = tr("UI_LEVEL_COMPLETE")
	elif game.state == "exhausted": result_title.text = tr("UI_NOT_ENOUGH_POWER")
	else: result_title.text = tr("UI_DEFEAT")
	if game.state == "lost": result_subtitle.text = tr("UI_CORE_DESTROYED") if game.battle.core_hp <= 0 else tr("UI_TRAY_OVERFLOW")
	elif game.state == "exhausted": result_subtitle.text = tr("UI_BOARD_EXHAUSTED")
	$ResultOverlay/Center/Panel/Restart.visible = true
	$ResultOverlay/Center/Panel/Menu.text = tr("UI_MAIN_MENU")
	if game.run_mode: update_run_view()
	if game.state != previous_state:
		if game.state=="won":audio.play_sfx(audio.victory)
		elif game.state in ["milestone","campaign_complete"]:audio.play_sfx(audio.relic_unlock)
		elif game.state in ["lost", "exhausted"]: audio.play_sfx(audio.defeat)
	previous_state = game.state
	update_music_flow()
	queue_redraw()

func update_run_view() -> void:
	var run := run_controller.run
	level_label.text = "%s\n%s · %s" % [tr(run_controller.chapter().name_key),
		tr("UI_RUN_BATTLE") % [run.current_slot_index + 1, run_controller.definition.slots.size()],
		tr("UI_RUN_ROLE_" + run_controller.role().to_upper())]
	overlay.visible = run.status in [RunState.Status.BETWEEN_ENCOUNTERS, RunState.Status.VICTORY, RunState.Status.DEFEAT]
	if overlay.visible:
		intro_time = 0.0; flights.clear(); combat_events.clear()
		triple_time = 0.0; reveal_time = 0.0
	$ResultOverlay/Center/Panel/Next.visible = run.status == RunState.Status.BETWEEN_ENCOUNTERS
	$ResultOverlay/Center/Panel/Next.text = tr("UI_CONTINUE")
	$ResultOverlay/Center/Panel/Restart.visible = run.status in [RunState.Status.VICTORY, RunState.Status.DEFEAT]
	$ResultOverlay/Center/Panel/Restart.text = tr("UI_NEW_RUN")
	$ResultOverlay/Center/Panel/Menu.visible = true
	$ResultOverlay/Center/Panel/Menu.text = tr("UI_END_RUN") if run.is_active() else tr("UI_MAIN_MENU")
	result_title.text = tr("UI_RUN_COMPLETE") if run.status == RunState.Status.VICTORY else tr("UI_DEFEAT" if run.status == RunState.Status.DEFEAT else "UI_RUN_VICTORY")
	result_subtitle.text = tr("UI_RUN_SUMMARY") % [run.completed_encounters, run_controller.definition.slots.size(), run.boundary_hp]
	if run.status == RunState.Status.DEFEAT:
		result_subtitle.text = tr("UI_RUN_" + run.defeat_reason) + "\n" + result_subtitle.text
	elif run.status == RunState.Status.BETWEEN_ENCOUNTERS and run_controller.definition.is_chapter_end(run.current_slot_index):
		result_subtitle.text = tr("UI_RUN_CHAPTER_COMPLETE") % tr(run_controller.chapter().name_key) + "\n" + result_subtitle.text

func update_music_flow() -> void:
	var context := "menu"
	if game.board != null and game.current_level:
		context = presentation_location()
	if context == last_music_context:
		return
	last_music_context = context
	audio.play_music(audio.frozen_grove_music if context == "frozen_grove" else (audio.stone_ruins_music if context == "stone_ruins" else audio.menu_music))

func board_rect() -> Rect2:
	return Rect2(board_space.global_position, board_space.size)

func battle_rect() -> Rect2:
	return Rect2(battle_space.global_position, battle_space.size)

func tray_rect() -> Rect2:
	var outer := Rect2(tray_space.global_position, tray_space.size)
	var width := minf(outer.size.x - 24.0, 672.0)
	var vertical_padding := 20.0 if game.run_mode else 12.0
	return Rect2(outer.position + Vector2((outer.size.x - width) * 0.5, 6.0), Vector2(width, minf(96.0, outer.size.y - vertical_padding)))

func tile_rect(tile: TilePlacement) -> Rect2:
	var outer := board_rect()
	var scale_factor := minf((outer.size.x - 30.0) / game.current_level.design_size.x, (outer.size.y - 24.0) / game.current_level.design_size.y)
	var design_origin := outer.position + (outer.size - game.current_level.design_size * scale_factor) * 0.5
	var tile_size := game.current_level.tile_size * scale_factor
	var depth := maxi(0, game.board.visual_depth(tile.tile_id))
	var fan_offset := Vector2(depth * 7.0, depth * 29.0) * scale_factor
	return Rect2(design_origin + tile.position * scale_factor + fan_offset - tile_size * 0.5, tile_size)

func tray_slot_rect(index: int) -> Rect2:
	var rect := tray_rect(); var gap := 6.0
	var width := (rect.size.x - gap * (game.tray.capacity - 1)) / game.tray.capacity
	return Rect2(rect.position + Vector2(index * (width + gap), 0), Vector2(width, rect.size.y))

func pick_tile(point: Vector2) -> int:
	var candidates: Array = game.board.active.values()
	candidates.sort_custom(func(a, b): return a.layer > b.layer)
	for tile in candidates:
		if tile_rect(tile).has_point(point) and game.board.is_available(tile.tile_id): return tile.tile_id
	return -1

func _gui_input(event: InputEvent) -> void:
	var pressed := false; var point := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true; point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true; point = event.position
	if pressed: audio.unlock_audio()
	if not pressed or game.state != "playing" or game.busy or $InfoOverlay.visible or $OfferOverlay.visible: return
	var tile_id := pick_tile(point)
	if tile_id >= 0: game.select_tile(tile_id)

func _unhandled_key_input(event:InputEvent)->void:
	if game.run_mode: return
	if not OS.is_debug_build() or not event.pressed or event.echo:return
	if event.keycode==KEY_PAGEUP:game.start_level(mini(game.current_level_index+1,game.levels.size()-1))
	elif event.keycode==KEY_PAGEDOWN:game.start_level(maxi(game.current_level_index-1,0))

func show_tile_flight(tile: TilePlacement, insert_index: int) -> void:
	var next := game.board.top_tile(tile.stack_id)
	if next: revealed_tile_id = next.tile_id; reveal_time = 0.22
	flights.append({"type_id":tile.type_id, "from":tile_rect(tile).get_center(), "slot":insert_index, "age":0.0})
	audio.play_sfx(audio.tile_pick)
	queue_redraw()

func show_triple(type_id: String) -> void:
	triple_type = type_id; triple_time = game.balance.triple_pop_duration
	audio.play_sfx(audio.element_stream(type_id));audio.play_sfx(audio.triple_complete)
	queue_redraw()

func show_combat_feedback(event: Dictionary) -> void:
	var visual := event.duplicate(); visual.age = 0.0
	combat_events.append(visual)
	var event_type:=str(event.get("type",""))
	if event_type=="damage":audio.play_sfx(audio.enemy_hit)
	elif event_type=="enemy_attack":audio.play_sfx(audio.core_hit)
	elif event_type=="enemy_defeated":audio.play_sfx(audio.enemy_death)
	queue_redraw()

func _process(delta: float) -> void:
	ambience_time += delta
	$MainMenu/Center/Panel/Title.modulate=Color(0.86+sin(ambience_time*1.4)*.06,0.94,1.0,1.0)
	for flight in flights: flight.age += delta
	flights = flights.filter(func(flight): return flight.age < game.balance.tile_move_duration)
	if triple_time > 0.0: triple_time -= delta
	if reveal_time > 0.0: reveal_time -= delta
	if intro_time > 0.0: intro_time -= delta
	for event in combat_events: event["age"] = float(event.get("age", 0.0)) + delta
	combat_events = combat_events.filter(func(event): return float(event.get("age", 0.0)) < .75)
	if game.state == "menu" or intro_time > 0.0 or not flights.is_empty() or triple_time > 0.0 or reveal_time > 0.0 or not combat_events.is_empty(): queue_redraw()

func _draw() -> void:
	draw_screen_background()
	if game.board == null or not $Center.visible: return
	draw_battle()
	draw_rect(board_rect(), Color("102338") if presentation_location()=="frozen_grove" else Color("0c1626"), true)
	draw_board_tiles()
	draw_tray()
	for flight in flights:
		var progress: float = clampf(flight.age / game.balance.tile_move_duration, 0.0, 1.0)
		var target := tray_slot_rect(mini(flight.slot, game.tray.capacity - 1)).get_center()
		var center: Vector2 = flight.from.lerp(target, ease(progress, -1.6))
		draw_tile(flight.type_id, Rect2(center - Vector2(38,44), Vector2(76,88)), true, 1.0 + sin(progress * PI) * .07)
	if intro_time > 0.0: draw_milestone_intro()

func draw_milestone_intro() -> void:
	var alpha:=clampf(intro_time*2.5,0.0,1.0);var panel:=Rect2(size*Vector2(.12,.35),size*Vector2(.76,.22))
	draw_style_panel(panel,Color(0.025,0.045,0.08,.94*alpha),Color(0.3,0.78,0.85,alpha),3,16)
	var heading:=tr("UI_BOSS") if game.current_level.milestone=="boss" else tr("UI_MINIBOSS")
	draw_string(ThemeDB.fallback_font,panel.position+Vector2(0,58),heading,HORIZONTAL_ALIGNMENT_CENTER,panel.size.x,28,Color(0.48,0.9,0.96,alpha))
	draw_string(ThemeDB.fallback_font,panel.position+Vector2(0,108),tr(game.battle.current_enemy.name_key),HORIZONTAL_ALIGNMENT_CENTER,panel.size.x,34,Color(0.95,0.9,0.75,alpha))

func draw_screen_background() -> void:
	var texture:Texture2D=visual_library.main_menu_background if visual_library else null
	var location := background_location()
	var cold := location == "frozen_grove"
	if not location.is_empty():
		if visual_library:texture=visual_library.frozen_grove_background if cold else visual_library.stone_ruins_background
	if texture:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), true, Color.WHITE)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("071222") if cold else Color("090f1d"), true)
		for i in 8:
			var center := Vector2(size.x * (0.08 + i * 0.13), size.y * (0.15 + fmod(i * 0.19, 0.7)))
			draw_circle(center, 90.0 + i * 13.0, Color(0.05, 0.22 if cold else 0.14, 0.28, 0.025))
	if game.state == "menu":
		for i in 14:
			var x := fmod(i * 97.0 + ambience_time * (4.0 + i % 3), maxf(size.x, 1.0))
			var y := fmod(i * 149.0 - ambience_time * (7.0 + i % 4), maxf(size.y, 1.0))
			draw_circle(Vector2(x, y), 1.5 + i % 2, Color(0.35, 0.85, 0.95, 0.18 + 0.04 * sin(ambience_time + i)))

func draw_battle() -> void:
	var rect := battle_rect()
	draw_style_panel(rect.grow(-8.0), Color("0d192a"), Color("344f69"), 2.0, 14.0)
	if game.battle == null: return
	var combat := game.battle.hud_data()
	var compact := rect.size.y < 160.0
	var header_y := rect.position.y + 25.0
	var name_y := rect.position.y + (44.0 if compact else 50.0)
	var actor_y := rect.position.y + (84.0 if compact else 104.0)
	var status_y := rect.end.y - 13.0
	var core_pos := Vector2(rect.position.x + rect.size.x * .18, actor_y)
	var enemy_pos := Vector2(rect.position.x + rect.size.x * .82, actor_y)
	for feedback in combat_events:
		var feedback_age:=float(feedback.get("age",0.0));var feedback_type:=str(feedback.get("type",""))
		if feedback_type=="enemy_attack" and feedback_age<.22:core_pos.x+=sin(feedback_age*95.0)*5.0
		elif feedback_type=="damage" and feedback_age<.18:enemy_pos.x+=sin(feedback_age*110.0)*4.0
	var core_pulse:=1.0+sin(ambience_time*(5.5 if game.battle.core_hp<game.balance.core_max_hp*.25 else 2.2))*.035
	var core_rect:=Rect2(core_pos-Vector2.ONE*34.0*core_pulse,Vector2.ONE*68.0*core_pulse)
	if visual_library and visual_library.core_glow_texture:draw_texture_rect(visual_library.core_glow_texture,core_rect.grow(12),false,Color(0.4,1.0,.8,.55))
	if visual_library and visual_library.core_texture:draw_texture_rect(visual_library.core_texture,core_rect,false)
	else:draw_circle(core_pos,31.0*core_pulse,Color("214f59"));draw_circle(core_pos,24.0*core_pulse,Color("55c98d"));draw_circle(core_pos-Vector2(7,8),8.0,Color("c9fff0"))
	if game.battle.core_shield > 0:
		if visual_library and visual_library.shield_overlay_texture:draw_texture_rect(visual_library.shield_overlay_texture,core_rect.grow(10),false)
		else:draw_arc(core_pos,38.0,0,TAU,32,Color("72b7ff"),5.0)
	var enemy_color := game.battle.current_enemy.visual_color
	var enemy_scale:float=game.battle.current_enemy.boss_scale*(1.2 if game.battle.is_large_enemy() else 1.0)
	var enemy_rect:=Rect2(enemy_pos-Vector2(42,45)*enemy_scale,Vector2(84,90)*enemy_scale)
	if game.battle.current_enemy.texture:draw_texture_rect(game.battle.current_enemy.texture,enemy_rect,false)
	else:draw_enemy_placeholder(enemy_pos,enemy_color,enemy_scale,game.battle.is_boss(),game.battle.current_enemy.tags.has("mini_boss"))
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x+18,header_y), "%s %d/%d" % [tr("UI_CORE"), game.battle.core_hp, game.balance.core_max_hp], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * .44, 15, Color("d9f8e8"))
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x+rect.size.x*.48,header_y), "%s %d/%d · HP %d/%d" % [tr("UI_ENEMY"), game.current_enemy_number, game.encounter_total, combat.enemy_hp, combat.enemy_max_hp], HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x*.49-18, 15, Color("ffd9dc"))
	var core_bar := Rect2(core_pos + Vector2(-48,38), Vector2(96,7)); draw_rect(core_bar, Color("263247"), true); draw_rect(Rect2(core_bar.position, Vector2(core_bar.size.x * float(game.battle.core_hp)/game.balance.core_max_hp,7)), Color("55c98d"), true)
	var enemy_bar := Rect2(enemy_pos + Vector2(-48,38), Vector2(96,7)); draw_rect(enemy_bar, Color("3c2630"), true); draw_rect(Rect2(enemy_bar.position, Vector2(enemy_bar.size.x * float(game.battle.enemy_hp)/game.battle.current_enemy.max_hp,7)), enemy_color.lightened(.12), true)
	var enemy_caption := tr(game.battle.current_enemy.name_key)
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x+rect.size.x*.46,name_y), enemy_caption, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x*.51-18, 13 if compact else 15, Color("ffe8e8"))
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x+18,name_y), tr("UI_CORE_SHIELD_VALUE") % [combat.core_shield, combat.core_max_shield], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x*.35, 13, Color("8fdcff"))
	var defenses := enemy_defense_text(combat)
	if not defenses.armor.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x+rect.size.x*.36,actor_y-8), defenses.armor, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x*.30, 12, Color("c5cddd"))
	if not defenses.shield.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x+rect.size.x*.36,actor_y+10), defenses.shield, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x*.30, 12, Color("8fdcff"))
	var status := prepared_attack_text(combat.attack)
	var warning_color:=Color("8fdcff") if game.battle.enemy_frozen else (Color("f0b56a") if game.battle.enemy_action_counter==1 else Color("b7c5dc"))
	if not str(combat.attack.name_key).is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x+18,status_y-18), tr(combat.attack.name_key), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x-36, 13, Color("d9efff"))
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x+18,status_y), status, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x-36, 14 if compact else (15 if game.battle.enemy_action_counter==1 else 14), warning_color)
	for event in combat_events: draw_combat_event(event, core_pos, enemy_pos)

func prepared_attack_text(attack: Dictionary) -> String:
	var countdown: int = attack.countdown
	var text := tr("UI_PREPARED_ATTACK") % [attack.damage, countdown, triple_count_word(countdown)]
	if attack.kind == "lock_stack_request": text = tr("UI_PREPARED_LOCK") % attack.countdown
	if attack.frozen: text += " · " + tr("UI_FROZEN")
	return text

func triple_count_word(count: int) -> String:
	var last_two := count % 100
	if count % 10 == 1 and last_two != 11: return tr("UI_TRIPLE_ACCUSATIVE_ONE")
	if count % 10 in [2, 3, 4] and last_two not in [12, 13, 14]: return tr("UI_TRIPLE_GENITIVE_FEW")
	return tr("UI_TRIPLE_GENITIVE_MANY")

func draw_enemy_placeholder(center:Vector2,color:Color,scale_value:float,boss:bool,mini_boss:bool)->void:
	var body:=PackedVector2Array([center+Vector2(-34,32)*scale_value,center+Vector2(-29,-24)*scale_value,center+Vector2(-15,-42)*scale_value,center+Vector2(0,-48 if boss else -38)*scale_value,center+Vector2(20,-37)*scale_value,center+Vector2(34,30)*scale_value])
	draw_colored_polygon(body,color.darkened(.16));draw_polyline(body,color.lightened(.25),3.0)
	var eye:=Color("ffdf8a") if boss else Color("9feaff")
	draw_circle(center+Vector2(-10,-10)*scale_value,3.5*scale_value,eye);draw_circle(center+Vector2(10,-10)*scale_value,3.5*scale_value,eye)
	if boss or mini_boss:draw_arc(center,48*scale_value,PI*.1,PI*.9,18,Color("d9b76b") if boss else Color("9b8edb"),3)

func draw_combat_event(event: Dictionary, core_pos: Vector2, enemy_pos: Vector2) -> void:
	var event_type := str(event.get("type", ""))
	if event_type.is_empty(): return
	var age := float(event.get("age", 0.0))
	var alpha: float = 1.0 - age / .75
	var target_id := str(event.get("target", ""))
	var target: Vector2 = enemy_pos if target_id == "enemy" else core_pos
	# Separate simultaneous numeric components, without relic-specific UI branches.
	if event_type == "damage" and event.get("direct", false): target.y -= 22.0
	elif event_type == "shield": target.y += 22.0
	var value := int(event.get("value", 0))
	var color := Color("ffd064")
	if event.get("effect", "") == "ice": color = Color("80d9ff")
	elif event.get("effect", "") == "fire": color = Color("ff805e")
	elif event.get("effect", "") == "wind": color = Color("74dda0")
	if event_type == "damage":
		draw_line(core_pos.lerp(enemy_pos, clampf(age*7.0,0.0,1.0)), enemy_pos, Color(color, alpha), 4.0)
		draw_string(ThemeDB.fallback_font, target + Vector2(-28,-38-age*25), "-%d" % value, HORIZONTAL_ALIGNMENT_CENTER, 56, 20, Color(color,alpha))
	elif event_type in ["heal","shield"]:
		draw_string(ThemeDB.fallback_font, target + Vector2(-34,-38-age*25), "+%d" % value, HORIZONTAL_ALIGNMENT_CENTER, 68, 20, Color("79efad",alpha))
	elif event_type == "enemy_attack":
		draw_string(ThemeDB.fallback_font, target + Vector2(-32,-38-age*25), "-%d" % value, HORIZONTAL_ALIGNMENT_CENTER, 64, 20, Color("ff8b8b",alpha))
	elif event_type == "enemy_defeated":
		draw_circle(enemy_pos, 30.0 + age * 46.0, Color(1.0,.78,.42,alpha*.45))
	elif event_type == "enemy_spawned":
		draw_arc(enemy_pos, 34.0 - age * 18.0, 0, TAU, 28, Color(.8,.9,1.0,alpha), 4.0)

func draw_board_tiles() -> void:
	var tiles: Array = game.board.active.values()
	tiles.sort_custom(func(a, b): return a.stack_order > b.stack_order if a.stack_id == b.stack_id else a.stack_id < b.stack_id)
	for tile in tiles:
		var available := game.board.is_available(tile.tile_id)
		var reveal_scale := 1.0
		if tile.tile_id == revealed_tile_id and reveal_time > 0.0: reveal_scale = 1.0 + sin((1.0 - reveal_time / .22) * PI) * .10
		draw_tile(tile.type_id, tile_rect(tile), available, reveal_scale)
		if tile.stack_id == game.board.locked_stack_id and game.board.top_tile(tile.stack_id) == tile:
			var locked_rect := tile_rect(tile).grow(5.0)
			draw_rect(locked_rect, Color(0.38,0.42,0.5,.46), true)
			draw_rect(locked_rect, Color("c8d1df"), false, 5.0)
			draw_string(ThemeDB.fallback_font, locked_rect.position + Vector2(0,24), tr("UI_STONE_LOCK"), HORIZONTAL_ALIGNMENT_CENTER, locked_rect.size.x, 13, Color("ffffff"))

func draw_tray() -> void:
	var rect := tray_rect()
	var remaining_slots := game.tray.capacity - game.tray.tiles.size()
	var warning_color := Color("d45f5f") if remaining_slots <= 1 else (Color("c89b48") if remaining_slots == 2 else Color("4a5b78"))
	draw_panel_rect(rect.grow(8.0), Color("111b2e"), warning_color, 3.0)
	for i in game.tray.capacity:
		var slot := tray_slot_rect(i)
		draw_panel_rect(slot, Color("24324a"), Color("4a5b78"), 2.0)
		if i < game.tray.tiles.size(): draw_tile(game.tray.tiles[i], slot.grow(-5.0), true, 0.92)
	if triple_time > 0.0:
		var alpha := clampf(triple_time / game.balance.triple_pop_duration, 0.0, 1.0)
		var radius := 20.0 + (1.0 - alpha) * 28.0
		for offset in [-44.0, 0.0, 44.0]: draw_arc(rect.get_center() + Vector2(offset,0), radius, 0, TAU, 24, Color(1.0, .88, .38, alpha), 5.0)

func draw_tile(type_id: String, rect: Rect2, available: bool, scale_value: float) -> void:
	var definition: TileDefinition = definitions[type_id]
	var scaled := Rect2(rect.get_center() - rect.size * scale_value * 0.5, rect.size * scale_value)
	draw_style_panel(Rect2(scaled.position + Vector2(5,7),scaled.size),Color(0,0,0,.32),Color.TRANSPARENT,0,10)
	var color := definition.visual_color if available else definition.visual_color.darkened(0.58)
	if available and definition.glow_texture:draw_texture_rect(definition.glow_texture,scaled.grow(8),false,Color(1,1,1,.7))
	draw_style_panel(scaled,color.darkened(.18),color.lightened(.28) if available else Color("344057"),3,10)
	draw_style_panel(scaled.grow(-5),Color(color,.72),Color(color.lightened(.45),.5),1,7)
	if definition.texture:
		draw_texture_rect(definition.texture, scaled.grow(-10.0), false, Color.WHITE if available else Color(.45,.45,.5,1))
	else:
		draw_symbol(type_id, scaled.get_center(), minf(scaled.size.x, scaled.size.y) * .25, Color("fff8e7") if available else Color("7d8493"))

func draw_panel_rect(rect: Rect2, fill: Color, border: Color, width: float) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, width)

func draw_style_panel(rect:Rect2,fill:Color,border:Color,width:float,radius:float)->void:
	var style:=StyleBoxFlat.new();style.bg_color=fill;style.border_color=border;style.set_border_width_all(int(width));style.set_corner_radius_all(int(radius));draw_style_box(style,rect)

func draw_symbol(type_id: String, center: Vector2, radius: float, ink: Color) -> void:
	var stroke := maxf(3.0, radius * .16)
	match type_id:
		"fire":
			var flame := PackedVector2Array([center + Vector2(0,-radius),center + Vector2(radius*.65,radius),center,center + Vector2(-radius*.7,radius),center + Vector2(-radius*.35,0)])
			draw_colored_polygon(flame, ink)
		"ice":
			for angle in [0.0, PI/3.0, PI*2.0/3.0]:
				var d := Vector2(cos(angle),sin(angle))*radius; draw_line(center-d,center+d,ink,stroke)
		"lightning":
			var bolt := PackedVector2Array([center+Vector2(.1*radius,-radius),center+Vector2(-.65*radius,.05*radius),center+Vector2(-.1*radius,.05*radius),center+Vector2(-.3*radius,radius),center+Vector2(.7*radius,-.2*radius),center+Vector2(.15*radius,-.2*radius)])
			draw_colored_polygon(bolt, ink)
		"wind":
			draw_arc(center,radius,-.4,PI*1.55,20,ink,stroke); draw_arc(center,radius*.55,-.2,PI*1.45,16,ink,stroke)
		"life":
			draw_line(center+Vector2(-radius,0),center+Vector2(radius,0),ink,stroke); draw_line(center+Vector2(0,-radius),center+Vector2(0,radius),ink,stroke)
		"shield":
			var shield := PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius*.8,-radius*.55),center+Vector2(radius*.62,radius*.45),center+Vector2(0,radius),center+Vector2(-radius*.62,radius*.45),center+Vector2(-radius*.8,-radius*.55)])
			draw_polyline(shield,ink,stroke); draw_line(shield[-1],shield[0],ink,stroke)
