extends Control

const PREVIEW_SIZE := Vector2(220, 310)
const HOVER_DELAY := 0.3

var _timer: Timer
var _panel: Panel
var _suppressed := false
var _name_label: Label
var _strip: ColorRect
var _strip_label: Label
var _body_label: Label
var _tag_label: Label
var _recipe_label: Label
var _recipe_rule: ColorRect


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
	if _suppressed or card_id == "":
		return
	set_meta("pending_card", card_id)
	_timer.start()


func end_hover() -> void:
	set_meta("pending_card", "")
	_timer.stop()
	if _panel != null:
		_panel.visible = false


func suppress() -> void:
	_suppressed = true
	end_hover()


func unsuppress() -> void:
	_suppressed = false


func _show_pending() -> void:
	if _suppressed:
		return
	var card_id := str(get_meta("pending_card", ""))
	if card_id == "":
		return
	var card: Dictionary = CardData.get_card(card_id)
	var strip: Dictionary = CardView.strip_for(card)
	_name_label.text = str(card["name"])
	_strip.color = strip["color"]
	_strip_label.text = str(strip["title"])
	_strip_label.add_theme_color_override("font_color", strip["title_color"])
	var tag := CardView.action_tag(card)
	_tag_label.visible = tag != ""
	_tag_label.text = tag
	_layout_body(card, 148.0 if tag != "" else 122.0)
	_place_near_cursor()
	_panel.visible = true


func _place_near_cursor() -> void:
	var mouse := get_global_mouse_position()
	var pos := mouse + Vector2(18, 18)
	var screen := get_viewport_rect().size
	var panel_size := _panel.size
	if pos.x + panel_size.x > screen.x - 8.0:
		pos.x = mouse.x - panel_size.x - 18.0
	if pos.y + panel_size.y > screen.y - 8.0:
		pos.y = screen.y - panel_size.y - 8.0
	pos.x = clampf(pos.x, 8.0, maxf(8.0, screen.x - panel_size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, screen.y - panel_size.y - 8.0))
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

	_tag_label = Label.new()
	_tag_label.mouse_filter = MOUSE_FILTER_IGNORE
	_tag_label.position = Vector2(12, 116)
	_tag_label.size = Vector2(196, 22)
	_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_label.add_theme_font_size_override("font_size", 13)
	_tag_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	_panel.add_child(_tag_label)

	_body_label = Label.new()
	_body_label.mouse_filter = MOUSE_FILTER_IGNORE
	_body_label.position = Vector2(12, 122)
	_body_label.size = Vector2(196, 176)
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.add_theme_color_override("font_color", Color(0.16, 0.16, 0.18))
	_panel.add_child(_body_label)
	_recipe_label = Label.new()
	_recipe_label.visible = false
	_recipe_label.mouse_filter = MOUSE_FILTER_IGNORE
	_recipe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recipe_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recipe_label.clip_text = false
	_recipe_label.add_theme_font_size_override("font_size", 14)
	_recipe_label.add_theme_color_override("font_color", Color(0.12, 0.32, 0.38))
	_recipe_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_panel.add_child(_recipe_label)
	_recipe_rule = ColorRect.new()
	_recipe_rule.visible = false
	_recipe_rule.mouse_filter = MOUSE_FILTER_IGNORE
	_recipe_rule.color = Color(0.22, 0.28, 0.32, 0.7)
	_panel.add_child(_recipe_rule)


func _layout_body(card: Dictionary, top: float) -> void:
	var width := 196.0
	var recipe := CardData.recipe_block(card)
	if recipe == "":
		_panel.custom_minimum_size = PREVIEW_SIZE
		_panel.size = PREVIEW_SIZE
		_recipe_label.visible = false
		_recipe_rule.visible = false
		_recipe_label.custom_minimum_size = Vector2.ZERO
		_body_label.custom_minimum_size = Vector2.ZERO
		_body_label.clip_text = false
		_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body_label.add_theme_font_size_override("font_size", 16)
		_body_label.text = str(card["text"])
		_body_label.position = Vector2(12, top)
		_body_label.custom_minimum_size = Vector2.ZERO
		_body_label.size = Vector2(width, 4)
		var real := _body_label.get_minimum_size().y
		var box := maxf(real, PREVIEW_SIZE.y - 12.0 - top)
		_body_label.size = Vector2(width, box)
		var plain_h := maxf(PREVIEW_SIZE.y, top + box + 12.0)
		_panel.custom_minimum_size = Vector2(PREVIEW_SIZE.x, plain_h)
		_panel.size = Vector2(PREVIEW_SIZE.x, plain_h)
		return
	var effect := str(card["text"])
	var screen_h := get_viewport_rect().size.y
	var max_h := PREVIEW_SIZE.y
	if screen_h > 64.0:
		max_h = maxf(PREVIEW_SIZE.y, screen_h - 16.0)
	var gap := 12.0
	var recipe_size := 13
	var effect_size := 12
	var sizes: Array[int] = [16, 15, 14, 13, 12]
	for try_effect in sizes:
		var effect_try: int = int(try_effect)
		var recipe_try := 14
		if effect_try < 14:
			recipe_try = effect_try
		var rh := CardView.wrapped_height(_panel, recipe, width, recipe_try)
		var eh := CardView.wrapped_height(_panel, effect, width, effect_try)
		if top + rh + gap + eh + 16.0 <= max_h:
			recipe_size = recipe_try
			effect_size = effect_try
			break
	var recipe_h := CardView.settle_label(_recipe_label, Vector2(12, top), width, recipe, recipe_size)
	var rule_y := top + recipe_h + 4.0
	_recipe_rule.visible = true
	_recipe_rule.position = Vector2(28, rule_y)
	_recipe_rule.size = Vector2(164, 1)
	var effect_y := rule_y + 8.0
	var effect_h := CardView.settle_label(_body_label, Vector2(12, effect_y), width, effect, effect_size)
	var panel_h := maxf(PREVIEW_SIZE.y, effect_y + effect_h + 14.0)
	_panel.custom_minimum_size = Vector2(PREVIEW_SIZE.x, panel_h)
	_panel.size = Vector2(PREVIEW_SIZE.x, panel_h)
