class_name WinScreen
extends Control

signal new_game_pressed

var _title: Label
var _aliens: Label
var _missing: Label


func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	position = Vector2.ZERO
	size = Vector2(1920, 1080)
	var backdrop := ColorRect.new()
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	backdrop.color = Color(0.09, 0.09, 0.12, 1)
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(1920, 1080)
	add_child(backdrop)
	_title = Label.new()
	_title.mouse_filter = MOUSE_FILTER_IGNORE
	_title.position = Vector2(120, 280)
	_title.size = Vector2(1680, 100)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 72)
	var bold := SystemFont.new()
	bold.font_weight = 700
	_title.add_theme_font_override("font", bold)
	add_child(_title)
	_aliens = Label.new()
	_aliens.mouse_filter = MOUSE_FILTER_IGNORE
	_aliens.position = Vector2(200, 400)
	_aliens.size = Vector2(1520, 120)
	_aliens.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aliens.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aliens.add_theme_font_size_override("font_size", 28)
	_aliens.add_theme_color_override("font_color", Color(0.92, 0.92, 0.96))
	add_child(_aliens)
	_missing = Label.new()
	_missing.mouse_filter = MOUSE_FILTER_IGNORE
	_missing.position = Vector2(200, 540)
	_missing.size = Vector2(1520, 50)
	_missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_missing.add_theme_font_size_override("font_size", 26)
	_missing.add_theme_color_override("font_color", Color8(210, 160, 255))
	add_child(_missing)
	var button := Button.new()
	button.text = "New game"
	button.position = Vector2(810, 640)
	button.size = Vector2(300, 56)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(func() -> void: new_game_pressed.emit())
	add_child(button)


func show_winner(player: Dictionary, missing_name: String) -> void:
	var screen := get_viewport_rect().size
	size = screen
	_title.text = "%s wins!" % str(player["name"])
	_title.add_theme_color_override("font_color", player["color"])
	_aliens.text = _owned_names(player)
	_missing.text = "The missing alien was: %s" % missing_name
	visible = true


func _owned_names(player: Dictionary) -> String:
	var names: PackedStringArray = PackedStringArray()
	var hand: Array = player["hand"]
	for card_id in hand:
		if CardData.is_alien(str(card_id)):
			names.append(str(CardData.get_card(str(card_id))["name"]))
	var aliens: Array = player["aliens"]
	for card_id in aliens:
		names.append(str(CardData.get_card(str(card_id))["name"]))
	return ", ".join(names)
