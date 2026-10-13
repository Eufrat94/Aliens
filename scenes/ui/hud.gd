extends Control

signal card_clicked(hand_index: int)
signal recall_pressed
signal end_turn_pressed

const CARD_SCENE := preload("res://scenes/ui/card_view.tscn")
const CARD_STEP := 152.0
const MOVE_HINT := "Click a highlighted tile to move there. Right-click or Esc to cancel."

@onready var _turn_label: Label = $InfoPanel/Margin/Column/TurnLabel
@onready var _actions_label: Label = $InfoPanel/Margin/Column/ActionsLabel
@onready var _instruction_label: Label = $InfoPanel/Margin/Column/InstructionLabel
@onready var _player_list: VBoxContainer = $InfoPanel/Margin/Column/PlayerList
@onready var _hand_row: Control = $HandRow
@onready var _played_row: Control = $PlayedRow
@onready var _recall_button: Button = $RecallButton
@onready var _end_turn_button: Button = $EndTurnButton


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_recall_button.pressed.connect(func() -> void: recall_pressed.emit())
	_end_turn_button.pressed.connect(func() -> void: end_turn_pressed.emit())


func show_status(text: String) -> void:
	_instruction_label.text = text


func refresh(game: GameState, selected_hand_index: int) -> void:
	if game.players.is_empty():
		return
	var player: Dictionary = game.current_player()
	_turn_label.text = "%s's turn" % player["name"]
	_turn_label.add_theme_color_override("font_color", player["color"])
	_actions_label.text = "Actions left: %d / %d" % [game.actions_left, GameState.ACTIONS_PER_TURN]
	_recall_button.disabled = not game.can_recall()
	_end_turn_button.disabled = false
	if selected_hand_index >= 0:
		_instruction_label.text = MOVE_HINT
	elif game.actions_left <= 0:
		_instruction_label.text = "No actions left."
	else:
		_instruction_label.text = "Choose a card to play."
	_fill_cards(_hand_row, player["hand"], true, game, selected_hand_index)
	_fill_cards(_played_row, player["played"], false, game, -1)
	_fill_players(game)


func _fill_cards(row: Control, card_ids: Array, in_hand: bool, game: GameState, selected_hand_index: int) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	var x := 0.0
	for i in card_ids.size():
		var card_view: Panel = CARD_SCENE.instantiate()
		row.add_child(card_view)
		var playable := in_hand and game.can_play_card(i)
		var selected := in_hand and i == selected_hand_index
		card_view.setup(card_ids[i], i if in_hand else -1, playable, not in_hand, selected)
		var lift := -15.0 if selected else 0.0
		card_view.position = Vector2(x, lift)
		if in_hand:
			card_view.card_clicked.connect(_on_card_clicked)
		x += CARD_STEP


func _on_card_clicked(hand_index: int) -> void:
	card_clicked.emit(hand_index)


func _fill_players(game: GameState) -> void:
	for child in _player_list.get_children():
		_player_list.remove_child(child)
		child.queue_free()
	for player in game.players:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 0)
		block.mouse_filter = MOUSE_FILTER_IGNORE
		_player_list.add_child(block)
		var title := player["name"] as String
		if int(player["index"]) == game.current_index:
			title += " (current)"
		block.add_child(_info_label(title, player["color"], 16))
		var tile_name: String = BoardData.get_tile(player["tile"])["name"]
		var detail := Color(0.9, 0.9, 0.94)
		block.add_child(_info_label("On: %s" % tile_name, detail, 14))
		block.add_child(_info_label("Hand: %s" % _count_phrase(player["hand"].size()), detail, 14))
		block.add_child(_info_label("Played: %s" % _played_phrase(player["played"]), detail, 14))


func _info_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _count_phrase(count: int) -> String:
	if count == 1:
		return "1 card"
	return "%d cards" % count


func _played_phrase(played: Array) -> String:
	if played.is_empty():
		return "—"
	var names: PackedStringArray = PackedStringArray()
	for card_id in played:
		names.append(CardData.get_card(card_id)["name"])
	return ", ".join(names)
