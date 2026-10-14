extends Node2D

var game := GameState.new()
var _selected_hand_index := -1
var _gear_replace_index := -1
var _selecting_move := false

@onready var _board: GameBoard = $GameLayer/Board
@onready var _seats: Control = $GameLayer/SeatLayer
@onready var _hud: Control = $GameLayer/Hud
@onready var _setup: Control = $OverlayLayer/SetupScreen
@onready var _pass: Control = $OverlayLayer/PassScreen
@onready var _popup: Control = $PopupLayer/PrivatePopup
@onready var _market: Control = $PopupLayer/MarketPanel
@onready var _preview: Control = $PreviewLayer/CardPreview

var _checklist: AlienChecklist
var _skrim: SkrimBanner
var _win: WinScreen


func _ready() -> void:
	_checklist = AlienChecklist.new()
	$PopupLayer.add_child(_checklist)
	_checklist.alien_toggled.connect(_on_checklist_toggled)
	_skrim = SkrimBanner.new()
	$BannerLayer.add_child(_skrim)
	_win = WinScreen.new()
	$WinLayer.add_child(_win)
	_win.new_game_pressed.connect(_on_new_game)
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
	_seats.gear_use_pressed.connect(_on_gear_use)
	_seats.move_pressed.connect(_on_move)
	_seats.search_pressed.connect(_on_search)
	_seats.interact_pressed.connect(_on_interact)
	_seats.fight_pressed.connect(_on_fight)
	_seats.end_turn_pressed.connect(_on_end_turn)
	_seats.checklist_pressed.connect(_on_checklist)
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
	game.turn_ended.connect(_on_turn_ended)
	game.skrim_announced.connect(_on_skrim)
	game.game_won.connect(_on_game_won)


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
	if _popup.visible:
		if _is_cancel(event):
			game.dismiss_prompt()
			get_viewport().set_input_as_handled()
		return
	if _checklist.visible and _is_cancel(event):
		_checklist.hide_checklist()
		get_viewport().set_input_as_handled()
		return
	if _pass.visible or _setup.visible:
		return
	if not _is_cancel(event):
		return
	if _gear_replace_index >= 0 or _selected_hand_index >= 0 or _selecting_move:
		_clear_selection()
		get_viewport().set_input_as_handled()


func _on_player_count_chosen(count: int) -> void:
	game.start_game(count)
	_setup.visible = false
	_board.visible = true
	_hud.visible = true
	if game.game_over:
		return
	_present_pass()


func _on_state_changed() -> void:
	if _pass.visible:
		_hud.refresh_log(game)
		_board.refresh_tokens(game)
		_board.refresh_decks(game)
		_seats.conceal()
		return
	_refresh_view()
	_board.refresh_tokens(game)
	_board.refresh_decks(game)
	if _market.visible:
		_market.refresh(game)


func _refresh_view() -> void:
	if game.players.is_empty():
		return
	_hud.refresh_log(game)
	_seats.refresh(game, _selected_hand_index, _gear_replace_index, _selecting_move)
	_warn_if_popup_missing()


func _on_card_clicked(hand_index: int) -> void:
	_selecting_move = false
	_board.clear_highlights()
	_gear_replace_index = -1
	var card_id: String = game.current_player()["hand"][hand_index]
	var card: Dictionary = CardData.get_card(card_id)
	var kind := int(card["kind"])
	if kind == CardData.Kind.GEAR:
		if not game.can_play_card(hand_index):
			_selected_hand_index = -1
			_refresh_view()
			return
		if game.current_player()["gear"].size() >= GameState.GEAR_SLOTS:
			_selected_hand_index = -1
			_gear_replace_index = hand_index
			_refresh_view()
			return
		_selected_hand_index = -1
		game.play_gear(hand_index)
		return
	if kind == CardData.Kind.RESOURCE:
		_selected_hand_index = -1
		_refresh_view()
		return
	if kind == CardData.Kind.ALIEN:
		_selected_hand_index = -1
		if game.can_play_card(hand_index):
			game.play_alien(hand_index)
		else:
			_refresh_view()
		return
	if not game.can_play_card(hand_index):
		_selected_hand_index = -1
		_refresh_view()
		return
	if card_id == "scrap_hoverboard" or card_id == "patchwork_glider":
		var destinations := game.ability_destinations(hand_index)
		_selected_hand_index = hand_index
		_board.set_highlighted_tiles(destinations)
		_refresh_view()
		return
	if card_id == "grappling_claw":
		var targets := game.get_claw_targets()
		_selected_hand_index = hand_index
		_board.set_highlighted_tiles(targets)
		_refresh_view()
		return
	_selected_hand_index = -1
	game.play_ability(hand_index)


func _on_tile_clicked(tile_id: String) -> void:
	if _popup.visible or _market.visible or _pass.visible or _setup.visible or _gear_replace_index >= 0:
		return
	if _selected_hand_index >= 0:
		var hand_index := _selected_hand_index
		var card_id: String = game.current_player()["hand"][hand_index]
		if card_id == "grappling_claw":
			if tile_id not in game.get_claw_targets():
				return
			_clear_selection(false)
			game.play_ability(hand_index, "", tile_id)
			return
		if tile_id not in game.ability_destinations(hand_index):
			return
		_clear_selection(false)
		game.play_ability(hand_index, tile_id)
		return
	if tile_id not in game.get_move_destinations():
		return
	_selecting_move = false
	_board.clear_highlights()
	game.do_move(tile_id)


func _on_gear_slot_clicked(slot_index: int) -> void:
	var hand_index := _gear_replace_index
	_gear_replace_index = -1
	_selected_hand_index = -1
	if hand_index < 0:
		return
	game.play_gear(hand_index, slot_index)


