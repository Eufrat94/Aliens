extends Control

signal dismissed

@onready var _title: Label = $Title
@onready var _hint: Label = $Hint


func show_for(player: Dictionary) -> void:
	show_message(
		"%s's turn" % player["name"],
		"Pass the device to %s, then click anywhere to start." % player["name"],
		player["color"]
	)


func show_message(title: String, hint: String, color: Color) -> void:
	var screen := get_viewport_rect().size
	position = Vector2.ZERO
	size = screen
	mouse_filter = MOUSE_FILTER_STOP
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_hint.text = hint
	move_to_front()
	visible = true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide()
		dismissed.emit()
		accept_event()
