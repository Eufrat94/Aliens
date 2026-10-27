extends Panel

signal card_clicked(hand_index: int)
signal gear_slot_clicked(slot_index: int)
signal gear_use_pressed(slot_index: int)
signal move_pressed
signal search_pressed
signal interact_pressed
signal fight_pressed
signal end_turn_pressed
signal checklist_pressed
signal alien_use_pressed(area_index: int)

const MINI_SCENE := preload("res://scenes/ui/mini_card.tscn")
const CARD_SCENE := preload("res://scenes/ui/card_view.tscn")
const CLAW_HINT := "Click a highlighted tile to draw from its deck. Right-click or Esc to cancel."
const MOVE_HINT := "Click a highlighted tile to move there. Right-click or Esc to cancel."
const ACTION_W := 110.0
const ACTION_H := 40.0
const ACTION_GAP := 8.0
const END_GAP := 50.0
const END_W := 150.0
const END_H := 44.0
const ACTION_SCREEN_X := 650.0

var _instruction: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true


func show_player(player: Dictionary, game: GameState, selected_hand_index: int, gear_replace_index: int, selecting_move: bool) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_instruction = null
	_apply_chrome(player["color"])
	var inset := 12.0
	var header_h := 48.0
	var header_w := size.x - inset * 2.0
	var header := _build_header(player, game, selected_hand_index, gear_replace_index, selecting_move, header_w, header_h)
	header.position = Vector2(inset, 6)
	header.size = Vector2(header_w, header_h)
	add_child(header)

	var row_top := 6.0 + header_h + 4.0
	var row_h := size.y - row_top - 8.0
	var gap := 14.0
	var gear_w := UiConfig.MINI_SIZE.x * float(GameState.GEAR_SLOTS) + 12.0
	var alien_w := 210.0
	var inner_w := size.x - inset * 2.0
	var hand_w := inner_w - gear_w - alien_w - gap * 2.0
	var hand_x := inset
	var gear_x := hand_x + hand_w + gap
	var alien_x := gear_x + gear_w + gap

	var hand := Control.new()
	hand.name = "Hand"
	hand.mouse_filter = MOUSE_FILTER_IGNORE
	hand.position = Vector2(hand_x, row_top)
	add_child(hand)
	_fill_hand(hand, player, game, selected_hand_index, gear_replace_index)
	UiConfig.layout_fan(hand, hand_w, CardView.CARD_SIZE, row_h - CardView.CARD_SIZE.y)

	var gear_box := Control.new()
	gear_box.mouse_filter = MOUSE_FILTER_IGNORE
	gear_box.position = Vector2(gear_x, row_top)
	gear_box.size = Vector2(gear_w, row_h)
	add_child(gear_box)
	var gear_title := Label.new()
	var gear: Array = player["gear"]
	gear_title.text = "Gear (%d/%d)" % [gear.size(), GameState.GEAR_SLOTS]
	gear_title.mouse_filter = MOUSE_FILTER_IGNORE
	gear_title.position = Vector2(0, 0)
	gear_title.size = Vector2(gear_w, 22)
	gear_title.add_theme_color_override("font_color", Color(0.82, 0.82, 0.9))
	gear_title.add_theme_font_size_override("font_size", 14)
	gear_box.add_child(gear_title)
	var gear_host := Control.new()
	gear_host.mouse_filter = MOUSE_FILTER_IGNORE
	gear_box.add_child(gear_host)
	var replacing := gear_replace_index >= 0
	for slot in GameState.GEAR_SLOTS:
		if slot < gear.size():
			var mini: Control = MINI_SCENE.instantiate()
			gear_host.add_child(mini)
			var gear_id := str(gear[slot])
			mini.call("setup", gear_id)
			mini.call("set_selected", replacing)
			if replacing:
				mini.gui_input.connect(_on_gear_input.bind(slot))
			else:
				_add_use_badge(mini, slot, game, gear_id)
		else:
			gear_host.add_child(UiConfig.empty_slot())
	UiConfig.layout_fan(gear_host, gear_w, UiConfig.MINI_SIZE, row_h - UiConfig.MINI_SIZE.y)

	var aliens: Array = player["aliens"]
	var alien_box := Control.new()
	alien_box.mouse_filter = MOUSE_FILTER_IGNORE
	alien_box.position = Vector2(alien_x, row_top)
	alien_box.size = Vector2(alien_w, row_h)
	add_child(alien_box)
	var alien_title := Label.new()
	alien_title.text = "Aliens (%d)" % aliens.size()
	alien_title.mouse_filter = MOUSE_FILTER_IGNORE
	alien_title.position = Vector2(0, 0)
	alien_title.size = Vector2(alien_w, 22)
	alien_title.add_theme_color_override("font_color", Color(0.82, 0.82, 0.9))
	alien_title.add_theme_font_size_override("font_size", 14)
	alien_box.add_child(alien_title)
	var alien_host := Control.new()
	alien_host.mouse_filter = MOUSE_FILTER_IGNORE
	alien_box.add_child(alien_host)
	for area_index in aliens.size():
		var alien_id := str(aliens[area_index])
		var alien_card: Control = MINI_SCENE.instantiate()
		alien_host.add_child(alien_card)
		alien_card.call("setup", alien_id)
		_add_alien_badge(alien_card, area_index, game, alien_id)
	UiConfig.layout_fan(alien_host, alien_w, UiConfig.MINI_SIZE, row_h - UiConfig.MINI_SIZE.y)


