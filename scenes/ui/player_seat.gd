extends Panel

signal card_clicked(hand_index: int)
signal gear_slot_clicked(slot_index: int)
signal rest_pressed
signal end_turn_pressed

const MINI_SCENE := preload("res://scenes/ui/mini_card.tscn")
const CARD_SCENE := preload("res://scenes/ui/card_view.tscn")
const GOLD := Color8(212, 172, 13)
const PURPLE := Color8(142, 68, 173)
const HAND_SCALE := 110.0 / 130.0
const HAND_STEP := 116.0
const HAND_LIFT := 4.0
const BACK_SIZE := Vector2(50, 70)
const CLAW_HINT := "Click a highlighted tile to draw from its deck. Right-click or Esc to cancel."
const MOVE_HINT := "Click a highlighted tile to move there. Right-click or Esc to cancel."

@onready var _name_label: Label = $Margin/Column/Header/Name
@onready var _turn_tag: Label = $Margin/Column/Header/TurnTag
@onready var _header: HBoxContainer = $Margin/Column/Header
@onready var _location: Label = $Margin/Column/Header/Location
@onready var _turn_row: HBoxContainer = $Margin/Column/TurnRow
@onready var _pips: HBoxContainer = $Margin/Column/TurnRow/Pips
@onready var _actions_label: Label = $Margin/Column/TurnRow/ActionsLabel
@onready var _instruction: Label = $Margin/Column/TurnRow/Instruction
@onready var _hand_scroll: ScrollContainer = $Margin/Column/HandHost/HandScroll
@onready var _hand_row: Control = $Margin/Column/HandHost/HandScroll/HandRow
@onready var _backs_box: HBoxContainer = $Margin/Column/HandHost/BacksBox
@onready var _backs: Control = $Margin/Column/HandHost/BacksBox/Backs
@onready var _count_label: Label = $Margin/Column/HandHost/BacksBox/CountLabel
@onready var _played_scroll: ScrollContainer = $Margin/Column/PlayedBox/PlayedScroll
@onready var _played_row: HBoxContainer = $Margin/Column/PlayedBox/PlayedScroll/PlayedRow
@onready var _played_empty: Label = $Margin/Column/PlayedBox/PlayedEmpty
@onready var _gear_title: Label = $Margin/Column/GearBox/GearTitle
@onready var _gear_row: HBoxContainer = $Margin/Column/GearBox/GearRow
@onready var _buttons: HBoxContainer = $Margin/Column/ButtonRow
@onready var _rest_button: Button = $Margin/Column/ButtonRow/RestButton
@onready var _end_button: Button = $Margin/Column/ButtonRow/EndTurnButton


func _ready() -> void:
	clip_contents = true
	$Margin/Column/PlayedBox.custom_minimum_size.y = 118
	_rest_button.pressed.connect(func() -> void: rest_pressed.emit())
	_end_button.pressed.connect(func() -> void: end_turn_pressed.emit())
	for child in _pips.get_children():
		var pip: Control = child
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func show_player(player: Dictionary, game: GameState, is_current: bool, selected_hand_index: int, gear_replace_index: int) -> void:
	var color: Color = player["color"]
	_apply_chrome(color, is_current)
	_name_label.text = str(player["name"])
	_name_label.add_theme_color_override("font_color", color)
	_turn_tag.visible = is_current
	_turn_tag.add_theme_color_override("font_color", color)
	var tile_name: String = BoardData.get_tile(player["tile"])["name"]
	_location.text = "On: %s" % tile_name
	_fill_tokens(player)
	_show_turn(game, player, is_current, selected_hand_index, gear_replace_index)
	if is_current:
		_fill_hand(player, game, selected_hand_index, gear_replace_index)
	else:
		_fill_backs(player["hand"])
	_fill_played(player["played"])
	_fill_gear(player["gear"], is_current and gear_replace_index >= 0)
	_buttons.modulate = Color.WHITE
	_rest_button.visible = is_current
	_end_button.visible = is_current
	if is_current:
		_rest_button.disabled = not game.can_rest()


func set_instruction(text: String) -> void:
	_instruction.text = text


