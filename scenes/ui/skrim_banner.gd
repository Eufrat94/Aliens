class_name SkrimBanner
extends Control

var _title: Label
var _who: Label


func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	position = Vector2.ZERO
	size = Vector2(1920, 1080)
	var dim := ColorRect.new()
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	dim.color = Color(0, 0, 0, 0.45)
	dim.position = Vector2.ZERO
	dim.size = Vector2(1920, 1080)
	add_child(dim)
	_title = Label.new()
	_title.text = "SKRIM!"
	_title.mouse_filter = MOUSE_FILTER_IGNORE
	_title.position = Vector2(80, 340)
	_title.size = Vector2(1760, 140)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 96)
	_title.add_theme_color_override("font_color", Color8(210, 160, 255))
	var bold := SystemFont.new()
	bold.font_weight = 700
	_title.add_theme_font_override("font", bold)
	add_child(_title)
	_who = Label.new()
	_who.mouse_filter = MOUSE_FILTER_IGNORE
	_who.position = Vector2(160, 490)
	_who.size = Vector2(1600, 80)
	_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_who.add_theme_font_size_override("font_size", 36)
	_who.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	add_child(_who)
	var hint := Label.new()
	hint.text = "Click to continue"
	hint.mouse_filter = MOUSE_FILTER_IGNORE
	hint.position = Vector2(160, 590)
	hint.size = Vector2(1600, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.86))
	add_child(hint)


func show_for(player_name: String) -> void:
	_title.text = "SKRIM!"
	_title.add_theme_font_size_override("font_size", 96)
	_who.text = "%s has Skrim" % player_name
	_show()


func show_announcement(headline: String) -> void:
	_title.text = headline
	_title.add_theme_font_size_override("font_size", 48)
	_who.text = ""
	_show()


func _show() -> void:
	var screen := get_viewport_rect().size
	size = screen
	visible = true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		visible = false
		accept_event()
