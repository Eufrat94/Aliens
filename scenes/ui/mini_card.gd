extends Panel

const CARD_SIZE := Vector2(86, 120)

var _card_id := ""
var _recipe_only := false
var _style: StyleBoxFlat
var _bold_name: Font
var _recipe_label: Label
var _recipe_rule: ColorRect
var _effect_label: Label


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = MOUSE_FILTER_STOP
	_style = StyleBoxFlat.new()
	_style.bg_color = Color.WHITE
	_style.border_color = Color(0.12, 0.12, 0.12)
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", _style)
	var bold := SystemFont.new()
	bold.font_weight = 700
	_bold_name = bold
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_recipe_label = Label.new()
	_recipe_label.visible = false
	_recipe_label.mouse_filter = MOUSE_FILTER_IGNORE
	_recipe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recipe_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_recipe_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recipe_label.clip_text = false
	_recipe_label.add_theme_font_size_override("font_size", 9)
	_recipe_label.add_theme_color_override("font_color", Color(0.12, 0.32, 0.38))
	add_child(_recipe_label)
	_recipe_rule = ColorRect.new()
	_recipe_rule.visible = false
	_recipe_rule.mouse_filter = MOUSE_FILTER_IGNORE
	_recipe_rule.color = Color(0.22, 0.28, 0.32, 0.7)
	add_child(_recipe_rule)
	_effect_label = Label.new()
	_effect_label.visible = false
	_effect_label.mouse_filter = MOUSE_FILTER_IGNORE
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.clip_text = true
	_effect_label.add_theme_font_size_override("font_size", 8)
	_effect_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.22))
	add_child(_effect_label)


func set_selected(on: bool) -> void:
	if _style == null:
		return
	if on:
		_style.border_color = Color8(241, 196, 15)
		_style.set_border_width_all(4)
	else:
		_style.border_color = Color(0.12, 0.12, 0.12)
		_style.set_border_width_all(2)


func set_recipe_only(on: bool) -> void:
	_recipe_only = on
	_layout_face()


func apply_size(card_size: Vector2) -> void:
	custom_minimum_size = card_size
	size = card_size
	var strip: ColorRect = $Strip
	strip.offset_left = 4
	strip.offset_top = 4
	strip.offset_right = card_size.x - 4
	strip.offset_bottom = 24
	var name_label: Label = $NameLabel
	name_label.offset_left = 4
	name_label.offset_top = 26
	name_label.offset_right = card_size.x - 4
	name_label.offset_bottom = card_size.y - 4
	_layout_face()


func setup(card_id: String) -> void:
	_card_id = card_id
	var card: Dictionary = CardData.get_card(card_id)
	var strip: Dictionary = CardView.strip_for(card)
	$Strip.color = strip["color"]
	$NameLabel.text = str(card["name"])
	_layout_face()


func _layout_face() -> void:
	if _recipe_label == null:
		return
	var name_label: Label = $NameLabel
	var recipe := ""
	var effect := ""
	if _card_id != "":
		var card: Dictionary = CardData.get_card(_card_id)
		recipe = CardData.recipe_block(card)
		effect = str(card["text"])
	if recipe == "":
		_recipe_label.visible = false
		_recipe_rule.visible = false
		_effect_label.visible = false
		name_label.offset_top = 26
		name_label.offset_bottom = size.y - 4
		name_label.clip_text = true
		name_label.remove_theme_font_override("font")
		name_label.add_theme_font_size_override("font_size", 13)
		clip_contents = false
		return
	if _recipe_only:
		_show_recipe_only(name_label, recipe)
		return
	var text_w := size.x - 8.0
	var bottom := size.y - 3.0
	name_label.remove_theme_font_override("font")
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.clip_text = false
	name_label.offset_left = 4.0
	name_label.offset_right = size.x - 4.0
	name_label.offset_top = 25.0
	name_label.offset_bottom = 29.0
	var name_h := name_label.get_minimum_size().y
	name_label.offset_bottom = 25.0 + name_h
	var content_top := name_label.offset_bottom + 2.0
	var room := bottom - content_top
	var gap := 8.0
	var recipe_size := 8
	var effect_size := 7
	var fitted := false
	var sizes: Array[int] = [11, 10, 9, 8, 7]
	for try_effect in sizes:
		var effect_try: int = int(try_effect)
		var recipe_try := 9
		if effect_try < 8:
			recipe_try = 8
		var rh := _content_height(_recipe_label, recipe, text_w, recipe_try)
		var eh := _content_height(_effect_label, effect, text_w, effect_try)
		if rh + gap + eh <= room:
			recipe_size = recipe_try
			effect_size = effect_try
			fitted = true
			break
	if not fitted:
		_content_height(_recipe_label, recipe, text_w, recipe_size)
		_content_height(_effect_label, effect, text_w, effect_size)
	var recipe_h := _recipe_label.size.y
	_recipe_label.position = Vector2(4, content_top)
	var rule_y := content_top + recipe_h + 2.0
	_recipe_rule.visible = true
	_recipe_rule.position = Vector2(8, rule_y)
	_recipe_rule.size = Vector2(maxf(size.x - 16.0, 8.0), 1)
	var effect_top := rule_y + 4.0
	_effect_label.position = Vector2(4, effect_top)
	_effect_label.clip_text = not fitted
	clip_contents = not fitted


func _show_recipe_only(name_label: Label, recipe: String) -> void:
	_effect_label.visible = false
	_recipe_rule.visible = false
	clip_contents = false
	var text_w := size.x - 8.0
	name_label.add_theme_font_override("font", _bold_name)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.clip_text = false
	name_label.offset_left = 4.0
	name_label.offset_right = size.x - 4.0
	name_label.offset_top = 25.0
	name_label.offset_bottom = 29.0
	var name_h := name_label.get_minimum_size().y
	name_label.offset_bottom = 25.0 + name_h
	var top := name_label.offset_bottom + 2.0
	_content_height(_recipe_label, recipe, text_w, 12)
	_recipe_label.clip_text = false
	_recipe_label.position = Vector2(4, top)


func _content_height(label: Label, text: String, width: float, font_size: int) -> float:
	label.visible = true
	label.clip_text = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.custom_minimum_size = Vector2.ZERO
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.size = Vector2(width, 4)
	var height := label.get_minimum_size().y
	label.size = Vector2(width, height)
	return label.size.y


func _on_mouse_entered() -> void:
	var tree := get_tree()
	if tree == null or _card_id == "":
		return
	var preview := tree.get_first_node_in_group("card_preview")
	if preview != null and preview.has_method("begin_hover"):
		preview.call("begin_hover", _card_id)


func _on_mouse_exited() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var preview := tree.get_first_node_in_group("card_preview")
	if preview != null and preview.has_method("end_hover"):
		preview.call("end_hover")
