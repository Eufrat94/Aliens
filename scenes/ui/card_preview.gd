extends Control

const PREVIEW_SIZE := Vector2(220, 310)
const HOVER_DELAY := 0.3

var _timer: Timer
var _panel: Panel
var _name_label: Label
var _strip: ColorRect
var _strip_label: Label
var _body_label: Label


func _ready() -> void:
	add_to_group("card_preview")
	mouse_filter = MOUSE_FILTER_IGNORE
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = HOVER_DELAY
	_timer.timeout.connect(_show_pending)
	add_child(_timer)
	_build_panel()


func begin_hover(card_id: String) -> void:
	if card_id == "":
		return
	set_meta("pending_card", card_id)
	_timer.start()


func end_hover() -> void:
	set_meta("pending_card", "")
	_timer.stop()
	_panel.visible = false


func _show_pending() -> void:
	var card_id := str(get_meta("pending_card", ""))
	if card_id == "":
		return
	var card: Dictionary = CardData.get_card(card_id)
	var strip: Dictionary = CardView.strip_for(card)
	_name_label.text = str(card["name"])
	_strip.color = strip["color"]
	_strip_label.text = str(strip["title"])
	_strip_label.add_theme_color_override("font_color", strip["title_color"])
	_body_label.text = str(card["text"])
	_place_near_cursor()
	_panel.visible = true


func _place_near_cursor() -> void:
	var mouse := get_global_mouse_position()
	var pos := mouse + Vector2(18, 18)
	var screen := get_viewport_rect().size
	if pos.x + PREVIEW_SIZE.x > screen.x - 8.0:
		pos.x = mouse.x - PREVIEW_SIZE.x - 18.0
	if pos.y + PREVIEW_SIZE.y > screen.y - 8.0:
		pos.y = screen.y - PREVIEW_SIZE.y - 8.0
	pos.x = clampf(pos.x, 8.0, maxf(8.0, screen.x - PREVIEW_SIZE.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, screen.y - PREVIEW_SIZE.y - 8.0))
	_panel.position = pos


func _build_panel() -> void:
	_panel = Panel.new()
	_panel.visible = false
	_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = PREVIEW_SIZE
	_panel.size = PREVIEW_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color(0.12, 0.12, 0.12)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_name_label = Label.new()
	_name_label.mouse_filter = MOUSE_FILTER_IGNORE
	_name_label.position = Vector2(12, 10)
	_name_label.size = Vector2(196, 64)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	var bold := SystemFont.new()
	bold.font_weight = 700
	_name_label.add_theme_font_override("font", bold)
	_panel.add_child(_name_label)

	_strip = ColorRect.new()
	_strip.mouse_filter = MOUSE_FILTER_IGNORE
	_strip.position = Vector2(12, 80)
	_strip.size = Vector2(196, 32)
	_panel.add_child(_strip)

	_strip_label = Label.new()
	_strip_label.mouse_filter = MOUSE_FILTER_IGNORE
	_strip_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_strip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_strip_label.add_theme_font_size_override("font_size", 14)
	_strip.add_child(_strip_label)

	_body_label = Label.new()
	_body_label.mouse_filter = MOUSE_FILTER_IGNORE
	_body_label.position = Vector2(12, 122)
	_body_label.size = Vector2(196, 176)
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.add_theme_color_override("font_color", Color(0.16, 0.16, 0.18))
	_panel.add_child(_body_label)
