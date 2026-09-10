class_name RunOfferView
extends ColorRect

signal exit_requested
signal build_requested

@export var visual_library: VisualLibrary
var foreground_panel: PanelContainer
var biome_heading: Label
var victory_heading: Label
var heading: Label
var details: Label
var cards: VBoxContainer
var buttons: Array[Button] = []
var build_button: Button
var rendered_offer_id := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	foreground_panel = PanelContainer.new()
	foreground_panel.name = "ForegroundPanel"
	foreground_panel.custom_minimum_size.x = 500
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("0d1728f5")
	panel_style.border_color = Color("3b5874")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	foreground_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(foreground_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	foreground_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	biome_heading = _label("", 15); biome_heading.modulate = Color("e8c85c"); column.add_child(biome_heading)
	victory_heading = _label("", 20); victory_heading.modulate = Color("8fe1d3"); column.add_child(victory_heading)
	heading = _label("", 27); column.add_child(heading)
	details = _label("", 15); details.modulate = Color("aebbd0"); column.add_child(details)
	cards = VBoxContainer.new()
	cards.add_theme_constant_override("separation", 9)
	column.add_child(cards)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	build_button = Button.new()
	build_button.name = "CurrentBuild"
	build_button.flat = true
	build_button.custom_minimum_size.y = 34
	build_button.pressed.connect(func(): build_requested.emit())
	actions.add_child(build_button)
	var exit_button := Button.new()
	exit_button.name = "LeaveRun"
	exit_button.text = "UI_END_RUN"
	exit_button.custom_minimum_size.y = 36
	exit_button.flat = true
	exit_button.add_theme_font_size_override("font_size", 15)
	exit_button.modulate = Color("a4b0c0")
	exit_button.pressed.connect(func(): exit_requested.emit())
	actions.add_child(exit_button)

func refresh(controller: RunController) -> void:
	var run := controller.run
	visible = controller.game.run_mode and run.status in [RunState.Status.ENCOUNTER_CHOICE, RunState.Status.REWARD]
	if not visible:
		rendered_offer_id = ""
		return
	var choosing := run.status == RunState.Status.ENCOUNTER_CHOICE
	var token := run.offer_id("encounter" if choosing else "reward")
	# UI reopening reads existing offers. It never generates or rerolls them.
	if token == rendered_offer_id: return
	rendered_offer_id = token
	for child in cards.get_children():
		cards.remove_child(child); child.queue_free()
	buttons.clear()
	biome_heading.text = tr(controller.chapter().name_key)
	victory_heading.visible = not choosing
	victory_heading.text = tr("M8UX_VICTORY")
	heading.text = tr("M4_CHOOSE_ENEMY" if choosing else "M4_CHOOSE_REWARD")
	details.text = tr("M4_BOUNDARY_HP") % run.boundary_hp
	build_button.text = tr("M8UX_RELIC_COUNT") % run.acquired_relic_ids.size()
	if not choosing and controller.role() == "boss": details.text += "\n" + tr("M4_RECOVERY_APPLIED")
	if not controller.validation_errors.is_empty():
		details.text += "\n" + tr("M4_CONFIG_ERROR") + "\n" + "\n".join(controller.validation_errors)
		return
	for id in run.encounter_offer if choosing else run.reward_offer:
		if choosing:
			var encounter := controller.definition.encounter_by_id(id)
			var enemy := EnemyCatalog.by_id(encounter.enemy_id)
			var copy := "%s\n%s\n%s" % [tr(encounter.mechanic_key), tr("M4_DANGER_" + encounter.danger), tr("M7UI_REWARD_CATEGORY") % tr("M4_CATEGORY_" + encounter.reward_category)]
			var portrait := enemy.portrait
			if visual_library:
				var mapped := visual_library.enemy_texture(enemy.id)
				if mapped: portrait = mapped
			var button := _card(tr(enemy.name_key), copy, "◈", portrait)
			button.text = tr("M7UI_FIGHT")
			button.pressed.connect(controller.choose_encounter.bind(id, token))
		elif id == "restore_core":
			var full := run.boundary_hp >= controller.definition.maximum_hp
			var restored := mini(controller.definition.restore_amount, controller.definition.maximum_hp - run.boundary_hp)
			var restore_copy := tr("M4_RESTORE_DESCRIPTION") if full else tr("M8UX_HP_AMOUNT") % restored
			var button := _card(tr("M4_CORE_RESTORED" if full else "M4_RESTORE_CORE"), restore_copy, "+", null)
			button.disabled = full
			button.text = tr("M4_CORE_RESTORED" if full else "M7UI_RESTORE")
			button.pressed.connect(controller.claim_reward.bind(id, token))
		else:
			var relic := controller.definition.relic_by_id(id)
			var copy := "%s · %s\n%s" % [tr("M4_RARITY_" + relic.rarity), tr("M4_CATEGORY_" + relic.category), tr(relic.description_key)]
			var button := _card(tr(relic.name_key), copy, relic.icon_key, relic.texture)
			button.pressed.connect(controller.claim_reward.bind(id, token))
		buttons[-1].set_meta("offer_item_id", id)

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _card(title: String, description: String, icon: String, texture: Texture2D) -> Button:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14243b")
	style.content_margin_left = 12; style.content_margin_right = 12
	style.content_margin_top = 9; style.content_margin_bottom = 9
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	cards.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var portrait_area := PanelContainer.new()
	portrait_area.name = "PortraitArea"
	portrait_area.custom_minimum_size = Vector2(72, 72)
	row.add_child(portrait_area)
	if texture:
		var portrait := TextureRect.new()
		portrait.texture = texture
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_area.add_child(portrait)
	else:
		var placeholder := _label(icon, 28)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		portrait_area.add_child(placeholder)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	column.add_child(_label(title, 20))
	column.add_child(_label(description, 15))
	var button := Button.new()
	button.text = "M4_CHOOSE"
	button.custom_minimum_size = Vector2(140, 36)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(button)
	buttons.append(button)
	return button
