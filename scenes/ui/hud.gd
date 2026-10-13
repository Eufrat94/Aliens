extends Control

signal card_clicked(hand_index: int)
signal gear_slot_clicked(slot_index: int)
signal rest_pressed
signal end_turn_pressed

const CLAW_HINT := "Click a highlighted tile to draw from its deck. Right-click or Esc to cancel."

const CARD_SCENE := preload("res://scenes/ui/card_view.tscn")
const CARD_STEP := 128.0
const CARD_LIFT := 15.0
const MOVE_HINT := "Click a highlighted tile to move there. Right-click or Esc to cancel."

@onready var _turn_label: Label = $InfoPanel/Margin/Column/TurnLabel
@onready var _actions_label: Label = $InfoPanel/Margin/Column/ActionsLabel
@onready var _instruction_label: Label = $InfoPanel/Margin/Column/InstructionLabel
@onready var _player_list: VBoxContainer = $InfoPanel/Margin/Column/PlayerScroll/PlayerList
@onready var _hand_row: Control = $HandScroll/HandRow
@onready var _played_row: Control = $PlayedRow
@onready var _gear_title: Label = $GearTitle
@onready var _gear_row: Control = $GearRow
@onready var _rest_button: Button = $RestButton
@onready var _end_turn_button: Button = $EndTurnButton
@onready var _log_label: Label = $LogBar/LogLabel
@onready var _history_overlay: Control = $HistoryOverlay
@onready var _history_list: VBoxContainer = $HistoryOverlay/HistoryPanel/Margin/Column/HistoryScroll/HistoryList

var _game: GameState


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_rest_button.pressed.connect(func() -> void: rest_pressed.emit())
	_end_turn_button.pressed.connect(func() -> void: end_turn_pressed.emit())
	$LogBar/HistoryButton.pressed.connect(_open_history)
	$HistoryOverlay/HistoryPanel/Margin/Column/HistoryClose.pressed.connect(_close_history)


func show_status(text: String) -> void:
	_instruction_label.text = text


func refresh(game: GameState, selected_hand_index: int, gear_replace_index: int = -1) -> void:
	if game.players.is_empty():
		return
	_game = game
	var player: Dictionary = game.current_player()
	if game.public_log.is_empty():
		_log_label.text = ""
	else:
		_log_label.text = str(game.public_log[0])
	_turn_label.text = "%s's turn" % player["name"]
	_turn_label.add_theme_color_override("font_color", player["color"])
	_actions_label.text = "Actions left: %d / %d" % [game.actions_left, GameState.ACTIONS_PER_TURN]
	_rest_button.disabled = not game.can_rest()
	_end_turn_button.disabled = false
	if gear_replace_index >= 0:
		_instruction_label.text = "Choose a gear slot to replace (Esc to cancel)"
	elif selected_hand_index >= 0:
		var selected_id := ""
		if selected_hand_index < player["hand"].size():
			selected_id = str(player["hand"][selected_hand_index])
		if selected_id == "grappling_claw":
			_instruction_label.text = CLAW_HINT
		else:
			_instruction_label.text = MOVE_HINT
	elif not game.found_card_ids.is_empty():
		_instruction_label.text = "You found: %s" % _found_names(game.found_card_ids)
	elif game.actions_left <= 0:
		_instruction_label.text = "No actions left."
	else:
		_instruction_label.text = "Choose a card to play."
	_fill_hand(player, game, selected_hand_index, gear_replace_index)
	_fill_played(player["played"])
	_fill_gear(player["gear"], gear_replace_index)
	_fill_players(game)


func _fill_hand(player: Dictionary, game: GameState, selected_hand_index: int, gear_replace_index: int) -> void:
	_clear_row(_hand_row)
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
		var y := 0.0 if selected else CARD_LIFT
		card_view.position = Vector2(x, y)
		card_view.card_clicked.connect(_on_card_clicked)
		x += CARD_STEP
	_hand_row.custom_minimum_size = Vector2(maxf(x, 10.0), CARD_LIFT + CardView.CARD_SIZE.y)


