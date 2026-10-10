extends Node2D

@onready var _board: Node2D = $Board


func _ready() -> void:
	if BoardData.validate():
		print("Board data OK: 9 tiles, 15 connections")
	for id in BoardData.get_tile_ids():
		var tile_name: String = BoardData.get_tile(id)["name"]
		print("%s: %s" % [tile_name, _neighbor_list(id)])
	_board.tile_clicked.connect(_on_tile_clicked)


func _on_tile_clicked(tile_id: String) -> void:
	var tile_name: String = BoardData.get_tile(tile_id)["name"]
	print("Clicked: %s | neighbors: %s" % [tile_name, _neighbor_list(tile_id)])


func _neighbor_list(id: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for neighbor in BoardData.get_neighbors(id):
		var neighbor_name: String = BoardData.get_tile(neighbor["tile"])["name"]
		var path_name: String = BoardData.path_type_name(neighbor["path"])
		parts.append("%s (%s)" % [neighbor_name, path_name])
	return ", ".join(parts)