func _on_gear_use(slot_index: int) -> void:
	_clear_selection(false)
	game.use_gear(slot_index)


func _on_move() -> void:
	_gear_replace_index = -1
	_selected_hand_index = -1
	if not game.can_move():
		_selecting_move = false
		_board.clear_highlights()
		_refresh_view()
		return
	_selecting_move = true
	_board.set_highlighted_tiles(game.get_move_destinations())
	_refresh_view()


func _on_search() -> void:
	_clear_selection(false)
	game.do_search()


func _on_interact() -> void:
	_clear_selection(false)
	if game.do_interact() and not game.market_visit.is_empty():
		_hide_preview()
		_market.present(game)


func _on_fight() -> void:
	pass


func _on_end_turn() -> void:
	if not game.market_visit.is_empty():
		return
	_clear_selection(false)
	game.end_turn()


func _on_turn_ended() -> void:
	if game.prompt.is_empty() and not _pass.visible:
		_present_pass()


func _on_pass_dismissed() -> void:
	_preview.call("unsuppress")
	game.begin_turn()
	_refresh_view()


func _on_prompt_opened(prompt: Dictionary) -> void:
	_hide_preview()
	_popup.present(prompt)


func _on_prompt_closed() -> void:
	_popup.dismiss()
	call_deferred("_after_prompt_closed")


func _after_prompt_closed() -> void:
	if not game.prompt.is_empty():
		if not _popup.visible:
			_popup.present(game.prompt)
		if not _pass.visible:
			_refresh_view()
		return
	if _pass.visible:
		_seats.conceal()
		return
	_refresh_view()


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


func _present_pass() -> void:
	_hide_preview()
	_preview.call("suppress")
	if _popup.visible:
		_popup.dismiss()
	if _checklist.visible:
		_checklist.hide_checklist()
	_seats.conceal()
	_pass.show_for(game.current_player())


func _on_checklist() -> void:
	if game.players.is_empty() or game.game_over or _pass.visible:
		return
	_checklist.show_for(game.current_player())


func _on_checklist_toggled(alien_id: String, on: bool) -> void:
	game.set_checklist(alien_id, on)


func _on_skrim(player_name: String) -> void:
	_skrim.show_for(player_name)


func _on_game_won(player_index: int) -> void:
	if _checklist.visible:
		_checklist.hide_checklist()
	var player: Dictionary = game.players[player_index]
	var missing := str(CardData.get_card(game.missing_alien)["name"])
	_win.show_winner(player, missing)


func _on_new_game() -> void:
	_win.visible = false
	_skrim.visible = false
	if _checklist.visible:
		_checklist.hide_checklist()
	if _popup.visible:
		_popup.dismiss()
	if _market.visible:
		_market.dismiss()
	_pass.visible = false
	_preview.call("unsuppress")
	_seats.conceal()
	_board.visible = false
	_hud.visible = false
	_setup.visible = true


func _hide_preview() -> void:
	_preview.call("end_hover")


func _warn_if_popup_missing() -> void:
	if game.players.is_empty() or _pass.visible or _setup.visible:
		return
	var waiting := not game.prompt.is_empty() or not game.market_visit.is_empty()
	var showing := _popup.visible or _market.visible
	if waiting and not showing:
		print("Warning: the game is waiting on a popup, but none is visible.")
	if game.actions_left <= 0 or waiting or showing:
		return
	var move_button := _find_action_button("Move")
	var search_button := _find_action_button("Search")
	if move_button != null and move_button.disabled == game.can_move():
		print("Warning: Move is out of date while actions are left.")
	if search_button != null and search_button.disabled == game.can_search():
		print("Warning: Search is out of date while actions are left.")


func _find_action_button(title: String) -> Button:
	var found: Button = _find_button(_seats, title)
	return found


func _find_button(node: Node, title: String) -> Button:
	if node is Button and (node as Button).text == title:
		return node as Button
	for child in node.get_children():
		var match_button := _find_button(child, title)
		if match_button != null:
			return match_button
	return null


func _clear_selection(refresh_hud: bool = true) -> void:
	var had_selection := _selected_hand_index >= 0 or _gear_replace_index >= 0 or _selecting_move
	_selected_hand_index = -1
	_gear_replace_index = -1
	_selecting_move = false
	_board.clear_highlights()
	if refresh_hud and had_selection and not game.players.is_empty():
		_refresh_view()


func _fit_board() -> void:
	var bounds: Rect2 = _board.content_bounds()
	var margin := 6.0
	var region := UiConfig.BOARD_REGION
	var avail := region.size - Vector2(margin, margin) * 2.0
	var fit := minf(avail.x / bounds.size.x, avail.y / bounds.size.y)
	_board.scale = Vector2(fit, fit)
	var scaled: Vector2 = bounds.size * fit
	var top_left: Vector2 = region.position + (region.size - scaled) * 0.5
	_board.position = top_left - bounds.position * fit
	_place_legend(top_left, scaled)


func _place_legend(_board_top_left: Vector2, _scaled: Vector2) -> void:
	var legend := _seats.get_node("Legend") as Control
	var crystal: Rect2 = _board.tile_rect("crystal_mount")
	var lake: Rect2 = _board.tile_rect("lake")
	var width := 124.0
	var height := 86.0
	var gap := lake.position.x - crystal.end.x
	var x := crystal.end.x + (gap - width) * 0.5
	var y := crystal.position.y + 4.0
	legend.position = Vector2(x, y)
	legend.size = Vector2(width, height)
	_hud.place_discard(crystal, lake, Rect2(legend.position, legend.size))


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