func set_instruction(text: String) -> void:
	_apply_instruction(text)


func _apply_chrome(color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UiConfig.CURRENT_BG
	style.border_color = color
	style.set_border_width_all(6)
	style.set_corner_radius_all(12)
	add_theme_stylebox_override("panel", style)


func _build_header(player: Dictionary, game: GameState, selected_hand_index: int, gear_replace_index: int, selecting_move: bool, header_w: float, header_h: float) -> Control:
	var header := Control.new()
	header.name = "Header"
	header.mouse_filter = MOUSE_FILTER_PASS

	var action_local_x := ACTION_SCREEN_X - position.x - 12.0
	var action_w := ACTION_W * 4.0 + ACTION_GAP * 3.0
	var left := HBoxContainer.new()
	left.name = "Status"
	left.mouse_filter = MOUSE_FILTER_PASS
	left.clip_contents = true
	left.add_theme_constant_override("separation", 10)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.position = Vector2.ZERO
	left.size = Vector2(maxf(action_local_x - 16.0, 0.0), header_h)
	header.add_child(left)

	var turn := Label.new()
	turn.text = "%s's turn" % str(player["name"])
	turn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn.add_theme_color_override("font_color", player["color"])
	turn.add_theme_font_size_override("font_size", 20)
	var bold := SystemFont.new()
	bold.font_weight = 700
	turn.add_theme_font_override("font", bold)
	left.add_child(turn)

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	pips.mouse_filter = MOUSE_FILTER_IGNORE
	for _i in GameState.ACTIONS_PER_TURN:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(14, 14)
		pip.size_flags_vertical = SIZE_SHRINK_CENTER
		pip.mouse_filter = MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	left.add_child(pips)
	_paint_pips(pips, game.actions_left)

	var actions := Label.new()
	actions.text = "%d / %d" % [game.actions_left, GameState.ACTIONS_PER_TURN]
	actions.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	actions.add_theme_color_override("font_color", Color(0.94, 0.94, 0.97))
	actions.add_theme_font_size_override("font_size", 16)
	left.add_child(actions)

	left.add_child(UiConfig.circle_token(UiConfig.GOLD, int(player["gold"]), Color(0.12, 0.09, 0.02)))
	left.add_child(UiConfig.circle_token(UiConfig.PURPLE, int(player["purple"]), Color.WHITE))
	if _has_skrim(player):
		left.add_child(_skrim_badge())

	_instruction = Label.new()
	_instruction.name = "Instruction"
	_instruction.size_flags_horizontal = SIZE_EXPAND_FILL
	_instruction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_instruction.clip_text = true
	_instruction.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_instruction.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_instruction.add_theme_font_size_override("font_size", 15)
	left.add_child(_instruction)
	_apply_instruction(_instruction_text(player, game, selected_hand_index, gear_replace_index, selecting_move))

	var action_bar := _build_actions(game)
	action_bar.position = Vector2(action_local_x, (header_h - ACTION_H) * 0.5)
	header.add_child(action_bar)

	var end_turn := _end_turn_button(player["color"])
	end_turn.position = Vector2(action_local_x + action_w + END_GAP, (header_h - END_H) * 0.5)
	header.add_child(end_turn)

	var aliens_button := Button.new()
	aliens_button.name = "AliensButton"
	aliens_button.text = "Aliens"
	aliens_button.custom_minimum_size = Vector2(90, 32)
	aliens_button.size = Vector2(90, 32)
	aliens_button.position = Vector2(header_w - 90.0, (header_h - 32.0) * 0.5)
	aliens_button.pressed.connect(func() -> void: checklist_pressed.emit())
	header.add_child(aliens_button)
	return header


func _apply_instruction(text: String) -> void:
	if _instruction == null:
		return
	_instruction.text = text
	_instruction.tooltip_text = text


func _build_actions(game: GameState) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ActionBar"
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(ACTION_GAP))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var move := _action_button("Move", game.can_move(), game.move_reason(), move_pressed)
	move.text = game.move_button_text()
	move.add_theme_font_size_override("font_size", 15)
	if game.can_move() and game.move_button_tip() != "":
		move.tooltip_text = game.move_button_tip()
	row.add_child(move)
	row.add_child(_action_button("Search", game.can_search(), game.search_reason(), search_pressed))
	row.add_child(_action_button("Interact", game.can_interact(), game.interact_reason(), interact_pressed))
	row.add_child(_action_button("Fight", game.can_fight(), game.fight_reason(), fight_pressed))
	return row


