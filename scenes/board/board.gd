class_name GameBoard
extends Node2D

signal tile_clicked(tile_id: String)

const TILE_SCENE := preload("res://scenes/board/tile.tscn")
const TILE_WIDTH := 260.0
const TILE_HEIGHT := 150.0
const H_GAP := 620.0
const V_GAP := 110.0
const BOARD_ORIGIN := Vector2(20, 16)
const TOKEN_RADIUS := 24.0
const TOKEN_GAP := 4.0

var _tile_nodes := {}
var _game: GameState
var _tokens: TokenLayer

@onready var _tiles: Node2D = $Tiles


func _ready() -> void:
	for id in BoardData.get_tile_ids():
		var grid: Vector2i = BoardData.get_tile(id)["grid_pos"]
		var tile: Panel = TILE_SCENE.instantiate()
		_tiles.add_child(tile)
		tile.position = _tile_top_left(grid)
		tile.setup(id)
		tile.tile_clicked.connect(_on_tile_clicked)
		_tile_nodes[id] = tile
	_tokens = TokenLayer.new()
	_tokens.host = self
	add_child(_tokens)
	$ConnectionsLayer.queue_redraw()


func refresh_tokens(game: GameState) -> void:
	_game = game
	if _tokens != null:
		_tokens.queue_redraw()


func refresh_decks(game: GameState) -> void:
	for id in _tile_nodes:
		var tile_id: String = id
		_tile_nodes[tile_id].set_deck_count(game.deck_count(tile_id))
		_tile_nodes[tile_id].set_crystal_pool(game.crystal_pool)


func set_highlighted_tiles(tile_ids: Array) -> void:
	for id in _tile_nodes:
		_tile_nodes[id].set_move_target(id in tile_ids)


func clear_highlights() -> void:
	set_highlighted_tiles([])


func content_bounds() -> Rect2:
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for id in _tile_nodes:
		var tile: Control = _tile_nodes[id]
		var tile_size := tile.size
		if tile_size.x < 1.0:
			tile_size = Vector2(TILE_WIDTH, TILE_HEIGHT)
		var rect := Rect2(tile.position, tile_size)
		min_p.x = minf(min_p.x, rect.position.x)
		min_p.y = minf(min_p.y, rect.position.y)
		max_p.x = maxf(max_p.x, rect.end.x)
		max_p.y = maxf(max_p.y, rect.end.y)
	var points: PackedVector2Array = $ConnectionsLayer.sample_points(self)
	for point in points:
		var at: Vector2 = point
		min_p.x = minf(min_p.x, at.x)
		min_p.y = minf(min_p.y, at.y)
		max_p.x = maxf(max_p.x, at.x)
		max_p.y = maxf(max_p.y, at.y)
	return Rect2(min_p, max_p - min_p).grow(28.0)


func tile_rect(tile_id: String) -> Rect2:
	var tile: Control = _tile_nodes[tile_id]
	var top_left: Vector2 = position + tile.position * scale
	return Rect2(top_left, tile.size * scale)


func get_tile_center(id: String) -> Vector2:
	var grid: Vector2i = BoardData.get_tile(id)["grid_pos"]
	return _tile_top_left(grid) + Vector2(TILE_WIDTH, TILE_HEIGHT) * 0.5


func draw_player_tokens(canvas: CanvasItem) -> void:
	if _game == null:
		return
	var groups := {}
	for player in _game.players:
		var tile_id: String = player["tile"]
		if not groups.has(tile_id):
			groups[tile_id] = []
		groups[tile_id].append(player)
	for tile_id in groups:
		var group: Array = groups[tile_id]
		group.sort_custom(func(a, b): return int(a["index"]) < int(b["index"]))
		_draw_token_group(canvas, tile_id, group)


func _draw_token_group(canvas: CanvasItem, tile_id: String, group: Array) -> void:
	var count := group.size()
	var top_left := _tile_top_left(BoardData.get_tile(tile_id)["grid_pos"])
	var total := count * TOKEN_RADIUS * 2.0 + (count - 1) * TOKEN_GAP
	var x := top_left.x + (TILE_WIDTH - total) * 0.5 + TOKEN_RADIUS
	var y := top_left.y + TILE_HEIGHT - TOKEN_RADIUS - 14.0
	for player in group:
		var pos := Vector2(x, y)
		var is_current: bool = int(player["index"]) == _game.current_index
		if is_current:
			canvas.draw_circle(pos, TOKEN_RADIUS + 10.0, Color.BLACK)
			canvas.draw_circle(pos, TOKEN_RADIUS + 6.0, Color.WHITE)
		canvas.draw_circle(pos, TOKEN_RADIUS, player["color"])
		canvas.draw_arc(pos, TOKEN_RADIUS, 0.0, TAU, 40, Color.BLACK, 2.0, true)
		_draw_player_number(canvas, pos, int(player["index"]) + 1)
		x += TOKEN_RADIUS * 2.0 + TOKEN_GAP


func _draw_player_number(canvas: CanvasItem, pos: Vector2, number: int) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var font_size := 22
	var text := str(number)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := Vector2(
		pos.x - text_size.x * 0.5,
		pos.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	)
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		canvas.draw_string(font, baseline + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _tile_top_left(grid: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(
		grid.x * (TILE_WIDTH + H_GAP),
		grid.y * (TILE_HEIGHT + V_GAP)
	)


func _on_tile_clicked(id: String) -> void:
	tile_clicked.emit(id)


class TokenLayer extends Node2D:
	var host: Node2D

	func _draw() -> void:
		if host != null and host.has_method("draw_player_tokens"):
			host.draw_player_tokens(self)
