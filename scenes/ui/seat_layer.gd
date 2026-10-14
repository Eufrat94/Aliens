extends Control

signal card_clicked(hand_index: int)
signal gear_slot_clicked(slot_index: int)
signal gear_use_pressed(slot_index: int)
signal move_pressed
signal search_pressed
signal interact_pressed
signal fight_pressed
signal end_turn_pressed

const SEAT_SCENE := preload("res://scenes/ui/player_seat.tscn")
const STRIP_SCENE := preload("res://scenes/ui/opponent_strip.tscn")

var _bottom: Control


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func refresh(game: GameState, selected_hand_index: int = -1, gear_replace_index: int = -1, selecting_move: bool = false) -> void:
	_clear_seats()
	_bottom = null
	if game.players.is_empty():
		return
	var count := game.players.size()
	for player in game.players:
		var who: Dictionary = player
		var index := int(who["index"])
		var offset := (index - game.current_index + count) % count
		if offset == 0:
			_add_bottom(who, game, selected_hand_index, gear_replace_index, selecting_move)
		else:
			_add_opponent(who, _slot_for(offset, count))


func conceal() -> void:
	_clear_seats()
	_bottom = null


func show_status(text: String) -> void:
	if _bottom != null:
		_bottom.call("set_instruction", text)


func _slot_for(offset: int, count: int) -> String:
	if count == 2:
		return "top"
	if count == 3:
		return "left" if offset == 1 else "right"
	if offset == 1:
		return "left"
	if offset == 2:
		return "top"
	return "right"


func _add_bottom(player: Dictionary, game: GameState, selected_hand_index: int, gear_replace_index: int, selecting_move: bool) -> void:
	var seat: Control = SEAT_SCENE.instantiate()
	add_child(seat)
	_place_upright(seat, UiConfig.BOTTOM_REGION)
	seat.call("show_player", player, game, selected_hand_index, gear_replace_index, selecting_move)
	_bottom = seat
	seat.connect("card_clicked", _emit_card)
	seat.connect("gear_slot_clicked", _emit_gear)
	seat.connect("gear_use_pressed", _emit_gear_use)
	seat.connect("move_pressed", _emit_move)
	seat.connect("search_pressed", _emit_search)
	seat.connect("interact_pressed", _emit_interact)
	seat.connect("fight_pressed", _emit_fight)
	seat.connect("end_turn_pressed", _emit_end)


func _add_opponent(player: Dictionary, slot: String) -> void:
	var strip: Control = STRIP_SCENE.instantiate()
	add_child(strip)
	var region := _region(slot)
	var column := slot != "top" and not UiConfig.ROTATE_SIDE_SEATS
	if column or slot == "top":
		_place_upright(strip, region)
	elif slot == "left":
		strip.size = Vector2(region.size.y, region.size.x)
		strip.pivot_offset = Vector2.ZERO
		strip.rotation = PI / 2.0
		strip.position = Vector2(region.end.x, region.position.y)
	else:
		strip.size = Vector2(region.size.y, region.size.x)
		strip.pivot_offset = Vector2.ZERO
		strip.rotation = -PI / 2.0
		strip.position = Vector2(region.position.x, region.end.y)
	strip.call("show_player", player, column)


func _region(slot: String) -> Rect2:
	if slot == "left":
		return UiConfig.LEFT_REGION
	if slot == "right":
		return UiConfig.RIGHT_REGION
	return UiConfig.TOP_REGION


func _place_upright(seat: Control, region: Rect2) -> void:
	seat.rotation = 0.0
	seat.pivot_offset = Vector2.ZERO
	seat.position = region.position
	seat.size = region.size


func _emit_card(hand_index: int) -> void:
	card_clicked.emit(hand_index)


func _emit_gear(slot_index: int) -> void:
	gear_slot_clicked.emit(slot_index)


func _emit_gear_use(slot_index: int) -> void:
	gear_use_pressed.emit(slot_index)


func _emit_move() -> void:
	move_pressed.emit()


func _emit_search() -> void:
	search_pressed.emit()


func _emit_interact() -> void:
	interact_pressed.emit()


func _emit_fight() -> void:
	fight_pressed.emit()


func _emit_end() -> void:
	end_turn_pressed.emit()


func _clear_seats() -> void:
	for child in get_children():
		if str(child.name) == "Legend":
			continue
		remove_child(child)
		child.queue_free()
