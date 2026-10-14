extends Node2D

const BOARD_REGION := Rect2(400, 0, 1120, 1040)

var game := GameState.new()
var _selected_hand_index := -1
var _gear_replace_index := -1

@onready var _board: GameBoard = $Board
@onready var _seats: Control = $SeatLayer
@onready var _hud: Control = $Hud
@onready var _setup: Control = $SetupScreen
@onready var _pass: Control = $PassScreen
@onready var _popup: Control = $PrivatePopup
@onready var _market: Control = $MarketPanel


func _ready() -> void:
	_fit_board()
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
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
	_seats.card_clicked.connect(_on_card_clicked)
	_seats.gear_slot_clicked.connect(_on_gear_slot_clicked)
	_seats.rest_pressed.connect(_on_rest)
	_seats.end_turn_pressed.connect(_on_end_turn)
	_board.tile_clicked.connect(_on_tile_clicked)
	_pass.dismissed.connect(_on_pass_dismissed)
	_popup.card_picked.connect(_on_popup_card)
	_popup.button_picked.connect(_on_popup_button)
	_market.buy_pressed.connect(_on_market_buy)
	_market.sell_pressed.connect(_on_market_sell)
	_market.closed.connect(_on_market_closed)
	_market.visible = false
	game.state_changed.connect(_on_state_changed)
	game.prompt_opened.connect(_on_prompt_opened)
	game.prompt_closed.connect(_on_prompt_closed)


func _input(event: InputEvent) -> void:
	if _is_fullscreen_toggle(event):
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if _market.visible:
		if _is_cancel(event):
			_close_market()
			get_viewport().set_input_as_handled()
		return
	if _pass.visible or _setup.visible or _popup.visible:
		return
	if not _is_cancel(event):
		return
	if _gear_replace_index >= 0:
		_gear_replace_index = -1
		_refresh_view()
		get_viewport().set_input_as_handled()
		return
	if _selected_hand_index >= 0:
		_clear_move_selection()
		get_viewport().set_input_as_handled()


func _on_player_count_chosen(count: int) -> void:
	game.start_game(count)
	_setup.visible = false
	_board.visible = true
	_hud.visible = true
	_pass.show_for(game.current_player())


func _on_state_changed() -> void:
	_refresh_view()
	_board.refresh_tokens(game)
	_board.refresh_decks(game)
	if _market.visible:
		_market.refresh(game)


func _refresh_view() -> void:
	if game.players.is_empty():
		return
	_hud.refresh_log(game)
	_seats.refresh(game, _selected_hand_index, _gear_replace_index)


func _on_card_clicked(hand_index: int) -> void:
	_gear_replace_index = -1
	var card_id: String = game.current_player()["hand"][hand_index]
	var card: Dictionary = CardData.get_card(card_id)
	var kind := int(card["kind"])
	if kind == CardData.Kind.GEAR:
		_clear_move_selection(false)
		if not game.can_equip(hand_index):
			_refresh_view()
			return
		if game.current_player()["gear"].size() >= GameState.GEAR_SLOTS:
			_gear_replace_index = hand_index
			_refresh_view()
			return
		_selected_hand_index = -1
		game.equip_gear(hand_index, -1)
		return
	if kind == CardData.Kind.RESOURCE:
		_clear_move_selection(false)
		_refresh_view()
		return
	if not game.can_play_card(hand_index):
		_clear_move_selection(false)
		_refresh_view()
		return
	if int(card["action"]) == CardData.ActionType.MOVE:
		var destinations := game.get_move_destinations(hand_index)
		if destinations.is_empty():
			_clear_move_selection(false)
			_refresh_view()
			_seats.show_status("No reachable tiles with this card.")
			return
		_selected_hand_index = hand_index
		_board.set_highlighted_tiles(destinations)
		_refresh_view()
		return
	_clear_move_selection(false)
	_selected_hand_index = -1
	if int(card["action"]) == CardData.ActionType.SEARCH:
		if card_id == "grappling_claw":
			var targets := game.get_claw_targets()
			if targets.is_empty():
				_seats.show_status("No deck next to you.")
				return
			_selected_hand_index = hand_index
			_board.set_highlighted_tiles(targets)
			_refresh_view()
			return
		game.play_search_card(hand_index)
	elif int(card["action"]) == CardData.ActionType.INTERACT:
		if game.begin_market(hand_index):
			_market.present(game)
	else:
		game.play_placeholder_card(hand_index)