func _action_button(title: String, enabled: bool, reason: String, pressed_signal: Signal) -> Button:
	var button := Button.new()
	button.name = title + "Button"
	button.text = title
	button.custom_minimum_size = Vector2(ACTION_W, ACTION_H)
	button.size = Vector2(ACTION_W, ACTION_H)
	button.disabled = not enabled
	if not enabled and reason != "":
		button.tooltip_text = reason
	button.pressed.connect(func() -> void: pressed_signal.emit())
	return button


func _end_turn_button(color: Color) -> Button:
	var button := Button.new()
	button.name = "EndTurn"
	button.text = "End turn"
	button.custom_minimum_size = Vector2(END_W, END_H)
	button.size = Vector2(END_W, END_H)
	button.add_theme_color_override("font_color", Color(0.12, 0.1, 0.16))
	button.add_theme_font_size_override("font_size", 18)
	var normal := _pill_style(Color(0.93, 0.93, 0.96), color)
	var hover := _pill_style(Color(1, 1, 1), color)
	var pressed := _pill_style(color.lerp(Color(0.9, 0.9, 0.93), 0.72), color)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", _pill_style(Color(0.75, 0.75, 0.8), color))
	button.pressed.connect(func() -> void: end_turn_pressed.emit())
	return button


func _pill_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(END_H * 0.5))
	style.content_margin_left = 16
	style.content_margin_right = 16
	return style


func _instruction_text(player: Dictionary, game: GameState, selected_hand_index: int, gear_replace_index: int, selecting_move: bool) -> String:
	var alien_text := game.alien_hint()
	if alien_text != "":
		return alien_text
	if gear_replace_index >= 0:
		return "Choose a gear slot to replace (Esc to cancel)"
	if selected_hand_index >= 0:
		var selected_id := ""
		var hand: Array = player["hand"]
		if selected_hand_index < hand.size():
			selected_id = str(hand[selected_hand_index])
		if selected_id == "grappling_claw":
			return CLAW_HINT
		return MOVE_HINT
	if selecting_move:
		return MOVE_HINT
	if not game.found_card_ids.is_empty():
		return "You found: %s" % _found_names(game.found_card_ids)
	if game.actions_left <= 0:
		return "No actions left."
	return "Move, search, or play a card."


