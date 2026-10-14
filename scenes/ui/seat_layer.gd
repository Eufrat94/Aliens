extends Control

signal card_clicked(hand_index: int)
signal gear_slot_clicked(slot_index: int)
signal rest_pressed
signal end_turn_pressed

const SEAT_SCENE := preload("res://scenes/ui/player_seat.tscn")
const SEAT_RECTS: Array[Rect2] = [
	Rect2(8, 548, 384, 524),
	Rect2(8, 8, 384, 524),
	Rect2(1528, 8, 384, 524),
	Rect2(1528, 548, 384, 524),
]

var _instruction: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func refresh(game: GameState, selected_hand_index: int = -1, gear_replace_index: int = -1) -> void:
	_clear_seats()
	_instruction = null
	if game.players.is_empty():
		return
	for player in game.players:
		var who: Dictionary = player
		var index := int(who["index"])
		if index < 0 or index >= SEAT_RECTS.size():
			continue
		var seat: Control = SEAT_SCENE.instantiate()
		add_child(seat)
		var rect: Rect2 = SEAT_RECTS[index]
		seat.offset_left = rect.position.x
		seat.offset_top = rect.position.y
		seat.offset_right = rect.end.x
		seat.offset_bottom = rect.end.y
		var is_current := index == game.current_index
		seat.call("show_player", who, game, is_current, selected_hand_index, gear_replace_index)
		if is_current:
			var label := seat.get_node("Margin/Column/TurnRow/Instruction") as Label
			_instruction = label
		seat.connect("card_clicked", _emit_card)
		seat.connect("gear_slot_clicked", _emit_gear)
		seat.connect("rest_pressed", _emit_rest)
		seat.connect("end_turn_pressed", _emit_end)


func show_status(text: String) -> void:
	if _instruction != null:
		_instruction.text = text


func _emit_card(hand_index: int) -> void:
	card_clicked.emit(hand_index)


func _emit_gear(slot_index: int) -> void:
	gear_slot_clicked.emit(slot_index)


func _emit_rest() -> void:
	rest_pressed.emit()


func _emit_end() -> void:
	end_turn_pressed.emit()


func _clear_seats() -> void:
	for child in get_children():
		if str(child.name) == "Legend":
			continue
		remove_child(child)
		child.free()