func _on_tile_clicked(tile_id: String) -> void:
	if _popup.visible or _market.visible or _gear_replace_index >= 0 or _selected_hand_index < 0:
		return
	var hand_index := _selected_hand_index
	var card_id: String = game.current_player()["hand"][hand_index]
	if card_id == "grappling_claw":
		var targets := game.get_claw_targets()
		if tile_id not in targets:
			return
		_clear_move_selection(false)
		game.play_claw(hand_index, tile_id)
		return
	var destinations := game.get_move_destinations(hand_index)
	if tile_id not in destinations:
		return
	_clear_move_selection(false)
	game.play_move_card(hand_index, tile_id)


func _on_gear_slot_clicked(slot_index: int) -> void:
	var hand_index := _gear_replace_index
	_gear_replace_index = -1
	if hand_index < 0:
		return
	game.equip_gear(hand_index, slot_index)


func _on_rest() -> void:
	_gear_replace_index = -1
	_clear_move_selection(false)
	if not game.rest():
		_refresh_view()


func _on_end_turn() -> void:
	if not game.market_visit.is_empty():
		return
	_gear_replace_index = -1
	_clear_move_selection(false)
	game.end_turn()
	if game.prompt.is_empty():
		_pass.show_for(game.current_player())


func _on_pass_dismissed() -> void:
	game.begin_turn()


func _on_prompt_opened(prompt: Dictionary) -> void:
	_popup.present(prompt)


func _on_prompt_closed() -> void:
	_popup.dismiss()


func _on_popup_card(index: int) -> void:
	game.choose_prompt_card(index)


func _on_popup_button(label: String) -> void:
	game.choose_prompt_button(label)


func _on_market_buy(slot: int) -> void:
	game.market_buy(slot)


func _on_market_sell(hand_index: int) -> void:
	game.market_sell(hand_index)


func _on_market_closed() -> void:
	_close_market()


func _close_market() -> void:
	_market.dismiss()
	game.market_finish()


func _clear_move_selection(refresh_hud: bool = true) -> void:
	var had_selection := _selected_hand_index >= 0
	_selected_hand_index = -1
	_board.clear_highlights()
	if refresh_hud and had_selection and not game.players.is_empty():
		_refresh_view()


func _fit_board() -> void:
	var bounds: Rect2 = _board.content_bounds()
	var margin := 6.0
	var avail := BOARD_REGION.size - Vector2(margin, margin) * 2.0
	var fit := minf(avail.x / bounds.size.x, avail.y / bounds.size.y)
	_board.scale = Vector2(fit, fit)
	var scaled: Vector2 = bounds.size * fit
	var top_left: Vector2 = BOARD_REGION.position + (BOARD_REGION.size - scaled) * 0.5
	_board.position = top_left - bounds.position * fit
	_place_legend(top_left, scaled)


func _place_legend(board_top_left: Vector2, scaled: Vector2) -> void:
	var legend := _seats.get_node("Legend") as Control
	var width := 128.0
	var height := 96.0
	var x := BOARD_REGION.position.x + 12.0
	var board_bottom := board_top_left.y + scaled.y
	var y := board_bottom + 8.0
	if y + height > BOARD_REGION.end.y - 4.0:
		y = BOARD_REGION.end.y - height - 4.0
	legend.offset_left = x
	legend.offset_top = y
	legend.offset_right = x + width
	legend.offset_bottom = y + height


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _is_fullscreen_toggle(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11


func _is_cancel(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		return true
	return false


func _neighbor_list(id: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for neighbor in BoardData.get_neighbors(id):
		var neighbor_name: String = BoardData.get_tile(neighbor["tile"])["name"]
		var path_name: String = BoardData.path_type_name(neighbor["path"])
		parts.append("%s (%s)" % [neighbor_name, path_name])
	return ", ".join(parts)
