class_name GameView
extends Control

@onready var game: GameController = $GameController
@onready var level_label: Label = $Center/Content/HUD/Rows/Level
@onready var remaining_label: Label = $Center/Content/HUD/Rows/Remaining
@onready var tray_label: Label = $Center/Content/TrayLabel
@onready var board_space: Control = $Center/Content/BoardSpace
@onready var tray_space: Control = $Center/Content/TraySpace
@onready var content: VBoxContainer = $Center/Content
@onready var hud: MarginContainer = $Center/Content/HUD
@onready var overlay: ColorRect = $ResultOverlay
@onready var result_title: Label = $ResultOverlay/Center/Panel/Title
var definitions := {}
var flights: Array = []
var triple_type := ""
var triple_time := 0.0

func _ready() -> void:
	TranslationServer.set_locale("ru")
	definitions = TileCatalog.all()
	game.state_changed.connect(update_view)
	game.tile_moving.connect(show_tile_flight)
	game.triple_resolved.connect(show_triple)
	$ResultOverlay/Center/Panel/Restart.pressed.connect(game.restart)
	resized.connect(apply_responsive_layout)
	apply_responsive_layout()
	update_view()

func layout_mode_for_size(viewport_size: Vector2) -> String:
	return "wide" if viewport_size.x / maxf(viewport_size.y, 1.0) >= 1.2 else "portrait"

func apply_responsive_layout() -> void:
	var wide := layout_mode_for_size(size) == "wide"
	content.custom_minimum_size = Vector2(405, 720) if wide else Vector2(720, 720)
	hud.custom_minimum_size.y = 88.0 if wide else 116.0
	board_space.custom_minimum_size.y = 430.0 if wide else 760.0
	tray_space.custom_minimum_size.y = 88.0 if wide else 116.0
	queue_redraw()

func update_view() -> void:
	if game.board == null: return
	level_label.text = tr(game.level.name_key)
	remaining_label.text = "%s: %d" % [tr("UI_TILES_LEFT"), game.board.remaining_count()]
	tray_label.text = "%s  %d/%d" % [tr("UI_TRAY"), game.tray.tiles.size(), game.tray.capacity]
	overlay.visible = game.state in ["won", "lost"]
	result_title.text = tr("UI_LEVEL_COMPLETE") if game.state == "won" else tr("UI_DEFEAT")
	queue_redraw()

func board_rect() -> Rect2:
	return Rect2(board_space.global_position, board_space.size)

func tray_rect() -> Rect2:
	var outer := Rect2(tray_space.global_position, tray_space.size)
	var width := minf(outer.size.x - 24.0, 672.0)
	return Rect2(outer.position + Vector2((outer.size.x - width) * 0.5, 6.0), Vector2(width, minf(96.0, outer.size.y - 12.0)))

func tile_rect(tile: TilePlacement) -> Rect2:
	var outer := board_rect()
	var scale_factor := minf((outer.size.x - 30.0) / game.level.design_size.x, (outer.size.y - 24.0) / game.level.design_size.y)
	var design_origin := outer.position + (outer.size - game.level.design_size * scale_factor) * 0.5
	var tile_size := game.level.tile_size * scale_factor
	return Rect2(design_origin + tile.position * scale_factor - tile_size * 0.5, tile_size)

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
	if not pressed or game.state != "playing" or game.busy: return
	var tile_id := pick_tile(point)
	if tile_id >= 0: game.select_tile(tile_id)

func show_tile_flight(tile: TilePlacement, insert_index: int) -> void:
	flights.append({"type_id":tile.type_id, "from":tile_rect(tile).get_center(), "slot":insert_index, "age":0.0})
	queue_redraw()

func show_triple(type_id: String) -> void:
	triple_type = type_id; triple_time = game.balance.triple_pop_duration
	queue_redraw()

func _process(delta: float) -> void:
	for flight in flights: flight.age += delta
	flights = flights.filter(func(flight): return flight.age < game.balance.tile_move_duration)
	if triple_time > 0.0: triple_time -= delta
	if not flights.is_empty() or triple_time > 0.0: queue_redraw()

func _draw() -> void:
	if game.board == null: return
	draw_rect(board_rect(), Color("0c1626"), true)
	draw_board_tiles()
	draw_tray()
	for flight in flights:
		var progress: float = clampf(flight.age / game.balance.tile_move_duration, 0.0, 1.0)
		var target := tray_slot_rect(mini(flight.slot, game.tray.capacity - 1)).get_center()
		var center: Vector2 = flight.from.lerp(target, ease(progress, -1.6))
		draw_tile(flight.type_id, Rect2(center - Vector2(38,44), Vector2(76,88)), true, 1.0)

func draw_board_tiles() -> void:
	var tiles: Array = game.board.active.values()
	tiles.sort_custom(func(a, b): return a.layer < b.layer)
	for tile in tiles:
		var available := game.board.is_available(tile.tile_id)
		draw_tile(tile.type_id, tile_rect(tile), available, 1.0)

func draw_tray() -> void:
	var rect := tray_rect()
	draw_rect(rect.grow(8.0), Color("111b2e"), true)
	for i in game.tray.capacity:
		var slot := tray_slot_rect(i)
		draw_panel_rect(slot, Color("24324a"), Color("4a5b78"), 2.0)
		if i < game.tray.tiles.size(): draw_tile(game.tray.tiles[i], slot.grow(-5.0), true, 0.92)
	if triple_time > 0.0:
		var alpha := clampf(triple_time / game.balance.triple_pop_duration, 0.0, 1.0)
		var radius := 34.0 + (1.0 - alpha) * 42.0
		draw_arc(rect.get_center(), radius, 0, TAU, 32, Color(1.0, .88, .38, alpha), 6.0)

func draw_tile(type_id: String, rect: Rect2, available: bool, scale_value: float) -> void:
	var definition: TileDefinition = definitions[type_id]
	var scaled := Rect2(rect.get_center() - rect.size * scale_value * 0.5, rect.size * scale_value)
	draw_rect(Rect2(scaled.position + Vector2(5,7), scaled.size), Color(0,0,0,.32), true)
	var color := definition.visual_color if available else definition.visual_color.darkened(0.58)
	draw_panel_rect(scaled, color, color.lightened(0.24) if available else Color("344057"), 3.0)
	if definition.texture:
		draw_texture_rect(definition.texture, scaled.grow(-10.0), false, Color.WHITE if available else Color(.45,.45,.5,1))
	else:
		draw_symbol(type_id, scaled.get_center(), minf(scaled.size.x, scaled.size.y) * .25, Color("fff8e7") if available else Color("7d8493"))

func draw_panel_rect(rect: Rect2, fill: Color, border: Color, width: float) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, width)

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