func _paint_pips(pips: HBoxContainer, actions_left: int) -> void:
	for i in pips.get_child_count():
		var pip: Panel = pips.get_child(i)
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


func _fill_hand(host: Control, player: Dictionary, game: GameState, selected_hand_index: int, gear_replace_index: int) -> void:
	var hand: Array = player["hand"]
	for i in hand.size():
		var card_id: String = hand[i]
		var enabled := game.can_play_card(i)
		var reason := ""
		if not enabled:
			reason = game.play_reason(i)
		var selected := i == selected_hand_index or i == gear_replace_index
		var card_view: CardView = CARD_SCENE.instantiate()
		host.add_child(card_view)
		card_view.setup(card_id, i, enabled, false, selected, false, reason)
		if selected:
			card_view.set_meta("fan_raised", true)
		card_view.card_clicked.connect(_on_card_clicked)


func _add_alien_badge(mini: Control, area_index: int, game: GameState, alien_id: String) -> void:
	var card: Dictionary = CardData.get_card(alien_id)
	var mode := str(card.get("alien_mode", ""))
	if mode == "passive":
		_add_mini_label(mini, "Passive")
		return
	if mode != "active":
		return
	var used: Array = game.current_player()["aliens_used_this_turn"]
	if alien_id in used:
		_add_mini_label(mini, "Used")
		return
	var button := Button.new()
	button.text = game.alien_use_label(alien_id)
	button.position = Vector2(2, 86)
	button.size = Vector2(82, 32)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 10)
	button.disabled = not game.can_use_alien(area_index)
	var reason := game.alien_use_reason(area_index)
	if reason != "":
		button.tooltip_text = reason
	button.pressed.connect(func() -> void: alien_use_pressed.emit(area_index))
	mini.add_child(button)


func _add_mini_label(mini: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.position = Vector2(4, 94)
	label.size = Vector2(78, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	mini.add_child(label)


func _add_use_badge(mini: Control, slot: int, game: GameState, card_id: String) -> void:
	var card: Dictionary = CardData.get_card(card_id)
	if str(card.get("gear_mode", "")) != "active":
		return
	var used: Array = game.current_player()["gear_used_this_turn"]
	if card_id in used:
		var label := Label.new()
		label.text = "Used"
		label.mouse_filter = MOUSE_FILTER_IGNORE
		label.position = Vector2(4, 94)
		label.size = Vector2(78, 22)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
		mini.add_child(label)
		return
	var button := Button.new()
	button.text = "Use (1)"
	button.position = Vector2(4, 94)
	button.size = Vector2(78, 22)
	button.disabled = not game.can_use_gear(slot)
	var reason := game.gear_use_reason(slot)
	if reason != "":
		button.tooltip_text = reason
	button.pressed.connect(func() -> void: gear_use_pressed.emit(slot))
	mini.add_child(button)


func _on_card_clicked(hand_index: int) -> void:
	card_clicked.emit(hand_index)


func _on_gear_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			gear_slot_clicked.emit(slot)
			get_viewport().set_input_as_handled()


func _has_skrim(player: Dictionary) -> bool:
	var hand: Array = player["hand"]
	for card_id in hand:
		if str(card_id) == "skrim":
			return true
	return false


func _skrim_badge() -> Label:
	var label := Label.new()
	label.text = "SKRIM"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color8(210, 160, 255))
	var bold := SystemFont.new()
	bold.font_weight = 700
	label.add_theme_font_override("font", bold)
	return label


func _found_names(card_ids: Array) -> String:
	var names: PackedStringArray = PackedStringArray()
	for card_id in card_ids:
		names.append(str(CardData.get_card(str(card_id))["name"]))
	return ", ".join(names)
