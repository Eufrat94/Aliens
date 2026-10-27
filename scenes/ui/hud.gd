extends Control

const DISCARD_CARD := Vector2(86, 86)
const BLUEPRINT_CARD := Vector2(130, 110)

@onready var _log_label: Label = $LogBar/LogLabel

var _discard_root: Control
var _discard_title: Label
var _discard_slot: Control
var _shown_discard := ""
var _workshop_root: Control
var _workshop_slots: Array[Control] = []
var _shown_blueprints := ""
@onready var _history_overlay: Control = $HistoryOverlay
@onready var _history_list: VBoxContainer = $HistoryOverlay/HistoryPanel/Margin/Column/HistoryScroll/HistoryList

var _game: GameState


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var bar := $LogBar as Control
	var log_region := UiConfig.LOG_REGION
	bar.position = log_region.position
	bar.size = log_region.size
	_log_label.offset_right = log_region.size.x - 118.0
	_log_label.offset_bottom = log_region.size.y
	_build_discard_pile()
	_build_workshop_row()
	var button := $LogBar/HistoryButton as Control
	button.offset_left = log_region.size.x - 108.0
	button.offset_right = log_region.size.x - 8.0
	button.offset_bottom = log_region.size.y - 1.0
	UiConfig.place_centered($HistoryOverlay/HistoryPanel as Control, Vector2(760, 560))
	$LogBar/HistoryButton.pressed.connect(_open_history)
	$HistoryOverlay/HistoryPanel/Margin/Column/HistoryClose.pressed.connect(_close_history)


func refresh_log(game: GameState) -> void:
	if game.players.is_empty():
		return
	_game = game
	if game.public_log.is_empty():
		_log_label.text = ""
	else:
		_log_label.text = str(game.public_log[0])
	_show_discard(game.discard_top(), game.discard.size())
	_show_blueprints(game)


func place_discard_at(at: Vector2, block: Vector2) -> void:
	_discard_root.position = at
	_discard_root.size = block
	_discard_title.position = Vector2(4, 2)
	_discard_title.size = Vector2(block.x - 8.0, 18)
	var card_x := (block.x - DISCARD_CARD.x) * 0.5
	_discard_slot.position = Vector2(card_x, 22)
	_discard_slot.size = DISCARD_CARD


func place_workshop(crystal: Rect2, lake: Rect2, village: Rect2) -> void:
	if _workshop_root == null:
		return
	var gap := 4.0
	var pad := 4.0
	var title_h := 18.0
	var block_w := pad * 2.0 + BLUEPRINT_CARD.x * 3.0 + gap * 2.0
	var block_h := 2.0 + title_h + 2.0 + BLUEPRINT_CARD.y + 2.0
	var scale := crystal.size.y / 150.0
	var x := crystal.end.x + 10.0
	var right_limit := lake.position.x - 10.0
	if x + block_w > right_limit:
		x = right_limit - block_w
	var curve_top := _plane_top(
		crystal.get_center(),
		lake.get_center(),
		village.get_center(),
		scale,
		x,
		x + block_w
	)
	var stroke := 2.5 * scale + 6.0
	var y := curve_top - stroke - block_h
	var region := UiConfig.BOARD_REGION
	y = clampf(y, region.position.y + 4.0, maxf(region.position.y + 4.0, region.end.y - block_h - 4.0))
	_workshop_root.position = Vector2(x, y)
	_workshop_root.size = Vector2(block_w, block_h)
	var title := _workshop_root.get_node("Title") as Control
	title.position = Vector2(pad, 2)
	title.size = Vector2(block_w - pad * 2.0, title_h)
	for slot in _workshop_slots.size():
		var card_x := pad + float(slot) * (BLUEPRINT_CARD.x + gap)
		_workshop_slots[slot].position = Vector2(card_x, title_h + 4.0)
		_workshop_slots[slot].size = BLUEPRINT_CARD


func _plane_top(a: Vector2, b: Vector2, away_from: Vector2, scale: float, span_left: float, span_right: float) -> float:
	var mid := (a + b) * 0.5
	var along := b - a
	var perpendicular := along.orthogonal().normalized()
	if perpendicular.dot(mid - away_from) < 0.0:
		perpendicular = -perpendicular
	var control := mid + perpendicular * 340.0 * scale
	var top := 100000.0
	var reach := 2.5 * scale
	for i in 49:
		var t := float(i) / 48.0
		var point := _quad(a, control, b, t)
		if point.x < span_left - reach or point.x > span_right + reach:
			continue
		top = minf(top, point.y)
	if top > 99999.0:
		return mid.y
	return top


