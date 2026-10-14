extends Control

@onready var _log_label: Label = $LogBar/LogLabel
@onready var _history_overlay: Control = $HistoryOverlay
@onready var _history_list: VBoxContainer = $HistoryOverlay/HistoryPanel/Margin/Column/HistoryScroll/HistoryList

var _game: GameState


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var bar := $LogBar as Control
	var log_region := UiConfig.LOG_REGION
	bar.position = log_region.position
	bar.size = log_region.size
	_log_label.offset_right = log_region.size.x - 118.0
	_log_label.offset_bottom = log_region.size.y
	var button := $LogBar/HistoryButton as Control
	button.offset_left = log_region.size.x - 108.0
	button.offset_right = log_region.size.x - 8.0
	button.offset_bottom = log_region.size.y - 1.0
	UiConfig.place_centered($HistoryOverlay/HistoryPanel as Control, Vector2(760, 560))
	$LogBar/HistoryButton.pressed.connect(_open_history)
	$HistoryOverlay/HistoryPanel/Margin/Column/HistoryClose.pressed.connect(_close_history)


func refresh_log(game: GameState) -> void:
	if game.players.is_empty():
		return
	_game = game
	if game.public_log.is_empty():
		_log_label.text = ""
	else:
		_log_label.text = str(game.public_log[0])


func _open_history() -> void:
	if _game == null:
		return
	_clear(_history_list)
	if _game.public_log.is_empty():
		_history_list.add_child(_info_label("No public events yet.", Color(0.8, 0.8, 0.86), 16))
	else:
		for line in _game.public_log:
			_history_list.add_child(_info_label(str(line), Color(0.92, 0.92, 0.96), 16))
	_history_overlay.visible = true


func _close_history() -> void:
	_history_overlay.visible = false


func _info_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
