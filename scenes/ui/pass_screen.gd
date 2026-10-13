extends Control

@onready var _title: Label = $Title
@onready var _hint: Label = $Hint


func show_for(player: Dictionary) -> void:
	_title.text = "%s's turn" % player["name"]
	_title.add_theme_color_override("font_color", player["color"])
	_hint.text = "Pass the device to %s, then click anywhere to start." % player["name"]
	visible = true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide()
		accept_event()