func _quad(a: Vector2, control: Vector2, b: Vector2, t: float) -> Vector2:
	var inverse := 1.0 - t
	return inverse * inverse * a + 2.0 * inverse * t * control + t * t * b


func _build_discard_pile() -> void:
	_discard_root = Panel.new()
	_discard_root.name = "DiscardPile"
	_discard_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.78)
	style.border_color = Color(0.15, 0.12, 0.22, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	_discard_root.add_theme_stylebox_override("panel", style)
	add_child(_discard_root)
	_discard_title = Label.new()
	_discard_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_discard_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discard_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_discard_title.add_theme_font_size_override("font_size", 14)
	_discard_title.add_theme_color_override("font_color", Color(0.1, 0.08, 0.16))
	_discard_title.text = "Discard (0)"
	_discard_root.add_child(_discard_title)
	_discard_slot = Control.new()
	_discard_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_discard_root.add_child(_discard_slot)
	_show_discard("", 0)


func _build_workshop_row() -> void:
	_workshop_root = Panel.new()
	_workshop_root.name = "WorkshopBlueprints"
	_workshop_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.78)
	style.border_color = Color(0.12, 0.35, 0.42, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	_workshop_root.add_theme_stylebox_override("panel", style)
	add_child(_workshop_root)
	var title := Label.new()
	title.name = "Title"
	title.text = "Workshop"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.08, 0.22, 0.28))
	_workshop_root.add_child(title)
	for _slot in 3:
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.size = BLUEPRINT_CARD
		_workshop_root.add_child(slot)
		_workshop_slots.append(slot)


func _show_blueprints(game: GameState) -> void:
	var key := "%s|%s|%s" % [game.blueprint_row[0], game.blueprint_row[1], game.blueprint_row[2]]
	if key == _shown_blueprints:
		return
	_shown_blueprints = key
	var preview := get_tree().get_first_node_in_group("card_preview")
	if preview != null and preview.has_method("end_hover"):
		preview.call("end_hover")
	for slot in _workshop_slots.size():
		var host := _workshop_slots[slot]
		for child in host.get_children():
			host.remove_child(child)
			child.queue_free()
		var card_id := str(game.blueprint_row[slot])
		if card_id == "":
			host.add_child(_empty_blueprint())
			continue
		var mini: Control = preload("res://scenes/ui/mini_card.tscn").instantiate()
		host.add_child(mini)
		mini.call("setup", card_id)
		mini.call("apply_size", BLUEPRINT_CARD)
		mini.call("set_recipe_only", true)


func _empty_blueprint() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = BLUEPRINT_CARD
	panel.size = BLUEPRINT_CARD
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.04)
	style.border_color = Color(0.12, 0.35, 0.42, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "No more inventions"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.2, 0.28, 0.32, 0.7))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


func _show_discard(card_id: String, count: int) -> void:
	_discard_title.text = "Discard (%d)" % count
	if card_id == _shown_discard and _discard_slot.get_child_count() > 0:
		return
	_shown_discard = card_id
	var preview := get_tree().get_first_node_in_group("card_preview")
	if preview != null and preview.has_method("end_hover"):
		preview.call("end_hover")
	for child: Node in _discard_slot.get_children():
		_discard_slot.remove_child(child)
		child.queue_free()
	if card_id == "":
		_discard_slot.add_child(_empty_discard())
		return
	var mini: Control = preload("res://scenes/ui/mini_card.tscn").instantiate()
	_discard_slot.add_child(mini)
	mini.call("setup", card_id)
	mini.call("apply_size", DISCARD_CARD)


func _empty_discard() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = DISCARD_CARD
	panel.size = DISCARD_CARD
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.04)
	style.border_color = Color(0.2, 0.16, 0.28, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.name = "EmptyLabel"
	label.text = "Empty"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.25, 0.22, 0.32, 0.7))
	panel.add_child(label)
	return panel


func _open_history() -> void:
	if _game == null:
		return
	_clear(_history_list)
	if _game.public_log.is_empty():
		_history_list.add_child(_info_label("No public events yet.", Color(0.8, 0.8, 0.86), 16))
	else:
		for line in _game.public_log:
			_history_list.add_child(_info_label(str(line), Color(0.92, 0.92, 0.96), 16))
	_history_overlay.visible = true


func _close_history() -> void:
	_history_overlay.visible = false


func _info_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
