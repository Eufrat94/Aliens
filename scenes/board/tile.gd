extends Panel

signal tile_clicked(tile_id: String)

var tile_id: String = ""

var _style: StyleBoxFlat

@onready var _name_label: Label = $NameLabel
@onready var _type_label: Label = $TypeLabel
@onready var _deck_label: Label = $DeckLabel


func _ready() -> void:
	_style = (get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	add_theme_stylebox_override("panel", _style)


func setup(id: String) -> void:
	tile_id = id
	var tile := BoardData.get_tile(id)
	_name_label.text = tile["name"]
	_type_label.text = _type_name(tile["type"])


func set_deck_count(count: int) -> void:
	if count < 0:
		_deck_label.visible = false
		return
	_deck_label.visible = true
	if count == 0:
		_deck_label.text = "Deck: empty"
	else:
		_deck_label.text = "Deck: %d" % count


func set_move_target(on: bool) -> void:
	if _style == null:
		return
	if on:
		_style.border_color = Color8(241, 196, 15)
		_style.set_border_width_all(8)
	else:
		_style.border_color = Color.BLACK
		_style.set_border_width_all(4)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			tile_clicked.emit(tile_id)
			accept_event()


func _type_name(type: BoardData.TileType) -> String:
	match type:
		BoardData.TileType.SEARCH:
			return "search"
		BoardData.TileType.HUB:
			return "hub"
		BoardData.TileType.BLACK_MARKET:
			return "black market"
		BoardData.TileType.PURPLE_SOURCE:
			return "purple source"
		BoardData.TileType.ORACLE:
			return "oracle"
		BoardData.TileType.UNASSIGNED:
			return "unassigned"
	return "unknown"
