extends Node2D

signal tile_clicked(tile_id: String)

const TILE_SCENE := preload("res://scenes/board/tile.tscn")
const TILE_WIDTH := 260.0
const TILE_HEIGHT := 150.0
const H_GAP := 140.0
const V_GAP := 110.0
const BOARD_ORIGIN := Vector2(120, 115)

@onready var _tiles: Node2D = $Tiles


func _ready() -> void:
	for id in BoardData.get_tile_ids():
		var grid: Vector2i = BoardData.get_tile(id)["grid_pos"]
		var tile: Panel = TILE_SCENE.instantiate()
		_tiles.add_child(tile)
		tile.position = _tile_top_left(grid)
		tile.setup(id)
		tile.tile_clicked.connect(_on_tile_clicked)
	$ConnectionsLayer.queue_redraw()


func get_tile_center(id: String) -> Vector2:
	var grid: Vector2i = BoardData.get_tile(id)["grid_pos"]
	return _tile_top_left(grid) + Vector2(TILE_WIDTH, TILE_HEIGHT) * 0.5


func _tile_top_left(grid: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(
		grid.x * (TILE_WIDTH + H_GAP),
		grid.y * (TILE_HEIGHT + V_GAP)
	)


func _on_tile_clicked(id: String) -> void:
	tile_clicked.emit(id)