func _apply_chrome(color: Color, is_current: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color8(58, 58, 82) if is_current else Color8(43, 43, 58)
	style.border_color = color
	style.set_border_width_all(6 if is_current else 2)
	style.set_corner_radius_all(12)
	add_theme_stylebox_override("panel", style)


func _fill_tokens(player: Dictionary) -> void:
	for child in _header.get_children():
		if child == _name_label or child == _turn_tag or child == _location:
			continue
		_header.remove_child(child)
		child.free()
	var at := _location.get_index()
	var gold := _circle_token(GOLD, int(player["gold"]), Color(0.12, 0.09, 0.02))
	var purple := _circle_token(PURPLE, int(player["purple"]), Color.WHITE)
	_header.add_child(gold)
	_header.move_child(gold, at)
	_header.add_child(purple)
	_header.move_child(purple, at + 1)


func _show_turn(game: GameState, player: Dictionary, is_current: bool, selected_hand_index: int, gear_replace_index: int) -> void:
	_pips.visible = is_current
	_actions_label.visible = is_current
	_instruction.visible = is_current
	if not is_current:
		return
	_actions_label.text = "%d / %d" % [game.actions_left, GameState.ACTIONS_PER_TURN]
	_paint_pips(game.actions_left)
	if gear_replace_index >= 0:
		_instruction.text = "Choose a gear slot to replace (Esc to cancel)"
	elif selected_hand_index >= 0:
		var selected_id := ""
		var hand: Array = player["hand"]
		if selected_hand_index < hand.size():
			selected_id = str(hand[selected_hand_index])
		if selected_id == "grappling_claw":
			_instruction.text = CLAW_HINT
		else:
			_instruction.text = MOVE_HINT
	elif not game.found_card_ids.is_empty():
		_instruction.text = "You found: %s" % _found_names(game.found_card_ids)
	elif game.actions_left <= 0:
		_instruction.text = "No actions left."
	else:
		_instruction.text = "Choose a card to play."


func _paint_pips(actions_left: int) -> void:
	for i in _pips.get_child_count():
		var pip: Panel = _pips.get_child(i)
		var filled := i < actions_left
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(7)
		if filled:
			style.bg_color = Color(0.94, 0.94, 0.97)
		else:
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color(0.94, 0.94, 0.97, 0.75)
			style.set_border_width_all(2)
		pip.add_theme_stylebox_override("panel", style)


func _fill_hand(player: Dictionary, game: GameState, selected_hand_index: int, gear_replace_index: int) -> void:
	_hand_scroll.visible = true
	_backs_box.visible = false
	_clear(_hand_row)
	var hand: Array = player["hand"]
	var fresh: Array = player["fresh"]
	var x := 0.0
	for i in hand.size():
		var card_id: String = hand[i]
		var enabled := _hand_enabled(game, i)
		var reason := ""
		if not enabled:
			reason = game.play_reason(i)
		var selected := i == selected_hand_index or i == gear_replace_index
		var is_new: bool = bool(fresh[i])
		var card_view := _add_card(_hand_row, card_id, i, enabled, false, selected, is_new, reason)
		card_view.scale = Vector2(HAND_SCALE, HAND_SCALE)
		var y := 0.0 if selected else HAND_LIFT
		card_view.position = Vector2(x, y)
		card_view.card_clicked.connect(_on_card_clicked)
		x += HAND_STEP
	var visual_h := HAND_LIFT + CardView.CARD_SIZE.y * HAND_SCALE
	_hand_row.custom_minimum_size = Vector2(maxf(x, 10.0), visual_h)


func _fill_backs(hand: Array) -> void:
	_hand_scroll.visible = false
	_backs_box.visible = true
	_clear(_backs)
	var count := hand.size()
	_count_label.text = "1 card" if count == 1 else "%d cards" % count
	var width := 250.0
	var step := BACK_SIZE.x + 4.0
	if count > 1:
		var needed := BACK_SIZE.x + (count - 1) * step
		if needed > width:
			step = (width - BACK_SIZE.x) / float(count - 1)
	for i in count:
		var back := _card_back()
		_backs.add_child(back)
		back.position = Vector2(i * step, 0)
	var used := BACK_SIZE.x if count == 0 else BACK_SIZE.x + (count - 1) * step
	_backs.custom_minimum_size = Vector2(maxf(used, 10.0), BACK_SIZE.y)


func _fill_played(played: Array) -> void:
	_clear(_played_row)
	var empty := played.is_empty()
	_played_empty.visible = empty
	_played_scroll.visible = not empty
	if empty:
		return
	for card_id in played:
		var mini: Control = MINI_SCENE.instantiate()
		_played_row.add_child(mini)
		mini.call("setup", str(card_id))


func _fill_gear(gear: Array, replacing: bool) -> void:
	_clear(_gear_row)
	_gear_title.text = "Gear (%d/%d)" % [gear.size(), GameState.GEAR_SLOTS]
	for slot in GameState.GEAR_SLOTS:
		if slot < gear.size():
			var mini: Control = MINI_SCENE.instantiate()
			_gear_row.add_child(mini)
			mini.call("setup", str(gear[slot]))
			mini.call("set_selected", replacing)
			if replacing:
				mini.gui_input.connect(_on_gear_input.bind(slot))
		else:
			_gear_row.add_child(_empty_slot())


func _hand_enabled(game: GameState, index: int) -> bool:
	var card: Dictionary = CardData.get_card(game.current_player()["hand"][index])
	if int(card["kind"]) == CardData.Kind.GEAR:
		return game.can_equip(index)
	return game.can_play_card(index)


func _add_card(parent: Node, card_id: String, index: int, playable: bool, faded: bool, selected: bool, is_new: bool, reason: String) -> CardView:
	var card_view: CardView = CARD_SCENE.instantiate()
	parent.add_child(card_view)
	card_view.setup(card_id, index, playable, faded, selected, is_new, reason)
	return card_view


func _on_card_clicked(hand_index: int) -> void:
	card_clicked.emit(hand_index)


func _on_gear_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			gear_slot_clicked.emit(slot)
			get_viewport().set_input_as_handled()


func _circle_token(bg: Color, number: int, text_color: Color) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(26, 26)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(13)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = str(number)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_font_size_override("font_size", 13)
	panel.add_child(label)
	return panel


func _card_back() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = BACK_SIZE
	panel.size = BACK_SIZE
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12)
	style.border_color = Color(0.86, 0.86, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _empty_slot() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(72, 100)
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.04)
	style.border_color = Color(1, 1, 1, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _found_names(card_ids: Array) -> String:
	var names: PackedStringArray = PackedStringArray()
	for card_id in card_ids:
		names.append(str(CardData.get_card(str(card_id))["name"]))
	return ", ".join(names)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()