func _fill_played(played: Array) -> void:
	_clear_row(_played_row)
	var x := 0.0
	for card_id in played:
		var id: String = card_id
		var card_view := _add_card(_played_row, id, -1, false, true, false, false, "")
		card_view.position = Vector2(x, CARD_LIFT)
		x += CARD_STEP


func _fill_gear(gear: Array, gear_replace_index: int) -> void:
	_clear_row(_gear_row)
	_gear_title.text = "Gear (%d/%d)" % [gear.size(), GameState.GEAR_SLOTS]
	var replacing := gear_replace_index >= 0
	for slot in GameState.GEAR_SLOTS:
		var x := slot * CARD_STEP
		if slot < gear.size():
			var card_id: String = gear[slot]
			var card_view := _add_card(_gear_row, card_id, slot, true, false, replacing, false, "")
			card_view.position = Vector2(x, CARD_LIFT)
			if replacing:
				card_view.card_clicked.connect(_on_gear_slot_clicked)
			else:
				card_view.mouse_filter = MOUSE_FILTER_IGNORE
		else:
			var empty := _empty_slot()
			_gear_row.add_child(empty)
			empty.position = Vector2(x, CARD_LIFT)


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


func _empty_slot() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = CardView.CARD_SIZE
	panel.size = CardView.CARD_SIZE
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.06)
	style.border_color = Color(1, 1, 1, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "empty"
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.offset_right = CardView.CARD_SIZE.x
	label.offset_bottom = CardView.CARD_SIZE.y
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	label.add_theme_font_size_override("font_size", 16)
	panel.add_child(label)
	return panel


func _on_card_clicked(hand_index: int) -> void:
	card_clicked.emit(hand_index)


func _on_gear_slot_clicked(slot_index: int) -> void:
	gear_slot_clicked.emit(slot_index)


func _fill_players(game: GameState) -> void:
	_clear_row(_player_list)
	for player in game.players:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 0)
		block.mouse_filter = MOUSE_FILTER_IGNORE
		_player_list.add_child(block)
		var title: String = player["name"]
		if int(player["index"]) == game.current_index:
			title += " (current)"
		block.add_child(_info_label(title, player["color"], 16))
		var tile_name: String = BoardData.get_tile(player["tile"])["name"]
		var detail := Color(0.9, 0.9, 0.94)
		block.add_child(_info_label("On: %s" % tile_name, detail, 14))
		block.add_child(_info_label("Hand: %s" % _count_phrase(player["hand"].size()), detail, 14))
		block.add_child(_info_label("Played: %s" % _name_list(player["played"]), detail, 14))
		block.add_child(_info_label("Gold: %d · Purple: %d" % [player["gold"], player["purple"]], detail, 14))
		block.add_child(_info_label("Gear: %s" % _name_list(player["gear"]), detail, 14))


func _info_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _open_history() -> void:
	if _game == null:
		return
	_clear_row(_history_list)
	if _game.public_log.is_empty():
		_history_list.add_child(_info_label("No public events yet.", Color(0.8, 0.8, 0.86), 16))
	else:
		for line in _game.public_log:
			_history_list.add_child(_info_label(str(line), Color(0.92, 0.92, 0.96), 16))
	_history_overlay.visible = true


func _close_history() -> void:
	_history_overlay.visible = false


func _found_names(card_ids: Array) -> String:
	var names: PackedStringArray = PackedStringArray()
	for card_id in card_ids:
		names.append(str(CardData.get_card(str(card_id))["name"]))
	return ", ".join(names)


func _count_phrase(count: int) -> String:
	if count == 1:
		return "1 card"
	return "%d cards" % count


func _name_list(card_ids: Array) -> String:
	if card_ids.is_empty():
		return "—"
	var names: PackedStringArray = PackedStringArray()
	for card_id in card_ids:
		var id: String = card_id
		names.append(CardData.get_card(id)["name"])
	return ", ".join(names)


func _clear_row(row: Node) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
