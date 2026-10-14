extends Node2D

# The bow is half this length. 340px keeps Sacred altar–Spaceship outside Bandit camp.
const CONTROL_OFFSET := 340.0
const CURVE_POINTS := 24
const LABEL_SIZE := 20


func sample_points(board) -> PackedVector2Array:
	var points := PackedVector2Array()
	for connection in BoardData.CONNECTIONS:
		var a: Vector2 = board.get_tile_center(connection["a"])
		var b: Vector2 = board.get_tile_center(connection["b"])
		var path: BoardData.PathType = connection["path"]
		if path == BoardData.PathType.PLANE:
			var board_center: Vector2 = board.get_tile_center("village_market")
			var control := _control_point(a, b, board_center)
			for i in CURVE_POINTS:
				var t := float(i) / float(CURVE_POINTS - 1)
				points.append(_bezier(a, control, b, t))
		else:
			points.append(a)
			points.append(b)
	return points


func _draw() -> void:
	var board = get_parent()
	if board == null or not board.has_method("get_tile_center"):
		return
	var normals: Array[Dictionary] = []
	for connection in BoardData.CONNECTIONS:
		if connection["path"] == BoardData.PathType.NORMAL:
			normals.append(connection)
		else:
			_draw_connection(board, connection)
	for connection in normals:
		_draw_connection(board, connection)


func _draw_connection(board, connection: Dictionary) -> void:
	var path: BoardData.PathType = connection["path"]
	var color := _path_color(path)
	var width := _path_width(path)
	var a: Vector2 = board.get_tile_center(connection["a"])
	var b: Vector2 = board.get_tile_center(connection["b"])
	if path == BoardData.PathType.PLANE:
		_draw_plane(board, a, b, color, width)
	else:
		draw_line(a, b, color, width, true)


func _draw_plane(board, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var board_center: Vector2 = board.get_tile_center("village_market")
	var control := _control_point(a, b, board_center)
	var points := PackedVector2Array()
	for i in CURVE_POINTS:
		var t := float(i) / float(CURVE_POINTS - 1)
		points.append(_bezier(a, control, b, t))
	draw_polyline(points, color, width, true)
	_draw_plane_label(_bezier(a, control, b, 0.5))


func _control_point(a: Vector2, b: Vector2, board_center: Vector2) -> Vector2:
	var mid := (a + b) * 0.5
	var along := b - a
	if along.length_squared() == 0.0:
		return mid
	var perpendicular := along.orthogonal().normalized()
	if perpendicular.dot(mid - board_center) < 0.0:
		perpendicular = -perpendicular
	return mid + perpendicular * CONTROL_OFFSET


func _bezier(a: Vector2, control: Vector2, b: Vector2, t: float) -> Vector2:
	var inverse := 1.0 - t
	return inverse * inverse * a + 2.0 * inverse * t * control + t * t * b


func _draw_plane_label(at: Vector2) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var text := "PLANE"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
	var baseline_y := at.y + (font.get_ascent(LABEL_SIZE) - font.get_descent(LABEL_SIZE)) * 0.5
	var baseline := Vector2(at.x - text_size.x * 0.5, baseline_y)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Color8(16, 48, 82))


func _path_color(path: BoardData.PathType) -> Color:
	match path:
		BoardData.PathType.NORMAL:
			return Color8(139, 90, 43)
		BoardData.PathType.JUNGLE:
			return Color8(124, 194, 66)
		BoardData.PathType.RIVER:
			return Color8(30, 144, 255)
		BoardData.PathType.PLANE:
			return Color8(135, 206, 235)
	return Color.MAGENTA


func _path_width(path: BoardData.PathType) -> float:
	match path:
		BoardData.PathType.NORMAL, BoardData.PathType.JUNGLE:
			return 14.0
		BoardData.PathType.RIVER:
			return 10.0
		BoardData.PathType.PLANE:
			return 5.0
	return 1.0
