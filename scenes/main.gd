extends Node2D

var game := GameState.new()
var _selected_hand_index := -1

@onready var _board: Node2D = $Board
@onready var _hud: Control = $Hud
@onready var _setup: Control = $SetupScreen
@onready var _pass: Control = $PassScreen


func _ready() -> void:
	if BoardData.validate():
		print("Board data OK: 9 tiles, 15 connections")
	for id in BoardData.get_tile_ids():
		var tile_name: String = BoardData.get_tile(id)["name"]
		print("%s: %s" % [tile_name, _neighbor_list(id)])
	_board.visible = false
	_hud.visible = false
	_pass.visible = false
	_setup.visible = true
	_setup.player_count_chosen.connect(_on_player_count_chosen)
	_hud.card_clicked.connect(_on_card_clicked)
	_hud.recall_pressed.connect(_on_recall)
	_hud.end_turn_pressed.connect(_on_end_turn)
	_board.tile_clicked.connect(_on_tile_clicked)
	game.state_changed.connect(_on_state_changed)


func _input(event: InputEvent) -> void:
	if _selected_hand_index < 0 or _pass.visible or _setup.visible:
		return
	var cancel := false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
			cancel = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		cancel = true
	if cancel:
		_clear_selection()
		get_viewport().set_input_as_handled()


func _on_player_count_chosen(count: int) -> void:
	game.start_game(count)
	_setup.visible = false
	_board.visible = true
	_hud.visible = true
	_pass.show_for(game.current_player())


func _on_state_changed() -> void:
	_hud.refresh(game, _selected_hand_index)
	_board.refresh_tokens(game)


func _on_card_clicked(hand_index: int) -> void:
	if not game.can_play_card(hand_index):
		return
	var card_id: String = game.current_player()["hand"][hand_index]
	var card: Dictionary = CardData.get_card(card_id)
	if int(card["action"]) == CardData.ActionType.MOVE:
		var destinations := game.get_move_destinations(hand_index)
		if destinations.is_empty():
			_clear_selection()
			_hud.show_status("No reachable tiles with this card.")
			return
		_selected_hand_index = hand_index
		_board.set_highlighted_tiles(destinations)
		_hud.refresh(game, _selected_hand_index)
	else:
		_clear_selection()
		game.play_placeholder_card(hand_index)


func _on_tile_clicked(tile_id: String) -> void:
	if _selected_hand_index < 0:
		return
	var destinations := game.get_move_destinations(_selected_hand_index)
	if tile_id not in destinations:
		return
	var hand_index := _selected_hand_index
	_clear_selection()
	game.play_move_card(hand_index, tile_id)


func _on_recall() -> void:
	_clear_selection()
	game.recall()


func _on_end_turn() -> void:
	_clear_selection()
	game.end_turn()
	_pass.show_for(game.current_player())


func _clear_selection() -> void:
	var had_selection := _selected_hand_index >= 0
	_selected_hand_index = -1
	_board.clear_highlights()
	if had_selection and not game.players.is_empty():
		_hud.refresh(game, -1)


func _neighbor_list(id: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for neighbor in BoardData.get_neighbors(id):
		var neighbor_name: String = BoardData.get_tile(neighbor["tile"])["name"]
		var path_name: String = BoardData.path_type_name(neighbor["path"])
		parts.append("%s (%s)" % [neighbor_name, path_name])
	return ", ".join(parts)
