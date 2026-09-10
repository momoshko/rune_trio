class_name RunInfoView
extends ColorRect

signal close_requested

var title_label: Label
var subtitle_label: Label
var entries: VBoxContainer
var close_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "ForegroundPanel"
	panel.custom_minimum_size = Vector2(500, 560)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0d1728fa")
	style.border_color = Color("4b6a87")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	title_label = _label("", 28); title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; column.add_child(title_label)
	subtitle_label = _label("", 17); subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; column.add_child(subtitle_label)
	var scroll := ScrollContainer.new()
	scroll.name = "EntriesScroll"
	scroll.custom_minimum_size.y = 410
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	entries = VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 8)
	scroll.add_child(entries)
	close_button = Button.new()
	close_button.name = "Close"
	close_button.text = "M8UX_CLOSE"
	close_button.custom_minimum_size.y = 44
	close_button.pressed.connect(func(): close_requested.emit())
	column.add_child(close_button)

func show_build(controller: RunController) -> void:
	_clear_entries()
	title_label.text = tr("M8UX_CURRENT_BUILD")
	subtitle_label.text = tr("M8UX_RELIC_COUNT") % controller.run.acquired_relic_ids.size()
	for id in controller.run.acquired_relic_ids:
		var relic := controller.definition.relic_by_id(id)
		if relic:
			var description := tr(relic.description_key)
			var progress := relic_progress(id, controller)
			if not progress.is_empty(): description += "\n" + progress
			_add_entry(relic.icon_key + "  " + tr(relic.name_key), description)
	if controller.run.acquired_relic_ids.is_empty(): _add_entry(tr("M8UX_NO_RELICS"), "")
	visible = true

func relic_progress(id: String, controller: RunController) -> String:
	if controller.game == null or controller.game.battle == null: return ""
	var triples := controller.game.battle.relic_state.total_triples
	if id == "echo_seal": return tr("M95_ECHO_PROGRESS") % (4 - triples % 4)
	if id == "trinity_mark": return tr("M95_TRINITY_PROGRESS") % (3 - triples % 3)
	return ""

func show_rune(definition: TileDefinition, effect_text: String) -> void:
	_clear_entries()
	title_label.text = tr("M8UX_RUNE_INFO")
	subtitle_label.text = tr(definition.name_key)
	_add_entry(definition.symbol, effect_text)
	visible = true

func hide_modal() -> void:
	visible = false

func all_text() -> String:
	var result := title_label.text + "\n" + subtitle_label.text
	for child in entries.get_children():
		for label in child.find_children("*", "Label", true, false): result += "\n" + label.text
	return result

func _clear_entries() -> void:
	for child in entries.get_children():
		entries.remove_child(child)
		child.queue_free()

func _add_entry(heading: String, description: String) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14243b")
	style.set_corner_radius_all(9)
	style.content_margin_left = 12; style.content_margin_right = 12
	style.content_margin_top = 10; style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	entries.add_child(panel)
	var column := VBoxContainer.new(); panel.add_child(column)
	if not heading.is_empty(): column.add_child(_label(heading, 19))
	if not description.is_empty():
		var body := _label(description, 15); body.modulate = Color("c4cfdf"); column.add_child(body)

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	return label
