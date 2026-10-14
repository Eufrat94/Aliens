extends Control

signal player_count_chosen(count: int)


func _ready() -> void:
	for count in [2, 3, 4]:
		var button := get_node("Center/Box/Margin/Buttons/Count%d" % count) as Button
		button.pressed.connect(_choose.bind(count))


func _choose(count: int) -> void:
	player_count_chosen.emit(count)
