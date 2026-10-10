extends Panel

signal tile_clicked(tile_id: String)

var tile_id: String = ""

@onready var _name_label: Label = $NameLabel
@onready var _type_label: Label = $TypeLabel


func setup(id: String) -> void:
	tile_id = id
	var tile := BoardData.get_tile(id)
	_name_label.text = tile["name"]
	_type_label.text = _type_name(tile["type"])


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
