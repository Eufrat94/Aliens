extends Control

signal closed

const CARD_SCENE := preload("res://scenes/ui/card_view.tscn")

var _game: GameState
var _picking_slot := -1
var _row: HBoxContainer
var _extra: VBoxContainer
var _done: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(980, 620)
	panel.size = Vector2(980, 620)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.96, 0.98)
	style.border_color = Color(0.15, 0.12, 0.22)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	UiConfig.place_centered(panel, Vector2(980, 620))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 16
	margin.offset_top = 12
	margin.offset_right = -16
	margin.offset_bottom = -12
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)
	var title := Label.new()
	title.text = "Workshop"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.1, 0.08, 0.16))
	column.add_child(title)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 18)
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_row)
	_extra = VBoxContainer.new()
	_extra.add_theme_constant_override("separation", 6)
	column.add_child(_extra)
	_done = Button.new()
	_done.custom_minimum_size = Vector2(220, 44)
	_done.text = "Leave"
	_done.pressed.connect(_on_done)
	column.add_child(_done)


func present(game: GameState) -> void:
	_picking_slot = -1
	visible = true
	refresh(game)


func dismiss() -> void:
	_picking_slot = -1
	visible = false


func refresh(game: GameState) -> void:
	if not visible or game.players.is_empty():
		return
	_game = game
	_done.text = "Done (1 action)" if game.workshop_has_built() else "Leave"
	_fill_row()
	_fill_extra()


func _fill_row() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for slot in _game.blueprint_row.size():
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 6)
		_row.add_child(column)
		var card_id := str(_game.blueprint_row[slot])
		if card_id == "":
			column.add_child(_empty_blueprint())
			continue
		var card_view: CardView = CARD_SCENE.instantiate()
		column.add_child(card_view)
		card_view.setup(card_id, slot, true, false, false, false, "")
		card_view.allow_hover_only()
		if bool(CardData.get_card(card_id).get("invention", false)):
			var body := card_view.get_node("BodyLabel") as Label
			body.add_theme_font_size_override("font_size", 11)
		for mark in _game.recipe_marks(slot):
			var info: Dictionary = mark
			var line := Label.new()
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var ok := bool(info["ok"])
			line.text = "%s %s" % ["✓" if ok else "✗", str(info["label"])]
			line.add_theme_color_override("font_color", Color(0.12, 0.45, 0.22) if ok else Color(0.65, 0.15, 0.15))
			column.add_child(line)
		var button := Button.new()
		button.text = "Build"
		button.custom_minimum_size = Vector2(130, 36)
		var reason := _game.build_reason(slot)
		var pending := _game.workshop_pending_slot()
		button.disabled = reason != "" or pending >= 0
		if reason != "":
			button.tooltip_text = reason
		button.pressed.connect(_on_build.bind(slot))
		column.add_child(button)


func _fill_extra() -> void:
	for child in _extra.get_children():
		_extra.remove_child(child)
		child.queue_free()
	var pending := _game.workshop_pending_slot()
	if pending >= 0:
		var note := Label.new()
		note.text = "Your gear is full. Replace one:"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_extra.add_child(note)
		var gear: Array = _game.current_player()["gear"]
		for i in gear.size():
			var button := Button.new()
			button.text = "Replace %s" % str(CardData.get_card(str(gear[i]))["name"])
			button.pressed.connect(_on_replace.bind(i))
			_extra.add_child(button)
		var back := Button.new()
		back.text = "Cancel"
		back.pressed.connect(_on_cancel_replace)
		_extra.add_child(back)
		return
	if _picking_slot < 0:
		return
	var title := Label.new()
	title.text = "Pay any material with:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_extra.add_child(title)
	for material_id in _game.spare_materials(_picking_slot):
		var button := Button.new()
		button.text = str(CardData.get_card(material_id)["name"])
		button.pressed.connect(_on_any.bind(_picking_slot, material_id))
		_extra.add_child(button)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_on_cancel_pick)
	_extra.add_child(cancel)


func _on_build(slot: int) -> void:
	if _game == null:
		return
	if _game.workshop_pending_slot() >= 0:
		return
	var recipe := CardData.recipe_of(str(_game.blueprint_row[slot]))
	if recipe.has("any"):
		_picking_slot = slot
		_fill_extra()
		return
	_game.build(slot, "")


func _on_any(slot: int, material_id: String) -> void:
	_picking_slot = -1
	_game.build(slot, material_id)


func _on_replace(gear_index: int) -> void:
	_picking_slot = -1
	_game.workshop_replace(gear_index)


func _on_cancel_replace() -> void:
	_game.workshop_cancel_replace()


func _on_cancel_pick() -> void:
	_picking_slot = -1
	_fill_extra()


func _on_done() -> void:
	closed.emit()


func _empty_blueprint() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = CardView.CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.04)
	style.border_color = Color(0.2, 0.16, 0.28, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "No more inventions"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel
