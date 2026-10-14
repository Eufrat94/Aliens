class_name AlienChecklist
extends Control

signal alien_toggled(alien_id: String, on: bool)

var _panel: Panel
var _grid: GridContainer


func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(1920, 1080)
	_panel = Panel.new()
	_panel.mouse_filter = MOUSE_FILTER_STOP
	_panel.position = Vector2(560, 180)
	_panel.size = Vector2(800, 640)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.98)
	style.border_color = Color8(142, 68, 173)
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var title := Label.new()
	title.text = "Aliens"
	title.mouse_filter = MOUSE_FILTER_IGNORE
	title.position = Vector2(24, 16)
	title.size = Vector2(600, 36)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.94, 0.94, 0.97))
	_panel.add_child(title)

	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(660, 16)
	close.size = Vector2(116, 36)
	close.pressed.connect(hide_checklist)
	_panel.add_child(close)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.mouse_filter = MOUSE_FILTER_IGNORE
	_grid.position = Vector2(24, 68)
	_grid.size = Vector2(752, 548)
	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 6)
	_panel.add_child(_grid)


func show_for(player: Dictionary) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var checks: Dictionary = player["checklist"]
	for alien_id in CardData.all_alien_ids():
		var row := HBoxContainer.new()
		row.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(350, 28)
		var box := CheckBox.new()
		box.button_pressed = bool(checks.get(alien_id, false))
		box.toggled.connect(_on_toggled.bind(alien_id))
		row.add_child(box)
		var name := Label.new()
		name.text = str(CardData.get_card(alien_id)["name"])
		name.mouse_filter = MOUSE_FILTER_STOP
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.add_theme_font_size_override("font_size", 18)
		name.add_theme_color_override("font_color", Color(0.94, 0.94, 0.97))
		name.mouse_entered.connect(_hover.bind(alien_id))
		name.mouse_exited.connect(_clear_hover)
		row.add_child(name)
		_grid.add_child(row)
	visible = true


func hide_checklist() -> void:
	visible = false
	_clear_hover()


func _on_toggled(on: bool, alien_id: String) -> void:
	alien_toggled.emit(alien_id, on)


func _hover(alien_id: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var preview := tree.get_first_node_in_group("card_preview")
	if preview != null and preview.has_method("begin_hover"):
		preview.call("begin_hover", alien_id)


func _clear_hover() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var preview := tree.get_first_node_in_group("card_preview")
	if preview != null and preview.has_method("end_hover"):
		preview.call("end_hover")
