extends Panel

signal card_clicked(hand_index: int)
signal gear_slot_clicked(slot_index: int)
signal rest_pressed
signal end_turn_pressed

const MINI_SCENE := preload("res://scenes/ui/mini_card.tscn")
const CARD_SCENE := preload("res://scenes/ui/card_view.tscn")
const CLAW_HINT := "Click a highlighted tile to draw from its deck. Right-click or Esc to cancel."
const MOVE_HINT := "Click a highlighted tile to move there. Right-click or Esc to cancel."

var _instruction: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true


func show_player(player: Dictionary, game: GameState, selected_hand_index: int, gear_replace_index: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_instruction = null
	_apply_chrome(player["color"])
	var inset := 12.0
	var header_h := 36.0
	var header := _build_header(player, game, selected_hand_index, gear_replace_index)
	header.position = Vector2(inset, 8)
	header.size = Vector2(size.x - inset * 2.0, header_h)
	add_child(header)

	var row_top := 8.0 + header_h + 4.0
	var row_h := size.y - row_top - 10.0
	var gap := 16.0
	var gear_w := UiConfig.MINI_SIZE.x * 3.0 + 8.0
	var played_w := 380.0
	var inner_w := size.x - inset * 2.0
	var hand_w := inner_w - gear_w - played_w - gap * 2.0
	var hand_x := inset
	var played_x := hand_x + hand_w + gap
	var gear_x := played_x + played_w + gap

	var hand := Control.new()
	hand.mouse_filter = MOUSE_FILTER_IGNORE
	hand.position = Vector2(hand_x, row_top)
	add_child(hand)
	_fill_hand(hand, player, game, selected_hand_index, gear_replace_index)
	UiConfig.layout_fan(hand, hand_w, CardView.CARD_SIZE, row_h - CardView.CARD_SIZE.y)

	var played_box := Control.new()
	played_box.mouse_filter = MOUSE_FILTER_IGNORE
	played_box.position = Vector2(played_x, row_top)
	played_box.size = Vector2(played_w, row_h)
	add_child(played_box)
	var played: Array = player["played"]
	if played.is_empty():
		var empty := Label.new()
		empty.text = "—"
		empty.mouse_filter = MOUSE_FILTER_IGNORE
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		empty.add_theme_font_size_override("font_size", 22)
		played_box.add_child(empty)
	else:
		var played_host := Control.new()
		played_host.mouse_filter = MOUSE_FILTER_IGNORE
		played_box.add_child(played_host)
		for card_id in played:
			var mini: Control = MINI_SCENE.instantiate()
			played_host.add_child(mini)
			mini.call("setup", str(card_id))
			mini.modulate = Color(1, 1, 1, 0.6)
		UiConfig.layout_fan(played_host, played_w, UiConfig.MINI_SIZE, row_h - UiConfig.MINI_SIZE.y)

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
			mini.call("setup", str(gear[slot]))
			mini.call("set_selected", replacing)
			if replacing:
				mini.gui_input.connect(_on_gear_input.bind(slot))
		else:
			gear_host.add_child(UiConfig.empty_slot())
	UiConfig.layout_fan(gear_host, gear_w, UiConfig.MINI_SIZE, row_h - UiConfig.MINI_SIZE.y)


func set_instruction(text: String) -> void:
	if _instruction != null:
		_instruction.text = text


func _apply_chrome(color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UiConfig.CURRENT_BG
	style.border_color = color
	style.set_border_width_all(6)
	style.set_corner_radius_all(12)
	add_theme_stylebox_override("panel", style)


func _build_header(player: Dictionary, game: GameState, selected_hand_index: int, gear_replace_index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var turn := Label.new()
	turn.text = "%s's turn" % str(player["name"])
	turn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn.add_theme_color_override("font_color", player["color"])
	turn.add_theme_font_size_override("font_size", 20)
	var bold := SystemFont.new()
	bold.font_weight = 700
	turn.add_theme_font_override("font", bold)
	row.add_child(turn)

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	pips.mouse_filter = MOUSE_FILTER_IGNORE
	for _i in GameState.ACTIONS_PER_TURN:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(14, 14)
		pip.size_flags_vertical = SIZE_SHRINK_CENTER
		pip.mouse_filter = MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	row.add_child(pips)
	_paint_pips(pips, game.actions_left)

	var actions := Label.new()
	actions.text = "%d / %d" % [game.actions_left, GameState.ACTIONS_PER_TURN]
	actions.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	actions.add_theme_color_override("font_color", Color(0.94, 0.94, 0.97))
	actions.add_theme_font_size_override("font_size", 16)
	row.add_child(actions)

	row.add_child(UiConfig.circle_token(UiConfig.GOLD, int(player["gold"]), Color(0.12, 0.09, 0.02)))
	row.add_child(UiConfig.circle_token(UiConfig.PURPLE, int(player["purple"]), Color.WHITE))

	_instruction = Label.new()
	_instruction.size_flags_horizontal = SIZE_EXPAND_FILL
	_instruction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_instruction.clip_text = true
	_instruction.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_instruction.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_instruction.add_theme_font_size_override("font_size", 15)
	_instruction.text = _instruction_text(player, game, selected_hand_index, gear_replace_index)
	row.add_child(_instruction)

	var rest := Button.new()
	rest.text = "Rest (1 action)"
	rest.custom_minimum_size = Vector2(150, 32)
	rest.disabled = not game.can_rest()
	rest.pressed.connect(func() -> void: rest_pressed.emit())
	row.add_child(rest)

	var end_turn := Button.new()
	end_turn.text = "End turn"
	end_turn.custom_minimum_size = Vector2(120, 32)
	end_turn.pressed.connect(func() -> void: end_turn_pressed.emit())
	row.add_child(end_turn)
	return row


func _instruction_text(player: Dictionary, game: GameState, selected_hand_index: int, gear_replace_index: int) -> String:
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
	if not game.found_card_ids.is_empty():
		return "You found: %s" % _found_names(game.found_card_ids)
	if game.actions_left <= 0:
		return "No actions left."
	return "Choose a card to play."


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
	var fresh: Array = player["fresh"]
	for i in hand.size():
		var card_id: String = hand[i]
		var enabled := _hand_enabled(game, i)
		var reason := ""
		if not enabled:
			reason = game.play_reason(i)
		var selected := i == selected_hand_index or i == gear_replace_index
		var is_new: bool = bool(fresh[i])
		var card_view: CardView = CARD_SCENE.instantiate()
		host.add_child(card_view)
		card_view.setup(card_id, i, enabled, false, selected, is_new, reason)
		if selected:
			card_view.set_meta("fan_raised", true)
		card_view.card_clicked.connect(_on_card_clicked)


func _hand_enabled(game: GameState, index: int) -> bool:
	var card: Dictionary = CardData.get_card(game.current_player()["hand"][index])
	if int(card["kind"]) == CardData.Kind.GEAR:
		return game.can_equip(index)
	return game.can_play_card(index)


func _on_card_clicked(hand_index: int) -> void:
	card_clicked.emit(hand_index)


func _on_gear_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			gear_slot_clicked.emit(slot)
			get_viewport().set_input_as_handled()


func _found_names(card_ids: Array) -> String:
	var names: PackedStringArray = PackedStringArray()
	for card_id in card_ids:
		names.append(str(CardData.get_card(str(card_id))["name"]))
	return ", ".join(names)
